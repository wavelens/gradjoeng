# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite

const FIXTURE := "res://tests/fixtures/events.jsonl"


func fx_of(world: World, type: Variant) -> Array:
	return world.fx.filter(func(effect): return is_instance_of(effect, type))


func queued(evaluation: String, group: String = "") -> Effects.EvaluationChanged:
	return Effects.EvaluationChanged.new(evaluation, "queued", "", group)


func step(world: World, seconds: float, dt: float = 0.05) -> void:
	for i in ceili(seconds / dt):
		world.update(dt)


func test_worker_message_spawns_worker_and_comet() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1", true, "assign_job", 320))
	check(world.workers.has("w1"), "worker exists")
	equal(fx_of(world, Comet).size(), 1)


func test_comet_arrival_heats_worker() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1", true, "assign_job", 320))
	world.workers["w1"].heat = 0.0
	step(world, 1.0, 1.0 / 60)
	check(fx_of(world, Comet).is_empty(), "comet landed")
	check(world.workers["w1"].heat > 0.0, "worker heated")


func test_workers_are_spread_evenly() -> void:
	var world := World.new()
	for worker in ["a", "b", "c", "d"]:
		world.apply(Effects.WorkerMessage.new(worker, false, "request_job", 0))
	var targets := world.workers.values().map(func(w): return w.target)
	targets.sort()
	for i in range(1, targets.size()):
		near(targets[i] - targets[i - 1], TAU / 4)


func test_messages_of_the_same_job_stream_share_a_route() -> void:
	var world := World.new()
	for kind in ["log_chunk", "log_chunk", "nar_push", "nar_push"]:
		world.apply(Effects.WorkerMessage.new("w1", false, kind, 10, "eval:e1"))
	world.update(4 * World.MESSAGE_GAP)
	var comets := fx_of(world, Comet)
	equal([comets[0].bend, comets[0].duration], [comets[1].bend, comets[1].duration])
	equal([comets[2].bend, comets[2].duration], [comets[3].bend, comets[3].duration])
	check(comets[0].bend != comets[2].bend, "different kinds take different routes")


func test_evaluation_lifecycle_retires_after_linger() -> void:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "queued", "https://github.com/wavelens/gobgp.nix"))
	equal(world.evaluations["e1"].label, "gobgp.nix")
	world.apply(Effects.EvaluationChanged.new("e1", "completed"))
	check(not fx_of(world, Spark).is_empty() and not fx_of(world, Ripple).is_empty(), "celebration")
	world.update(World.EVAL_LINGER + World.EVAL_FADE / 2)
	check(0.0 < world.evaluations["e1"].alpha and world.evaluations["e1"].alpha < 1.0, "fading")
	world.update(World.EVAL_FADE)
	check(not world.evaluations.has("e1"), "retired")


func test_builds_of_unannounced_evaluations_spawn_no_sphere() -> void:
	var world := World.new()
	for state in ["created", "queued", "building", "completed"]:
		world.apply(Effects.BuildChanged.new("b1", "older-eval", state, "d1"))
	world.apply(Effects.BuildChanged.new("b2", "", "queued", "d2"))
	check(world.evaluations.is_empty(), "no phantom evaluations: %s" % [world.evaluations.keys()])


func test_idle_evaluation_despawns_after_30_seconds() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "queued"))
	step(world, 29.0, 1.0)
	check(world.evaluations.has("e1") and world.evaluations["e1"].alpha == 1.0, "still shown")
	step(world, 1.0 + World.EVAL_FADE + 0.5, 0.5)
	check(not world.evaluations.has("e1"), "despawned")


func test_finished_builds_fall_into_their_evaluation() -> void:
	for state in ["completed", "substituted", "failed", "dependency_failed", "aborted", "timeout", "skipped"]:
		var world := World.new()
		world.apply(queued("e1"))
		world.apply(Effects.BuildChanged.new("b1", "e1", "queued", "d1"))
		world.apply(Effects.BuildChanged.new("b2", "e1", "queued", "d2"))
		world.apply(Effects.JobDispatched.new("w1", "e1", "d1"))
		world.apply(Effects.BuildChanged.new("b1", "e1", "building", "d1"))
		step(world, 2.0)
		world.apply(Effects.BuildChanged.new("b1", "e1", state, "d1"))
		var evaluation: Bodies.Evaluation = world.evaluations["e1"]
		step(world, 3.0)
		var build: Bodies.Build = evaluation.builds["b1"]
		equal(build.electron.host, World.evaluation_host("e1"), state)
		near(build.position.distance_to(evaluation.position), 0.0, 0.01, state)
		check(build.absorbed, "%s absorbed" % state)
		equal(evaluation.visible_builds().map(func(b): return b.id), ["b2"], state)


func test_stale_evaluation_retires() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "created"))
	world.update(World.EVAL_STALE / 2)
	world.apply(Effects.BuildChanged.new("b1", "e1", "queued"))
	world.update(World.EVAL_STALE / 2 + World.EVAL_FADE / 2)
	check(world.evaluations.has("e1"), "activity keeps it alive")
	world.update(World.EVAL_STALE)
	check(not world.evaluations.has("e1"), "stale retired")


func test_evaluation_slots_are_reused() -> void:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "completed"))
	world.update(World.EVAL_LINGER + World.EVAL_FADE + 1)
	world.apply(queued("e2"))
	equal(world.evaluations["e2"].slot, 0)


func test_build_failure_shakes_once() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "building"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "failed"))
	var sparks := fx_of(world, Spark).size()
	world.apply(Effects.BuildChanged.new("b1", "e1", "failed"))
	equal(fx_of(world, Spark).size(), sparks)
	check(world.shake > 0.0, "shakes")
	equal(world.evaluations["e1"].builds["b1"].state, "failed")


func test_build_without_evaluation_uses_known_owner() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "queued"))
	world.apply(Effects.BuildChanged.new("b1", "", "completed"))
	equal(world.evaluations["e1"].builds["b1"].state, "completed")


func test_evaluation_electron_orbits_server_then_hops_to_worker_and_back() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	equal(world.evaluations["e1"].electron.host, "server")
	world.apply(Effects.JobDispatched.new("w1", "e1", ""))
	equal(world.evaluations["e1"].electron.host, "worker:w1")
	world.apply(Effects.EvaluationChanged.new("e1", "building"))
	equal(world.evaluations["e1"].electron.host, "server")


func test_build_electron_hops_to_worker_and_back() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "queued", "d1"))
	var build: Bodies.Build = world.evaluations["e1"].builds["b1"]
	equal(build.electron.host, "evaluation:e1")
	world.apply(Effects.JobDispatched.new("w1", "e1", "d1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "building", "d1"))
	equal(build.electron.host, "worker:w1")
	world.apply(Effects.BuildChanged.new("b1", "e1", "completed", "d1"))
	equal(build.electron.host, "evaluation:e1")


func test_shared_derivation_build_sends_one_build_to_the_worker() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(queued("e2"))
	world.apply(queued("e3"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "queued", "d1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", "d1"))
	world.apply(Effects.BuildChanged.new("b2", "e2", "building", "d1"))
	world.apply(Effects.BuildChanged.new("b3", "e3", "building", "d9"))
	equal(world.evaluations["e1"].builds["b1"].electron.host, "worker:w1")
	equal(world.evaluations["e2"].builds["b2"].electron.host, "evaluation:e2")
	equal(world.evaluations["e3"].builds["b3"].electron.host, "evaluation:e3")
	check(not world.evaluations["e1"].builds.has("d1"), "no phantom build")


func test_shared_derivation_build_redispatch_moves_the_same_build() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(queued("e2"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "building", "d1"))
	world.apply(Effects.BuildChanged.new("b2", "e2", "building", "d1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", "d1"))
	world.apply(Effects.JobDispatched.new("w2", "e1", "d1"))
	world.apply(Effects.WorkerMessage.new("w2", false, "job_update", 10, "build:d1"))
	var hosts := world.electrons().map(func(e: Electron): return e.host).filter(func(h: String): return h.begins_with("worker:"))
	equal(hosts, ["worker:w2"])


func test_finished_builds_do_not_board_on_dispatch() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "completed", "d1"))
	world.apply(Effects.JobDispatched.new("w1", "e2", "d1"))
	equal(world.evaluations["e1"].builds["b1"].electron.host, "evaluation:e1")


func test_finished_evaluation_calls_its_builds_home() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "building", "d1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", "d1"))
	world.apply(Effects.EvaluationChanged.new("e1", "aborted"))
	equal(world.evaluations["e1"].builds["b1"].electron.host, "evaluation:e1")


func test_worker_orbits_are_shelled_and_stay_near_the_worker() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	for build in ["b0", "b1", "b2", "b3", "b4"]:
		world.apply(Effects.BuildChanged.new(build, "e1", "queued", "d" + build))
		world.apply(Effects.JobDispatched.new("w1", "e1", "d" + build))
	var builds: Dictionary = world.evaluations["e1"].builds
	check(builds["b0"].electron.orbit.radius < builds["b1"].electron.orbit.radius, "shelled")
	step(world, 3.0)
	for build in builds.values():
		check(build.position.distance_to(world.workers["w1"].position) <= World.WORKER_ORBIT_MAX + 0.01, "near worker")


func test_electrons_settle_on_their_host_orbit() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", ""))
	step(world, 3.0)
	var evaluation: Bodies.Evaluation = world.evaluations["e1"]
	near(evaluation.position.distance_to(world.workers["w1"].position), evaluation.electron.orbit.radius, 0.05)


func test_evaluations_orbit_inside_the_worker_ring() -> void:
	var world := World.new()
	for i in 12:
		world.apply(queued("e%d" % i))
	step(world, 1.0)
	for evaluation in world.evaluations.values():
		check(evaluation.position.length() < World.WORKER_RING - 4.0, "inside worker ring")
		check(evaluation.position.length() > World.SUN_RADIUS + 2.0, "clear of the sun")


func test_evaluation_build_orbits_hug_evaluation() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "queued"))
	var radius: float = world.evaluations["e1"].builds["b1"].electron.orbit.radius
	check(radius >= 0.5 and radius < 0.9, "build orbit radius %s" % radius)


func test_server_pulse_flashes_core_and_headlines_are_kept() -> void:
	var world := World.new()
	world.apply(Effects.ServerPulse.new("graph"))
	world.apply(Effects.Headline.new("hello", "good"))
	check(world.core_flash > 0.0, "flash")
	equal(world.headlines[0].text, "hello")


func test_fx_expire() -> void:
	var world := World.new()
	world.apply(Effects.ServerPulse.new("cache"))
	step(world, 15.0, 1.0 / 30)
	check(world.fx.is_empty(), "fx gone")


func test_full_replay_is_stable() -> void:
	var world := World.new()
	for line in FileAccess.get_file_as_string(FIXTURE).split("\n", false):
		for effect in EventParser.parse(EventDecoder.decode(line)):
			world.apply(effect)
		world.update(1.0 / 60)
	check(not world.workers.is_empty(), "workers seen")


func test_cache_access_tracks_hits_misses_and_bytes() -> void:
	var world := World.new()
	world.apply(Effects.CacheAccess.new("c1", "narinfo", true, 0))
	world.apply(Effects.CacheAccess.new("c1", "narinfo", false, 0))
	world.apply(Effects.CacheAccess.new("c1", "nar", true, 2048))
	var cache: Bodies.Cache = world.caches["c1"]
	equal([cache.hits, cache.misses, cache.served], [1, 1, 2048])


func test_cache_miss_raises_the_alarm_and_hits_do_not() -> void:
	var world := World.new()
	world.apply(Effects.CacheAccess.new("c1", "narinfo", true, 0))
	equal(world.caches["c1"].alarm, 0.0)
	world.apply(Effects.CacheAccess.new("c1", "narinfo", false, 0))
	check(world.caches["c1"].alarm > 0.9, "miss alarms")
	world.update(3.0)
	check(world.caches["c1"].alarm < 0.05, "alarm decays")


func test_caches_lie_on_a_flat_half_circle_above_the_server() -> void:
	for count in [1, 3, 12]:
		var world := World.new()
		for i in count:
			world.apply(Effects.CacheAccess.new("c%02d" % i, "narinfo", true, 0))
		var ids := world.caches.keys()
		ids.sort()
		var positions := ids.map(func(id): return world.caches[id].position)
		var radius: float = positions[0].distance_to(World.CACHE_ARC_CENTER)
		for i in count:
			near(positions[i].y, World.CACHE_ARC_CENTER.y, 1e-3, "flat")
			near(positions[i].distance_to(World.CACHE_ARC_CENTER), radius, 1e-3, "on the arc")
			check(positions[i].z < World.CACHE_ARC_CENTER.z, "behind the server")
			if i > 0:
				check(positions[i].distance_to(positions[i - 1]) >= World.CACHE_SPACING * 0.95, "spaced: %s" % positions[i].distance_to(positions[i - 1]))
		check(World.CACHE_ARC_CENTER.y > World.SUN_RADIUS + 3.0, "above the sun")


func test_stored_nar_flies_from_server_into_its_cache_only() -> void:
	var world := World.new()
	world.apply(Effects.CachesListed.new({"c1": "main", "c2": "mirror"}))
	world.apply(Effects.CacheStored.new("c2"))
	var comets := fx_of(world, Comet)
	equal(comets.size(), 1)
	equal(comets[0].source.call(), World.server_position())
	equal(comets[0].target.call(), world.caches["c2"].position)


func offer(world: World, worker: String = "w1") -> void:
	world.apply(Effects.WorkerMessage.new(worker, true, "job_offer", 151))
	world.update(World.MESSAGE_GAP)


func answer(world: World, worker: String = "w1") -> void:
	world.apply(Effects.WorkerMessage.new(worker, false, "request_job_chunk", 0))
	world.update(World.MESSAGE_GAP)


func test_job_offer_sends_a_shockwave_from_the_server_to_the_worker() -> void:
	var world := World.new()
	offer(world)
	var waves := fx_of(world, Shockwave)
	equal(waves.size(), 1)
	equal(waves[0].anchor.call(), World.server_position())
	near(waves[0].reach, world.workers["w1"].position.length(), 0.01)
	check(fx_of(world, Comet).is_empty(), "scoring rides the wave, not a comet")


func reflections(world: World) -> Array:
	return fx_of(world, Shockwave).filter(func(wave): return wave.toward.is_valid())


func test_worker_reflects_only_once_its_scores_come_in() -> void:
	var world := World.new()
	offer(world)
	step(world, World.SHOCK_TIME + 0.1)
	check(reflections(world).is_empty(), "no scores, no reflection")
	answer(world)
	var waves := reflections(world)
	equal(waves.size(), 1)
	equal(waves[0].anchor.call(), world.workers["w1"].position)
	equal(waves[0].toward.call(), World.server_position())
	near(waves[0].reach, world.workers["w1"].position.length(), 0.01)


func test_reflection_is_an_eighth_circle_facing_the_server() -> void:
	var worker := Vector3(40, 0, 0)
	var wave := Shockwave.new(func() -> Vector3: return worker, Color.WHITE, 40.0, 1.0, Callable(), World.server_position, 1.0)
	wave.update(0.5)
	var arc := wave.arc(8)
	for point in arc:
		near(point.distance_to(worker), 20.0, 1e-3, "on the front")
		near(point.y, 0.0, 1e-4, "flat")
	near(arc[0].direction_to(worker).angle_to(arc[arc.size() - 1].direction_to(worker)), PI / 4, 1e-3, "eighth circle")
	near(arc[4].distance_to(World.server_position()), 20.0, 1e-3, "centred on the server")


func test_early_scores_reflect_when_the_wave_arrives() -> void:
	var world := World.new()
	offer(world)
	answer(world)
	check(reflections(world).is_empty(), "wave still travelling")
	step(world, World.SHOCK_TIME + 0.05, 0.01)
	equal(reflections(world).size(), 1)


func reflected_wave(score: float) -> Shockwave:
	var world := World.new()
	world.apply(queued("e1"))
	offer(world)
	answer(world)
	world.apply(Effects.JobDispatched.new("w1", "e1", "", score))
	step(world, World.SHOCK_TIME + 0.05, 0.01)
	return reflections(world)[0]


func test_shockwave_expands_from_the_server_at_constant_speed() -> void:
	var wave := Shockwave.new(World.server_position, Color.WHITE, 40.0, 1.0)
	wave.update(0.5)
	near(wave.radius, 20.0)
	check(wave.update(0.6) == false, "done once it reaches the ring")


func test_dispatch_score_shapes_the_reflection() -> void:
	var good := reflected_wave(3000.0)
	var bad := reflected_wave(20.0)
	check(good.strength > 0.8 and bad.strength < 0.2, "strength by score")
	check(good.color.g > good.color.r and bad.color.r > bad.color.g, "color by score")


func test_dispatch_alone_sends_no_shockwave() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", "", 500.0))
	check(fx_of(world, Shockwave).is_empty(), "waves come from job offers")


func test_evaluations_of_same_group_share_orbit_path_in_formation() -> void:
	var world := World.new()
	world.apply(queued("e1", "p1"))
	world.apply(queued("e2", "p2"))
	world.apply(queued("e3", "p1"))
	var e1: Orbit = world.evaluations["e1"].electron.orbit
	var e2: Orbit = world.evaluations["e2"].electron.orbit
	var e3: Orbit = world.evaluations["e3"].electron.orbit
	check(e1.same_path(e3), "same group, same path")
	check(not e1.same_path(e2), "other group, other path")
	check(e1.phase != e3.phase, "spread along the path")


func test_late_group_moves_evaluation_onto_group_orbit() -> void:
	var world := World.new()
	world.apply(queued("e1", "p1"))
	world.apply(queued("e2"))
	world.apply(Effects.EvaluationChanged.new("e2", "", "", "p1"))
	equal(world.evaluations["e2"].slot, world.evaluations["e1"].slot)
	check(world.evaluations["e2"].electron.orbit.same_path(world.evaluations["e1"].electron.orbit), "joined group path")


func test_evaluation_returning_home_rejoins_group_orbit() -> void:
	var world := World.new()
	world.apply(queued("e1", "p1"))
	world.apply(queued("e2", "p1"))
	world.apply(Effects.JobDispatched.new("w1", "e2", ""))
	world.apply(Effects.EvaluationChanged.new("e2", "building", "", "p1"))
	check(world.evaluations["e2"].electron.orbit.same_path(world.evaluations["e1"].electron.orbit), "rejoined")


func test_created_builds_are_hidden_until_they_progress() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "created"))
	world.apply(Effects.BuildChanged.new("b2", "e1", "queued"))
	equal(world.evaluations["e1"].visible_builds().map(func(b): return b.id), ["b2"])


func test_substituted_build_arrives_on_comet_from_cache() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.CacheAccess.new("c1", "narinfo", true, 0))
	world.fx.clear()
	world.apply(Effects.BuildChanged.new("b1", "e1", "substituted"))
	var build: Bodies.Build = world.evaluations["e1"].builds["b1"]
	var comets := fx_of(world, Comet)
	equal(comets.size(), 1)
	equal(comets[0].source.call(), world.caches["c1"].position)
	check(not build.visible and fx_of(world, Spark).is_empty(), "hidden until landing")
	world.update(comets[0].duration + 0.01)
	check(build.visible and not fx_of(world, Spark).is_empty(), "lands with burst")


func test_substituted_build_comes_only_from_caches_the_evaluation_uploaded_to() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b0", "e1", "building", "d0"))
	for cache in ["c1", "c2", "c3"]:
		world.apply(Effects.CacheAccess.new(cache, "narinfo", true, 0))
	world.apply(Effects.WorkerMessage.new("w1", false, "nar_push", 10, "build:d0"))
	world.apply(Effects.CacheStored.new("c2"))
	world.apply(Effects.WorkerMessage.new("w1", false, "nar_push", 10, "eval:e1"))
	world.apply(Effects.CacheStored.new("c3"))
	equal(world.evaluations["e1"].uploads.keys(), ["c2", "c3"])
	for i in 20:
		world.fx.clear()
		world.apply(Effects.BuildChanged.new("s%d" % i, "e1", "substituted"))
		check(fx_of(world, Comet)[0].source.call() != world.caches["c1"].position, "never from a cache without uploads")


func test_substituted_build_without_cache_falls_from_above() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "substituted"))
	check((fx_of(world, Comet)[0].source.call() as Vector3).y > 20.0, "from the sky")


func test_banner_fades_in_when_workers_idle_and_hides_when_busy() -> void:
	var world := World.new()
	equal(world.banner, 0.0)
	world.update(World.CALM_DELAY + World.CALM_FADE)
	equal(world.banner, 1.0)
	world.apply(queued("e1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", ""))
	world.update(0.1)
	equal(world.banner, 0.0)


func test_banner_waits_thirty_seconds() -> void:
	var world := World.new()
	world.update(29.0)
	equal(world.banner, 0.0)


func test_banner_hides_on_nar_and_log_pushes() -> void:
	for kind in ["nar_push", "log_chunk"]:
		var world := World.new()
		world.update(World.CALM_DELAY + World.CALM_FADE)
		world.apply(Effects.WorkerMessage.new("w1", false, kind, 10))
		world.update(0.1)
		equal(world.banner, 0.0, kind)


func test_evaluation_on_a_worker_stays_while_it_evaluates() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", ""))
	world.apply(Effects.EvaluationChanged.new("e1", "evaluating"))
	step(world, World.EVAL_STALE + World.EVAL_FADE + 5.0, 1.0)
	check(world.evaluations.has("e1"), "evaluation stays while on the worker")


func test_job_messages_keep_their_evaluation_awake() -> void:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "building"))
	step(world, World.EVAL_STALE - 1.0, 1.0)
	world.apply(Effects.WorkerMessage.new("w1", false, "log_chunk", 10, "eval:e1"))
	equal(world.evaluations["e1"].idle, 0.0)


func test_building_build_keeps_evaluation_alive() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "building"))
	step(world, World.EVAL_STALE + World.EVAL_FADE + 1.0, 1.0)
	check(world.evaluations.has("e1"), "evaluation stays while building")


func test_evaluating_evaluation_boards_worker_from_job_message() -> void:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "evaluating"))
	world.apply(Effects.WorkerMessage.new("w1", false, "log_chunk", 10, "eval:e1"))
	equal(world.evaluations["e1"].electron.host, World.worker_host("w1"))


func test_finished_evaluation_ignores_late_job_message() -> void:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "completed"))
	world.apply(Effects.WorkerMessage.new("w1", false, "job_completed", 10, "eval:e1"))
	equal(world.evaluations["e1"].electron.host, World.SERVER)


func test_building_build_boards_worker_from_job_message() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "building", "d1"))
	world.apply(Effects.WorkerMessage.new("w1", false, "job_update", 10, "build:d1"))
	equal(world.evaluations["e1"].builds["b1"].electron.host, World.worker_host("w1"))


func test_average_worker_network_ignores_workers_without_samples() -> void:
	var world := World.new()
	equal(world.average_network(), null)
	world.apply(Effects.WorkerNetwork.new("w1", 10.0))
	world.apply(Effects.WorkerNetwork.new("w2", 30.0))
	world.apply(Effects.WorkerNetwork.new("w3", null))
	equal(world.average_network(), 20.0)


func test_disconnected_worker_loses_its_link_and_regains_it() -> void:
	var world := World.new()
	world.apply(Effects.WorkerLoad.new("w1", 10.0))
	var worker: Bodies.Worker = world.workers["w1"]
	equal([worker.connected, worker.link], [true, 1.0])
	world.apply(Effects.WorkerLink.new("w1", false))
	world.update(World.LINK_FADE / 2)
	check(not worker.connected and worker.link > 0.0 and worker.link < 1.0, "glitching out: %s" % worker.link)
	world.update(World.LINK_FADE)
	equal(worker.link, 0.0)
	world.apply(Effects.WorkerLink.new("w1", true))
	world.update(World.LINK_FADE)
	equal([worker.connected, worker.link], [true, 1.0])


func test_worker_load_sets_cpu_and_overload_throws_sparks() -> void:
	var world := World.new()
	world.apply(Effects.WorkerLoad.new("w1", 40.0))
	var worker: Bodies.Worker = world.workers["w1"]
	check(worker.cpu == 40.0 and not worker.unstable, "calm")
	world.apply(Effects.WorkerLoad.new("w1", 95.0))
	check(worker.unstable, "overloaded")
	var sparked := false
	for i in 60:
		world.update(0.05)
		sparked = sparked or not fx_of(world, Spark).is_empty()
	check(sparked, "sparks")


func test_retired_evaluations_are_freed() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "completed"))
	world.apply(Effects.EvaluationChanged.new("e1", "completed"))
	var gone: WeakRef = weakref(world.evaluations["e1"])
	step(world, World.EVAL_LINGER + World.EVAL_FADE + 3.0)
	check(gone.get_ref() == null, "evaluation freed")


func test_retired_builds_leave_no_derivation_behind() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "completed", "d1"))
	world.apply(Effects.EvaluationChanged.new("e1", "completed"))
	var gone: WeakRef = weakref(world.evaluations["e1"].builds["b1"])
	step(world, World.EVAL_LINGER + World.EVAL_FADE + 3.0)
	check(gone.get_ref() == null, "build freed")


func test_comet_trail_covers_the_last_moments_of_its_path() -> void:
	var target := Vector3(10, 0, 0)
	var comet := Comet.new(func(): return Vector3.ZERO, func(): return target, Color.WHITE, 0.1, 1.0, 0.3)
	comet.update(0.05)
	equal(comet.tail, 0.0, "trail grows from the source")
	comet.update(0.5)
	near(comet.progress - comet.tail, Comet.TRAIL_TIME / comet.duration)
	equal([comet.path().x, comet.path().z], [Vector3.ZERO, target], "path runs from source to target")


func test_server_pulse_erupts_flare_from_the_sun_surface() -> void:
	var world := World.new()
	world.apply(Effects.ServerPulse.new("graph"))
	var flares := fx_of(world, Flare)
	equal(flares.size(), 1)
	world.update(2.0)
	for point in flares[0].points(16):
		check(point.length() >= World.SUN_RADIUS - 0.01, "arc stays above the surface")
	check(Array(flares[0].points(16)).any(func(p): return p.length() > World.SUN_RADIUS), "arc lifts off")
	check(fx_of(world, Spark).is_empty(), "no embers")


func test_most_flares_stay_small_and_few_tower() -> void:
	seed(7)
	var heights := []
	for i in 400:
		heights.append(World.flare_height())
	heights.sort()
	check(heights[200] < World.SUN_RADIUS * 0.12, "median flare is low: %s" % heights[200])
	check(heights[399] > World.SUN_RADIUS * 0.25, "rare flares tower: %s" % heights[399])
	check(heights.filter(func(h): return h > World.SUN_RADIUS * 0.25).size() < 40, "towering flares are rare")


func test_flare_frame_carries_the_arc_for_the_gpu() -> void:
	var flare := Flare.new(Vector3(1, 2, 0.5), 7.0, 1.5, Color.RED, 5.0)
	flare.update(3.0)
	var arc := flare.points(4)
	for i in arc.size():
		var s := i / 4.0
		var local := Vector3(1.0, (s - 0.5) * flare.spread, 0.0).normalized() * (flare.radius + sin(s * PI) * flare.lifted())
		check((flare.frame() * local).is_equal_approx(arc[i]), "point %d" % i)


func test_flare_footpoints_widen_with_height() -> void:
	var low := Flare.new(Vector3.UP, 7.0, 0.3, Color.RED, 5.0)
	var tall := Flare.new(Vector3.UP, 7.0, 3.0, Color.RED, 5.0)
	var span := func(flare: Flare) -> float:
		var arc := flare.points(8)
		return arc[0].distance_to(arc[arc.size() - 1])
	check(span.call(low) < span.call(tall), "tall loops stand on wider footpoints")


func test_only_graph_events_erupt() -> void:
	var world := World.new()
	for effect in EventParser.parse({"event": "cache.nar.fetched", "content": {}}):
		world.apply(effect)
	check(world.core_flash > 0.0, "cache traffic still flashes the core")
	check(fx_of(world, Flare).is_empty(), "no flare from cache traffic")


func test_every_graph_event_erupts() -> void:
	var world := World.new()
	for effect in EventParser.parse({"event": "graph.transitioned", "content": {}}) + EventParser.parse({"event": "graph.requeued", "content": {"requeued": 0}}):
		world.apply(effect)
	for i in 20:
		world.apply(Effects.ServerPulse.new("graph"))
	equal(fx_of(world, Flare).size(), 22)


func test_bodies_remember_when_they_were_first_seen() -> void:
	var world := World.new()
	world.update(3.0)
	world.apply(queued("e1"))
	world.apply(Effects.WorkerMessage.new("w1", true, "assign_job", 1))
	world.apply(Effects.CacheAccess.new("c1", "narinfo", true, 0))
	equal([world.evaluations["e1"].born, world.workers["w1"].born, world.caches["c1"].born], [3.0, 3.0, 3.0])


func test_resolved_names_label_bodies_and_replay_identification() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1-abcdef1234", true, "assign_job", 1))
	world.apply(Effects.CacheAccess.new("c1-abcdef1234", "narinfo", true, 0))
	equal(world.worker_label(world.workers["w1-abcdef1234"]), "worker w1-abcde")
	equal(world.cache_label(world.caches["c1-abcdef1234"]), "cache c1-abcde")
	world.update(5.0)
	world.apply(Effects.Names.new({"w1-abcdef1234": "builder-01", "c1-abcdef1234": "main"}))
	equal(world.worker_label(world.workers["w1-abcdef1234"]), "builder-01")
	equal(world.cache_label(world.caches["c1-abcdef1234"]), "main")
	equal(world.workers["w1-abcdef1234"].born, 5.0)
	world.update(1.0)
	world.apply(Effects.Names.new({"w1-abcdef1234": "builder-01"}))
	equal(world.workers["w1-abcdef1234"].born, 5.0)


func test_empty_messages_are_logged_without_size() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1", false, "request_job", 0))
	equal(world.messages[0].text, "{0}  <-  request_job")


func test_pushes_are_paced_by_a_coin_flip_of_zero_or_one_millisecond() -> void:
	for kind in World.ACTIVITY:
		var world := World.new()
		var previous := 0.0
		var gaps := {}
		for i in 60:
			world.apply(Effects.WorkerMessage.new("w1", false, kind, 10))
			var next: float = world.pacing["w1"]
			gaps[snappedf(next - previous, 1e-6)] = true
			previous = next
		equal(gaps.keys().filter(func(gap): return gap != 0.0 and gap != 0.001), [], kind)
		equal(gaps.size(), 2, "%s uses both gaps" % kind)


func test_worker_messages_are_logged_newest_first_and_capped() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1-abcdef12", false, "log_chunk", 2048))
	world.apply(Effects.WorkerMessage.new("w1-abcdef12", true, "assign_job", 320))
	world.update(World.MESSAGE_GAP)
	equal(world.messages.size(), 2)
	check(world.messages[0].text.contains("assign_job") and world.messages[0].text.contains("->"), "newest outbound first: %s" % world.messages[0].text)
	check(world.messages[1].text.contains("<-") and world.messages[1].text.contains("2.0 kB"), "inbound with size: %s" % world.messages[1].text)
	for i in 40:
		world.apply(Effects.WorkerMessage.new("w1", false, "log_chunk", 1))
	world.update(40 * World.MESSAGE_GAP)
	equal(world.messages.size(), World.MAX_MESSAGES)


func test_log_lines_resolve_names_when_they_become_known() -> void:
	var world := World.new()
	for effect in EventParser.parse({"event": "worker.job_dispatched", "content": {"worker_id": "w1-abcdef1234", "evaluation_id": "e1"}}):
		world.apply(effect)
	equal(world.describe(world.headlines[0]), "dispatch   -> worker w1-abcde")
	world.apply(Effects.WorkerMessage.new("w1-abcdef1234", false, "log_chunk", 10))
	world.apply(Effects.Names.new({"w1-abcdef1234": "builder-01"}))
	equal(world.describe(world.headlines[0]), "dispatch   -> builder-01")
	check(world.describe(world.messages[0]).begins_with("builder-01  <-"), world.describe(world.messages[0]))
	for effect in EventParser.parse({"event": "evaluation.queued", "content": {"evaluation_id": "e1", "status": 0, "repository": "https://github.com/wavelens/gobgp.nix"}}):
		world.apply(effect)
	check(world.describe(world.headlines[0]).ends_with("gobgp.nix"), world.describe(world.headlines[0]))


func test_listed_caches_appear_before_any_access() -> void:
	var world := World.new()
	world.apply(Effects.CachesListed.new({"c1": "main", "c2": "mirror"}))
	equal(world.caches.keys().size(), 2)
	equal(world.cache_label(world.caches["c2"]), "mirror")
	world.apply(Effects.CacheAccess.new("c1", "narinfo", true, 0))
	equal(world.caches.size(), 2)


func test_cache_query_pings_every_cache() -> void:
	var world := World.new()
	world.apply(Effects.CacheQueried.new())
	check(fx_of(world, Echo).is_empty(), "no caches, no pings")
	world.apply(Effects.CachesListed.new({"c1": "main", "c2": "mirror"}))
	world.apply(Effects.CacheQueried.new())
	var targets := fx_of(world, Echo).map(func(echo): return echo.target.call())
	equal(targets, [world.caches["c1"].position, world.caches["c2"].position])


func test_completed_build_feeds_no_cache_by_itself() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.CachesListed.new({"c1": "main"}))
	world.apply(Effects.BuildChanged.new("b1", "e1", "completed"))
	check(fx_of(world, Comet).is_empty(), "only cache.nar.signed feeds a cache")


func test_dispatched_queued_evaluation_is_fetching() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", ""))
	equal(world.evaluations["e1"].phase, "fetching")


func test_queued_evaluation_with_job_traffic_is_fetching_on_that_worker() -> void:
	var world := World.new()
	world.apply(queued("e1"))
	world.apply(Effects.WorkerMessage.new("w1", false, "job_update", 10, "eval:e1"))
	equal([world.evaluations["e1"].phase, world.evaluations["e1"].electron.host], ["fetching", "worker:w1"])


func test_evaluating_evaluation_keeps_phase_on_dispatch() -> void:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "evaluating"))
	world.apply(Effects.JobDispatched.new("w1", "e1", ""))
	equal(world.evaluations["e1"].phase, "evaluating")


func test_banner_shows_after_ten_minutes_without_nar_push_even_when_busy() -> void:
	var world := World.new()
	world.apply(Effects.JobDispatched.new("w1", "e1", ""))
	world.update(World.PUSH_DROUGHT - 1.0)
	world.apply(Effects.WorkerMessage.new("w1", false, "log_chunk", 10))
	equal(world.banner, 0.0)
	world.update(1.0 + World.CALM_FADE)
	world.apply(Effects.WorkerMessage.new("w1", false, "log_chunk", 10))
	equal(world.banner, 1.0)
	world.apply(Effects.WorkerMessage.new("w1", false, "nar_push", 10))
	world.update(0.1)
	equal(world.banner, 0.0)


func test_worker_messages_are_paced_per_worker() -> void:
	var world := World.new()
	for i in 3:
		world.apply(Effects.WorkerMessage.new("w1", false, "job_update", 10))
	world.apply(Effects.WorkerMessage.new("w2", false, "job_update", 10))
	equal(world.messages.size(), 2)
	world.update(World.MESSAGE_GAP)
	equal(world.messages.size(), 3)
	world.update(World.MESSAGE_GAP)
	equal(world.messages.size(), 4)


func test_message_backlog_lag_is_bounded() -> void:
	var world := World.new()
	for i in 1000:
		world.apply(Effects.WorkerMessage.new("w1", false, "job_update", 10))
	world.update(World.MESSAGE_LAG)
	equal(world.messages.size(), World.MAX_MESSAGES)
	check(world.backlog.is_empty(), "backlog drained")


func test_resolved_names_label_evaluations() -> void:
	var world := World.new()
	world.apply(Effects.JobDispatched.new("w1", "e1-abcdef1234", ""))
	equal(world.evaluations["e1-abcdef1234"].label, "e1-abcde")
	world.apply(Effects.Names.new({"e1-abcdef1234": "gobgp.nix"}))
	equal(world.evaluations["e1-abcdef1234"].label, "gobgp.nix")
	world.apply(Effects.Names.new({"e2-abcdef1234": "other"}))
	world.apply(Effects.JobDispatched.new("w1", "e2-abcdef1234", ""))
	equal(world.evaluations["e2-abcdef1234"].label, "other")
