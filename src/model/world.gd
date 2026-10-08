# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name World
extends RefCounted
## Simulation state of the live view in world units: the server is a sun at the origin, workers circle it on the ground ring.

const SUN_RADIUS := 6.25
const FLARE_COLOR := Color("ff5a1e")
const WORKER_RING := 40.0
const WORKER_SPIN := 0.04
const WORKER_ORBIT_MAX := 5.5
const CACHE_ARC_CENTER := Vector3(0.0, 17.0, 0.0)
const CACHE_ARC := 18.0
const CACHE_SPACING := 14.0
const SKY := 60.0
const EVAL_LINGER := 10.0
const EVAL_FADE := 3.0
const EVAL_STALE := 30.0
const EVAL_BUSY_STALE := 1800.0
const CALM_DELAY := 30.0
const CALM_FADE := 1.5
const PUSH_DROUGHT := 600.0
const MAX_FX := 2500
const MAX_HEADLINES := 9
const MAX_MESSAGES := 14
const MESSAGE_GAP := 0.005
const PUSH_GAPS := [0.0, 0.001]
const MESSAGE_LAG := 2.0
const SERVER := "server"
const WORKER_PHASES := ["fetching", "evaluating"]
const ACTIVITY := ["nar_push", "log_chunk"]
const OFFER := "job_offer"
const SCORES := "request_job_chunk"
const GOLDEN_ANGLE := PI * (3.0 - sqrt(5.0))
const FORMATION_GAP := 0.45
const UNSTABLE_SPARK_RATE := 4.0
const ECHO_TIME := 0.45
const SHOCK_TIME := 0.8
const LINK_FADE := 1.2
const SCORE_HALF := 600.0

var time := 0.0
var shake := 0.0
var core_flash := 0.0
var calm := 0.0
var drought := 0.0
var workers := {}
var evaluations := {}
var caches := {}
var build_owner := {}
var derivations := {}
var dispatched := {}
var assigned_evaluation := {}
var uploader := ""
var names := {}
var offers := {}
var pacing := {}
var backlog := []
var fx := []
var headlines: Array[Bodies.Headline] = []
var messages: Array[Bodies.Headline] = []

var banner: float:
	get:
		return clampf(maxf(calm - CALM_DELAY, drought - PUSH_DROUGHT) / CALM_FADE, 0.0, 1.0)


static func server_position() -> Vector3:
	return Vector3.ZERO


static func worker_host(worker_id: String) -> String:
	return "worker:%s" % worker_id


static func evaluation_host(evaluation_id: String) -> String:
	return "evaluation:%s" % evaluation_id


func apply(effect: Variant) -> void:
	if effect is Effects.WorkerMessage:
		if effect.kind == "nar_push":
			uploader = effect.job_id
		_pace(effect)
	elif effect is Effects.WorkerLoad:
		_worker(effect.worker_id).cpu = effect.cpu
	elif effect is Effects.WorkerLink:
		_worker(effect.worker_id).connected = effect.connected
	elif effect is Effects.WorkerNetwork:
		_worker(effect.worker_id).network = effect.mbps
	elif effect is Effects.EvaluationChanged:
		_evaluation_changed(effect)
	elif effect is Effects.BuildChanged:
		_build_changed(effect)
	elif effect is Effects.JobDispatched:
		_dispatch(effect)
	elif effect is Effects.ServerPulse:
		_pulse(effect.kind)
	elif effect is Effects.CacheAccess:
		_cache_access(effect)
	elif effect is Effects.CacheStored:
		_store(effect.cache_id)
	elif effect is Effects.CacheQueried:
		_query_caches()
	elif effect is Effects.Names:
		_resolve(effect.names)
	elif effect is Effects.CachesListed:
		_list_caches(effect.caches)
	elif effect is Effects.Headline:
		headlines.push_front(Bodies.Headline.new(effect.text, effect.tone, time, effect.subject, effect.fallback))
		headlines.resize(mini(headlines.size(), MAX_HEADLINES))


func update(dt: float) -> void:
	time += dt
	_release()
	shake *= pow(0.02, dt)
	core_flash *= pow(0.08, dt)
	calm = 0.0 if _workers_busy() else calm + dt
	drought += dt
	_update_workers(dt)
	_update_evaluations(dt)
	for cache in caches.values():
		cache.flash *= pow(0.1, dt)
		cache.alarm *= pow(0.2, dt)
	var current := fx
	var alive := []
	fx = []
	for effect in current:
		if effect.update(dt):
			alive.append(effect)
	fx = alive + fx


func describe(line: Bodies.Headline) -> String:
	if not line.subject:
		return line.text
	var label: String = names.get(line.subject, evaluations[line.subject].label if evaluations.has(line.subject) else line.fallback)
	return line.text.format([label])


func worker_label(worker: Bodies.Worker) -> String:
	return names.get(worker.id, "worker %s" % worker.id.substr(0, 8))


func cache_label(cache: Bodies.Cache) -> String:
	return names.get(cache.id, "cache %s" % cache.id.substr(0, 8))


func average_network() -> Variant:
	var samples := workers.values().filter(func(worker: Bodies.Worker): return worker.network != null)
	if samples.is_empty():
		return null
	return samples.reduce(func(total: float, worker: Bodies.Worker): return total + worker.network, 0.0) / samples.size()


func electrons() -> Array:
	var result := []
	for evaluation in evaluations.values():
		result.append(evaluation.electron)
		result.append_array(evaluation.builds.values().map(func(build): return build.electron))
	return result


func _resolve(resolved: Dictionary) -> void:
	for id in resolved:
		if names.get(id) == resolved[id]:
			continue
		names[id] = resolved[id]
		for bodies in [workers, caches]:
			if bodies.has(id):
				bodies[id].born = time
		if evaluations.has(id):
			evaluations[id].label = resolved[id]


func _list_caches(listed: Dictionary) -> void:
	for id in listed:
		_cache(id)
	_resolve(listed)


func _spawn(effects: Array) -> void:
	fx.append_array(effects)


static func byte_size(size: int) -> String:
	return "%.1f kB" % (size / 1024.0) if size >= 1024 else "%d B" % size


func _pace(message: Effects.WorkerMessage) -> void:
	var ready := minf(maxf(time, pacing.get(message.worker_id, time)), time + MESSAGE_LAG)
	pacing[message.worker_id] = ready + (PUSH_GAPS.pick_random() if message.kind in ACTIVITY else MESSAGE_GAP)
	if ready <= time:
		_message(message)
	else:
		backlog.append([ready, message])


func _release() -> void:
	var waiting := backlog
	backlog = []
	for entry in waiting:
		if entry[0] <= time:
			_message(entry[1])
		else:
			backlog.append(entry)


func _message(message: Effects.WorkerMessage) -> void:
	var worker := _worker(message.worker_id)
	var line := "{0}  %s  %s" % ["->" if message.outbound else "<-", message.kind]
	if message.size > 0:
		line += "  " + byte_size(message.size)
	messages.push_front(Bodies.Headline.new(line, message.kind, time, worker.id, "worker %s" % worker.id.substr(0, 8)))
	messages.resize(mini(messages.size(), MAX_MESSAGES))
	if message.kind in ACTIVITY:
		calm = 0.0
	if message.kind == "nar_push":
		drought = 0.0
	_claim(message.job_id, worker)
	if message.kind == OFFER:
		_offer(worker)
		return
	if message.kind == SCORES:
		_answer(worker)
		return
	if fx.size() > MAX_FX:
		return
	var at_worker := func() -> Vector3: return worker.position
	var source: Callable = server_position if message.outbound else at_worker
	var target: Callable = at_worker if message.outbound else server_position
	var arrive := func() -> void:
		if message.outbound:
			worker.heat = 1.0
		else:
			core_flash = maxf(core_flash, 0.35)
	var route := RandomNumberGenerator.new()
	route.seed = hash("%s:%s:%s" % [message.worker_id, message.job_id, message.kind]) if message.job_id else randi()
	var size := (1.5 + log(message.size + 1.0) / log(10.0) * 0.9) * 0.034
	_spawn([Comet.new(source, target, Palette.message(message.kind), size, route.randf_range(0.55, 0.9), route.randf_range(-0.3, 0.3), arrive)])


func _evaluation_changed(change: Effects.EvaluationChanged) -> void:
	var evaluation := _evaluation(change.evaluation_id)
	evaluation.flash = 1.0
	evaluation.idle = 0.0
	if change.group:
		_join(evaluation, change.group)
	if change.repository:
		evaluation.label = Bodies.repository_label(change.repository)
	var anchor := func() -> Vector3: return evaluation.position
	if not change.phase:
		_spawn([Comet.new(server_position, anchor, Palette.PROGRESS, 0.07, 0.9, 0.2)])
		return
	if change.phase == evaluation.phase:
		return
	evaluation.phase = change.phase
	if change.phase not in WORKER_PHASES:
		_send_home(evaluation)
	if evaluation.finished:
		for build in evaluation.builds.values():
			_send_build_home(evaluation, build)
	var color := Palette.state(change.phase)
	_spawn([Ripple.new(anchor, color, 1.5, 1.0, 0.05)])
	if change.phase == "completed":
		_spawn(Spark.burst(evaluation.position, color, 90, 8.0, 1.6))
		_spawn([Ripple.new(anchor, Color.WHITE, 3.4, 1.4, 0.09)])
	elif change.phase in EventParser.BAD:
		shake = maxf(shake, 1.0)
		_spawn(Spark.burst(evaluation.position, color, 120, 9.8, 1.8))
		_spawn([Ripple.new(anchor, color, 4.7, 1.2, 0.12)])


func _build_changed(change: Effects.BuildChanged) -> void:
	var evaluation: Bodies.Evaluation = evaluations.get(change.evaluation_id if change.evaluation_id else build_owner.get(change.build_id, ""))
	if not evaluation:
		return
	var build := _build(evaluation, change.build_id)
	if change.derivation_build:
		_link_derivation(build, change.derivation_build)
	if build.state == change.state:
		return
	build.state = change.state
	if change.state == "building" and dispatched.has(build.derivation_build):
		_board_derivation(build.derivation_build, _worker(dispatched[build.derivation_build]))
	elif change.state != "building":
		_send_build_home(evaluation, build)
	if build.finished:
		dispatched.erase(build.derivation_build)
		assigned_evaluation.erase(build.derivation_build)
	build.flash = 1.0
	evaluation.idle = 0.0
	evaluation.flash = maxf(evaluation.flash, 0.5)
	var color := Palette.state(change.state)
	if change.state == "substituted":
		_substitute(evaluation, build, color)
	elif change.state in EventParser.GOOD:
		_spawn(Spark.burst(build.position, color, 18, 3.8, 0.9))
	elif change.state in EventParser.BAD:
		shake = maxf(shake, 0.5)
		_spawn(Spark.burst(build.position, color, 45, 6.4, 1.3))
		_spawn([Ripple.new(func() -> Vector3: return build.position, color, 1.3, 0.8, 0.05)])


func _substitute(evaluation: Bodies.Evaluation, build: Bodies.Build, color: Color) -> void:
	build.incoming = true
	var arrive := func() -> void:
		build.incoming = false
		build.flash = 1.0
		_spawn(Spark.burst(build.position, color, 18, 3.8, 0.9))
	_spawn([Comet.new(_substitution_source(evaluation, build), func() -> Vector3: return build.position, color, 0.085, randf_range(1.0, 1.4), randf_range(-0.3, 0.3), arrive)])


func _substitution_source(evaluation: Bodies.Evaluation, build: Bodies.Build) -> Callable:
	var sources: Array = evaluation.uploads.keys().filter(func(id: String): return caches.has(id)).map(func(id: String): return caches[id])
	if sources.is_empty():
		sources = caches.values()
	if not sources.is_empty():
		var cache: Bodies.Cache = sources.pick_random()
		return func() -> Vector3: return cache.position
	var sky := Vector3(build.position.x + randf_range(-3.4, 3.4), SKY, build.position.z)
	return func() -> Vector3: return sky


func _dispatch(dispatch: Effects.JobDispatched) -> void:
	var worker := _worker(dispatch.worker_id)
	worker.heat = 1.0
	if offers.has(worker.id):
		offers[worker.id].score = dispatch.score
	if dispatch.derivation_build:
		dispatched[dispatch.derivation_build] = worker.id
		_assign(dispatch.derivation_build, dispatch.evaluation_id)
		_board_derivation(dispatch.derivation_build, worker)
	elif dispatch.evaluation_id:
		var evaluation := _evaluation(dispatch.evaluation_id)
		_start(evaluation)
		_board(evaluation, worker)


func _board(job: Variant, worker: Bodies.Worker) -> void:
	job.electron.jump(worker_host(worker.id), func() -> Vector3: return worker.position, _worker_orbit(worker.id), 2 * SHOCK_TIME)


func _claim(job_id: String, worker: Bodies.Worker) -> void:
	var id := job_id.get_slice(":", 1)
	var host := worker_host(worker.id)
	match job_id.get_slice(":", 0):
		"eval":
			var evaluation: Bodies.Evaluation = evaluations.get(id)
			if not evaluation:
				return
			evaluation.idle = 0.0
			_start(evaluation)
			if evaluation.phase in WORKER_PHASES and evaluation.electron.host != host:
				_board(evaluation, worker)
		"build":
			dispatched[id] = worker.id
			_board_derivation(id, worker)


func _job_evaluation(job_id: String) -> Bodies.Evaluation:
	var id := job_id.get_slice(":", 1)
	match job_id.get_slice(":", 0):
		"eval":
			return evaluations.get(id)
		"build":
			return evaluations.get(assigned_evaluation.get(id, ""))
	return null


func _start(evaluation: Bodies.Evaluation) -> void:
	if evaluation.phase == "queued":
		_evaluation_changed(Effects.EvaluationChanged.new(evaluation.id, "fetching"))


func _board_derivation(derivation_build: String, worker: Bodies.Worker) -> void:
	var build := _assigned_build(derivation_build)
	if build and not build.finished and build.electron.host != worker_host(worker.id):
		_board(build, worker)


func _assign(derivation_build: String, evaluation_id: String) -> void:
	var previous := _assigned_build(derivation_build)
	assigned_evaluation[derivation_build] = evaluation_id
	if previous and build_owner[previous.id] != evaluation_id:
		_send_build_home(evaluations[build_owner[previous.id]], previous)


func _assigned_build(derivation_build: String) -> Bodies.Build:
	var owner: String = assigned_evaluation.get(derivation_build, "")
	for build in _builds_of(derivation_build):
		if build_owner[build.id] == owner:
			return build
	return null


func _builds_of(derivation_build: String) -> Array:
	return derivations.get(derivation_build, [])


func _link_derivation(build: Bodies.Build, derivation_build: String) -> void:
	if build.derivation_build == derivation_build:
		return
	_unlink_derivation(build)
	build.derivation_build = derivation_build
	if not derivations.has(derivation_build):
		derivations[derivation_build] = []
	derivations[derivation_build].append(build)


func _unlink_derivation(build: Bodies.Build) -> void:
	var linked: Array = derivations.get(build.derivation_build, [])
	linked.erase(build)
	if linked.is_empty():
		derivations.erase(build.derivation_build)


func _offer(worker: Bodies.Worker) -> void:
	var offer := Bodies.Offer.new()
	offers[worker.id] = offer
	var arrive := func() -> void:
		offer.arrived = true
		_reflect(worker)
	_spawn([Shockwave.new(server_position, Palette.PING, worker.position.distance_to(server_position()), SHOCK_TIME, arrive)])


func _answer(worker: Bodies.Worker) -> void:
	if offers.has(worker.id):
		offers[worker.id].answered = true
		_reflect(worker)


func _reflect(worker: Bodies.Worker) -> void:
	var offer: Bodies.Offer = offers.get(worker.id)
	if not offer or not offer.arrived or not offer.answered:
		return
	offers.erase(worker.id)
	var at_worker := func() -> Vector3: return worker.position
	var distance := worker.position.distance_to(server_position())
	if offer.score == null:
		_spawn([Shockwave.new(at_worker, Palette.PING, distance, SHOCK_TIME, Callable(), server_position, 0.3)])
		return
	var quality: float = maxf(offer.score, 0.0) / (maxf(offer.score, 0.0) + SCORE_HALF)
	var color := Palette.ECHO_BAD.lerp(Palette.ECHO_GOOD, quality)
	_spawn([Shockwave.new(at_worker, color, distance, SHOCK_TIME, Callable(), server_position, 0.1 + 0.9 * quality)])


func _send_home(evaluation: Bodies.Evaluation) -> void:
	if evaluation.electron.host != SERVER:
		evaluation.electron.jump(SERVER, server_position, _server_orbit(evaluation.slot, evaluation.group))


func _send_build_home(evaluation: Bodies.Evaluation, build: Bodies.Build) -> void:
	var host := evaluation_host(evaluation.id)
	if build.finished:
		build.electron.jump(host, _follow(evaluation.electron), Orbit.new(0.0, 0.0, 0.0, 0.0))
	elif build.electron.host != host:
		build.electron.jump(host, _follow(evaluation.electron), _build_orbit(build.index))


func _join(evaluation: Bodies.Evaluation, group: String) -> void:
	if evaluation.group == group:
		return
	var slot := _lane(group)
	if evaluation.electron.host == SERVER:
		evaluation.electron.jump(SERVER, server_position, _server_orbit(slot, group))
	evaluation.group = group
	evaluation.slot = slot


func _pulse(kind: String) -> void:
	core_flash = 1.0
	if kind == "graph":
		_erupt()


static func flare_height() -> float:
	var roll := randf()
	return SUN_RADIUS * (0.02 + 0.08 * roll + 0.5 * pow(roll, 14.0))


func _erupt() -> void:
	var root := Vector3(randfn(0, 1), randfn(0, 1) * 0.6, randfn(0, 1)).normalized()
	var height := flare_height()
	_spawn([Flare.new(root, SUN_RADIUS, height, FLARE_COLOR, 4.0 + height * 2.0)])


func _cache_access(access: Effects.CacheAccess) -> void:
	var cache := _cache(access.cache_id)
	cache.flash = 1.0
	var color: Color
	var size := 0.07
	if access.kind == "nar":
		cache.served += access.size
		color = Palette.NAR
		size = (1.5 + log(access.size + 1.0) / log(10.0) * 0.9) * 0.034
	elif access.hit:
		cache.hits += 1
		color = Palette.CACHE_HIT
	else:
		cache.misses += 1
		cache.alarm = 1.0
		color = Palette.CACHE_MISS
	var client := Vector3(cache.position.x + randf_range(-4.0, 4.0), SKY, cache.position.z)
	_spawn([Comet.new(func() -> Vector3: return cache.position, func() -> Vector3: return client, color, size, randf_range(0.6, 0.9), randf_range(-0.3, 0.3))])


func _store(cache_id: String) -> void:
	var cache := _cache(cache_id)
	var evaluation := _job_evaluation(uploader)
	if evaluation:
		evaluation.uploads[cache_id] = true
	var arrive := func() -> void: cache.flash = 1.0
	_spawn([Comet.new(server_position, func() -> Vector3: return cache.position, Palette.STORE, 0.1, 1.3, randf_range(-0.2, 0.2), arrive)])


func _query_caches() -> void:
	for cache in caches.values():
		var arrive := func() -> void: cache.flash = maxf(cache.flash, 0.4)
		_spawn([Echo.new(server_position, func() -> Vector3: return cache.position, Palette.PING, 0.4, ECHO_TIME, arrive)])


func _cache(cache_id: String) -> Bodies.Cache:
	if not caches.has(cache_id):
		caches[cache_id] = Bodies.Cache.new(cache_id, time)
		_place_caches()
	return caches[cache_id]


func _place_caches() -> void:
	var ids := caches.keys()
	ids.sort()
	var radius := maxf(CACHE_ARC, CACHE_SPACING * (ids.size() + 1) / PI)
	for index in ids.size():
		var angle := PI * (index + 1) / (ids.size() + 1)
		caches[ids[index]].position = CACHE_ARC_CENTER + Vector3(-cos(angle), 0.0, -sin(angle)) * radius


func _worker(worker_id: String) -> Bodies.Worker:
	if not workers.has(worker_id):
		workers[worker_id] = Bodies.Worker.new(worker_id, randf() * TAU, time)
		var ids := workers.keys()
		ids.sort()
		for index in ids.size():
			workers[ids[index]].target = index * TAU / ids.size()
		_place_worker(workers[worker_id])
	return workers[worker_id]


func _evaluation(evaluation_id: String) -> Bodies.Evaluation:
	if not evaluations.has(evaluation_id):
		var slot := _lane(evaluation_id)
		var electron := Electron.new(SERVER, server_position, _server_orbit(slot, evaluation_id), server_position(), 0.0)
		evaluations[evaluation_id] = Bodies.Evaluation.new(evaluation_id, names.get(evaluation_id, evaluation_id.substr(0, 8)), slot, evaluation_id, electron, time)
	return evaluations[evaluation_id]


func _lane(group: String) -> int:
	var lanes := {}
	for evaluation in evaluations.values():
		lanes[evaluation.group] = evaluation.slot
	if lanes.has(group):
		return lanes[group]
	var slot := 0
	while slot in lanes.values():
		slot += 1
	return slot


func _build(evaluation: Bodies.Evaluation, build_id: String) -> Bodies.Build:
	if not evaluation.builds.has(build_id):
		var index := evaluation.builds.size()
		var electron := Electron.new(evaluation_host(evaluation.id), _follow(evaluation.electron), _build_orbit(index), evaluation.position, 0.0)
		evaluation.builds[build_id] = Bodies.Build.new(build_id, index, electron)
		build_owner[build_id] = evaluation.id
	return evaluation.builds[build_id]


func _follow(host: Electron) -> Callable:
	return func() -> Vector3: return host.position


func _workers_busy() -> bool:
	for evaluation in evaluations.values():
		if evaluation.electron.host.begins_with("worker:"):
			return true
		for build in evaluation.builds.values():
			if build.electron.host.begins_with("worker:"):
				return true
	return false


func _electrons_on(host: String) -> int:
	var count := 0
	for evaluation in evaluations.values():
		count += int(evaluation.electron.host == host)
		for build in evaluation.builds.values():
			count += int(build.electron.host == host)
	return count


func _server_orbit(slot: int, group: String) -> Orbit:
	var radius := 13.0 + 2.2 * (slot % 4)
	var speed := Orbit.kepler_speed(radius, 1 if slot % 2 else -1)
	return Orbit.new(radius, 0.08 + 0.08 * (slot % 3), slot * GOLDEN_ANGLE, speed, _formation_phase(group, speed))


func _formation_phase(group: String, speed: float) -> float:
	var siblings := evaluations.values().filter(func(e): return e.group == group and e.electron.host == SERVER)
	if siblings.is_empty():
		return randf() * TAU
	return siblings[0].electron.orbit.phase - signf(speed) * FORMATION_GAP * siblings.size()


func _build_orbit(index: int) -> Orbit:
	var radius := 0.65 + 0.17 * sqrt(index)
	return Orbit.new(radius, 0.7, index * GOLDEN_ANGLE, Orbit.kepler_speed(radius, 1) * 1.6, randf() * TAU)


func _worker_orbit(worker_id: String) -> Orbit:
	var radius := 2.6 + 0.7 * (_electrons_on(worker_host(worker_id)) % 5)
	return Orbit.new(radius, randf_range(0.3, 0.9), randf() * TAU, Orbit.kepler_speed(radius, 1) * 1.3, randf() * TAU)


func _update_workers(dt: float) -> void:
	for worker in workers.values():
		worker.angle += wrapf(worker.target - worker.angle, -PI, PI) * minf(dt * 2.5, 1.0)
		worker.heat *= pow(0.25, dt)
		worker.smoothed_cpu = lerpf(0.0 if worker.cpu == null else worker.cpu / 100.0, worker.smoothed_cpu, pow(0.3, dt))
		worker.link = move_toward(worker.link, 1.0 if worker.connected else 0.0, dt / LINK_FADE)
		_place_worker(worker)
		if worker.unstable and randf() < dt * UNSTABLE_SPARK_RATE:
			_spawn(Spark.burst(worker.position, Palette.cpu(worker.cpu), 8, 3.0, 0.6))


func _update_evaluations(dt: float) -> void:
	for evaluation in evaluations.values().duplicate():
		evaluation.flash *= pow(0.1, dt)
		evaluation.idle += dt
		var linger := EVAL_LINGER if evaluation.finished else EVAL_BUSY_STALE if evaluation.busy else EVAL_STALE
		evaluation.alpha = 1.0 - clampf((evaluation.idle - linger) / EVAL_FADE, 0.0, 1.0)
		if evaluation.alpha <= 0.0:
			_retire(evaluation)
			continue
		evaluation.electron.update(dt)
		for build in evaluation.builds.values():
			build.flash *= pow(0.1, dt)
			build.electron.update(dt)
			_absorb(evaluation, build)


func _absorb(evaluation: Bodies.Evaluation, build: Bodies.Build) -> void:
	if build.absorbed or not build.finished or build.incoming or build.electron.hop < 1.0 or build.electron.orbit.radius > 0.0:
		return
	build.absorbed = true
	evaluation.flash = maxf(evaluation.flash, 0.6)


func _retire(evaluation: Bodies.Evaluation) -> void:
	evaluations.erase(evaluation.id)
	for build in evaluation.builds.values():
		build_owner.erase(build.id)
		_unlink_derivation(build)


func _place_worker(worker: Bodies.Worker) -> void:
	var angle := worker.angle + time * WORKER_SPIN
	worker.position = Vector3(cos(angle), 0.0, sin(angle)) * WORKER_RING
