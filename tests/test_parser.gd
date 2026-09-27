extends Suite


func ev(name: String, content: Dictionary = {}) -> Dictionary:
	return {"event": name, "at": "2026-09-26T23:22:44Z", "content": content}


func only(effects: Array) -> Variant:
	equal(effects.size(), 1, "effect count")
	return effects[0] if effects.size() == 1 else null


func test_proto_client_message_flows_to_server() -> void:
	var message: Effects.WorkerMessage = only(EventParser.parse(ev("proto.client.log_chunk", {"direction": "client", "worker_id": "w1", "job_id": "eval:e1", "len": null})))
	equal([message.worker_id, message.outbound, message.kind, message.size, message.job_id], ["w1", false, "log_chunk", 0, "eval:e1"])


func test_proto_server_message_flows_to_worker() -> void:
	var message: Effects.WorkerMessage = only(EventParser.parse(ev("proto.server.assign_job", {"direction": "server", "worker_id": "w1", "len": 320.0})))
	equal([message.outbound, message.size], [true, 320])


func test_cache_query_also_asks_the_caches() -> void:
	var effects := EventParser.parse(ev("proto.client.cache_query", {"direction": "client", "worker_id": "w1", "len": 90.0}))
	equal(effects.map(func(effect): return effect.get_script()), [Effects.WorkerMessage, Effects.CacheQueried])


func test_proto_without_worker_is_ignored() -> void:
	equal(EventParser.parse(ev("proto.client.request_job", {"worker_id": null})), [])


func test_evaluation_queued_carries_repository_and_headline() -> void:
	var effects := EventParser.parse(ev("evaluation.queued", {"evaluation_id": "e1", "status": 0.0, "repository": "https://github.com/wavelens/gobgp.nix"}))
	var change: Effects.EvaluationChanged = effects[0]
	equal([change.evaluation_id, change.phase, change.repository], ["e1", "queued", "https://github.com/wavelens/gobgp.nix"])
	check(effects[1] is Effects.Headline, "headline follows")


func test_evaluation_status_codes_map_to_phases() -> void:
	equal(EventParser.parse(ev("evaluation.started", {"evaluation_id": "e1", "status": 8.0}))[0].phase, "fetching")
	equal(EventParser.parse(ev("evaluation.building", {"evaluation_id": "e1", "status": 3.0}))[0].phase, "building")
	equal(EventParser.parse(ev("evaluation.completed", {"evaluation_id": "e1", "status": 5.0}))[0].phase, "completed")
	equal(EventParser.parse(ev("evaluation.failed", {"evaluation_id": "e1", "status": 6.0}))[0].phase, "failed")


func test_evaluation_progress_keeps_phase() -> void:
	var change: Effects.EvaluationChanged = only(EventParser.parse(ev("evaluation.progress", {"evaluation_id": "e1", "task": "t"})))
	equal([change.phase, change.group], ["", "t"])


func test_evaluation_groups_by_project_before_task() -> void:
	equal(EventParser.parse(ev("evaluation.queued", {"evaluation_id": "e1", "status": 0.0, "project": "p", "task": "t"}))[0].group, "p")
	equal(EventParser.parse(ev("evaluation.queued", {"evaluation_id": "e1", "status": 0.0, "project": null, "task": "t"}))[0].group, "t")


func test_build_status_codes_map_to_states() -> void:
	var change: Effects.BuildChanged = only(EventParser.parse(ev("build.status_changed", {"build_id": "b1", "evaluation_id": "e1", "status": 0.0})))
	equal([change.build_id, change.evaluation_id, change.state], ["b1", "e1", "created"])
	equal(EventParser.parse(ev("build.completed", {"build_id": "b1", "status": 3.0}))[0].state, "completed")
	equal(EventParser.parse(ev("build.failed", {"build_id": "b1", "status": 6.0}))[0].state, "dependency_failed")
	equal(EventParser.parse(ev("build.substituted", {"build_id": "b1", "status": 7.0}))[0].state, "substituted")


func test_build_events_carry_their_derivation_build() -> void:
	var change: Effects.BuildChanged = only(EventParser.parse(ev("build.status_changed", {"build_id": "b1", "evaluation_id": "e1", "derivation_build": "d1", "status": 2.0})))
	equal(change.derivation_build, "d1")


func test_terminal_build_emits_toned_headline() -> void:
	equal(EventParser.parse(ev("build.failed", {"build_id": "b1", "evaluation_id": "e1", "status": 4.0}))[1].tone, "bad")


func test_worker_events() -> void:
	var dispatch: Effects.JobDispatched = EventParser.parse(ev("worker.job_dispatched", {"worker_id": "w1", "evaluation_id": "e1", "build_id": "b1", "score": 2057.7}))[0]
	equal([dispatch.worker_id, dispatch.evaluation_id, dispatch.derivation_build], ["w1", "e1", "b1"])
	near(dispatch.score, 2057.7)
	equal(EventParser.parse(ev("worker.queue_depth", {"active": 1.0})), [])


func test_worker_metrics_carry_cpu_usage() -> void:
	var load: Effects.WorkerLoad = only(EventParser.parse(ev("worker.metrics", {"worker_id": "w1", "cpu_usage_pct": 91.5})))
	equal([load.worker_id, load.cpu], ["w1", 91.5])
	equal(EventParser.parse(ev("worker.metrics", {"worker_id": "w1", "cpu_usage_pct": null}))[0].cpu, null)


func test_graph_and_cache_pulse_the_server() -> void:
	equal(only(EventParser.parse(ev("graph.requeued", {"requeued": 0.0}))).kind, "graph")
	equal(EventParser.parse(ev("graph.ingested", {"evaluation_id": "e1"}))[0].kind, "graph")
	equal(only(EventParser.parse(ev("cache.nar.fetched"))).kind, "cache")


func test_cache_events_address_their_cache() -> void:
	var access: Effects.CacheAccess = only(EventParser.parse(ev("cache.narinfo.served", {"cache": "c1", "hit": false})))
	equal([access.cache_id, access.kind, access.hit, access.size], ["c1", "narinfo", false, 0])
	equal(EventParser.parse(ev("cache.nar.fetched", {"cache": "c1", "size": 96941.0}))[0].size, 96941)


func test_committed_nar_is_stored_in_caches() -> void:
	check(EventParser.parse(ev("graph.nar_committed", {"created": true})).any(func(effect): return effect is Effects.CacheStored))


func test_unknown_events_become_headlines() -> void:
	var headline: Effects.Headline = only(EventParser.parse(ev("mystery.thing")))
	equal([headline.text, headline.tone], ["mystery.thing", "info"])


func test_malformed_event_is_ignored() -> void:
	equal(EventParser.parse({"content": null}), [])


func test_directory_names_become_name_effects() -> void:
	var names: Effects.Names = only(EventParser.parse(ev("directory.names", {"names": {"w1": "builder-01", "c1": "main cache"}})))
	equal(names.names, {"w1": "builder-01", "c1": "main cache"})
	equal(EventParser.parse(ev("directory.names", {"names": "nope"})), [])


func test_directory_caches_become_listed_caches() -> void:
	var listed: Effects.CachesListed = only(EventParser.parse(ev("directory.caches", {"caches": {"c1": "main"}})))
	equal(listed.caches, {"c1": "main"})
	equal(EventParser.parse(ev("directory.caches", {"caches": []})), [])
