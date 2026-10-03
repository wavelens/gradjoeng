# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name EventParser

const EVALUATION_PHASES := ["queued", "evaluating", "evaluating", "building", "waiting", "completed", "failed", "aborted", "fetching"]
const BUILD_STATES := ["created", "queued", "building", "completed", "failed", "aborted", "dependency_failed", "substituted", "retrying", "timeout", "skipped"]
const GOOD := ["completed", "substituted"]
const BAD := ["failed", "dependency_failed", "timeout", "aborted"]


static func parse(event: Dictionary) -> Array:
	var name: Variant = event.get("event")
	if not name is String:
		return []
	var content: Dictionary = event["content"] if event.get("content") is Dictionary else {}
	match name.get_slice(".", 0):
		"proto":
			return _proto(name, content)
		"evaluation":
			return _evaluation(name, content)
		"build":
			return _build(name, content)
		"worker":
			return _worker(name, content)
		"graph":
			return _graph(name, content)
		"cache":
			return _cache(name, content)
		"directory":
			return _directory(name, content)
	return [Effects.Headline.new(name, "info")]


static func tone_of(state: String) -> String:
	return "good" if state in GOOD else "bad" if state in BAD else "info"


static func short(identifier: String) -> String:
	return identifier.substr(0, 8) if identifier else "?"


static func text(content: Dictionary, key: String) -> String:
	var value: Variant = content.get(key)
	return value if value is String else ""


static func number(content: Dictionary, key: String) -> float:
	var value: Variant = content.get(key)
	return float(value) if value is float or value is int else 0.0


static func optional_number(content: Dictionary, key: String) -> Variant:
	var value: Variant = content.get(key)
	return float(value) if value is float or value is int else null


static func lookup(table: Array, code: Variant, fallback: String) -> String:
	var valid: bool = (code is float or code is int) and 0 <= int(code) and int(code) < table.size()
	return table[int(code)] if valid else fallback


static func suffix(name: String) -> String:
	return name.get_slice(".", name.get_slice_count(".") - 1)


static func _proto(name: String, content: Dictionary) -> Array:
	var worker := text(content, "worker_id")
	if not worker:
		return []
	var message := Effects.WorkerMessage.new(worker, text(content, "direction") == "server", suffix(name), int(number(content, "len")), text(content, "job_id"))
	return [message, Effects.CacheQueried.new()] if message.kind == "cache_query" else [message]


static func _evaluation(name: String, content: Dictionary) -> Array:
	var evaluation := text(content, "evaluation_id")
	if not evaluation:
		return []
	var group := text(content, "project") if text(content, "project") else text(content, "task")
	if not content.has("status"):
		return [Effects.EvaluationChanged.new(evaluation, "", "", group)]
	var phase := lookup(EVALUATION_PHASES, content["status"], suffix(name))
	return [
		Effects.EvaluationChanged.new(evaluation, phase, text(content, "repository"), group),
		Effects.Headline.new("evaluation %s {0}" % phase.rpad(10), tone_of(phase), evaluation, short(evaluation)),
	]


static func _build(name: String, content: Dictionary) -> Array:
	var build := text(content, "build_id")
	if not build:
		return []
	var state := lookup(BUILD_STATES, content.get("status"), suffix(name))
	var effects: Array = [Effects.BuildChanged.new(build, text(content, "evaluation_id"), state, text(content, "derivation_build"))]
	if tone_of(state) != "info":
		effects.append(Effects.Headline.new("build      %s {0}" % state.rpad(10), tone_of(state), build, short(build)))
	return effects


static func _worker(name: String, content: Dictionary) -> Array:
	var worker := text(content, "worker_id")
	match name:
		"worker.queue_depth":
			return []
		"worker.metrics" when worker:
			return [Effects.WorkerLoad.new(worker, optional_number(content, "cpu_usage_pct"))]
		"worker.connected", "worker.disconnected" when worker:
			var connected := name == "worker.connected"
			return [
				Effects.WorkerLink.new(worker, connected),
				Effects.Headline.new("worker     %s {0}" % ("online" if connected else "offline"), "good" if connected else "bad", worker, "worker %s" % short(worker)),
			]
		"worker.network" when worker:
			return [Effects.WorkerNetwork.new(worker, optional_number(content, "network_speed_mbps"))]
		"worker.job_dispatched" when worker:
			return [
				Effects.JobDispatched.new(worker, text(content, "evaluation_id"), text(content, "build_id"), number(content, "score")),
				Effects.Headline.new("dispatch   -> {0}", "info", worker, "worker %s" % short(worker)),
			]
	return [Effects.Headline.new(name, "info")]


static func _graph(name: String, content: Dictionary) -> Array:
	var pulse := Effects.ServerPulse.new("graph")
	if name == "graph.requeued" and not content.get("requeued"):
		return [pulse]
	return [pulse, Effects.Headline.new(name, "info")]


static func _directory(name: String, content: Dictionary) -> Array:
	if name == "directory.caches":
		var caches: Variant = content.get("caches")
		return [Effects.CachesListed.new(caches)] if caches is Dictionary else []
	if name == "directory.jobs":
		var jobs: Variant = content.get("jobs")
		return jobs.map(func(job: Dictionary): return Effects.JobDispatched.new(text(job, "worker_id"), text(job, "evaluation_id"), text(job, "build_id"), number(job, "score"))) if jobs is Array else []
	var names: Variant = content.get("names")
	return [Effects.Names.new(names)] if names is Dictionary else []


static func _cache(name: String, content: Dictionary) -> Array:
	var cache := text(content, "cache")
	match name:
		"cache.nar.signed" when cache:
			return [Effects.CacheStored.new(cache)]
		"cache.nar.fetched", "cache.narinfo.served" when cache:
			return [Effects.CacheAccess.new(cache, name.get_slice(".", 1), content.get("hit", true), int(number(content, "size")))]
	return [Effects.ServerPulse.new("cache")]
