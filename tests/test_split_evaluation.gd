# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func step(world: World, seconds: float, dt: float = 0.05) -> void:
	for i in ceili(seconds / dt):
		world.update(dt)


func send(world: World, worker: String, outbound: bool, kind: String, job_id: String) -> void:
	world.apply(Effects.WorkerMessage.new(worker, outbound, kind, 10, job_id))
	world.update(0.1)


func split_world() -> World:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "queued"))
	send(world, "w1", true, "assign_job", "eval:e1")
	send(world, "w2", true, "assign_job", "eval:e1:1")
	send(world, "w3", true, "assign_job", "eval:e1:2")
	return world


func test_shard_index_parses_job_keys() -> void:
	equal(SplitEvaluation.shard_index("eval:e1"), 0)
	equal(SplitEvaluation.shard_index("eval:e1:2"), 2)
	equal(SplitEvaluation.shard_index("build:d1"), -1)


func test_companion_claims_split_the_evaluation_onto_their_workers() -> void:
	var evaluation: Bodies.Evaluation = split_world().evaluations["e1"]
	equal(evaluation.electron.host, World.worker_host("w1"))
	equal(evaluation.shards.keys(), [1, 2])
	equal(evaluation.shards[1].electron.host, World.worker_host("w2"))
	equal(evaluation.shards[2].electron.host, World.worker_host("w3"))


func test_shard_reply_draws_a_comet_from_the_primary_worker_to_the_companion() -> void:
	var world := split_world()
	step(world, 2.0)
	send(world, "w3", true, "eval_shard_reply", "eval:e1:2")
	var shard_comets := world.fx.filter(func(effect): return effect is Comet and effect.color == Palette.SHARD)
	equal(shard_comets.size(), 1)
	near(shard_comets[0].source.call().distance_to(world.workers["w1"].position), 0.0)
	near(shard_comets[0].target.call().distance_to(world.workers["w3"].position), 0.0)


func test_a_finished_companion_job_merges_its_piece() -> void:
	var world := split_world()
	send(world, "w2", false, "job_completed", "eval:e1:1")
	step(world, 2.0)
	equal(world.evaluations["e1"].shards.keys(), [2])
	send(world, "w2", false, "log_chunk", "eval:e1:1")
	equal(world.evaluations["e1"].shards.keys(), [2])


func test_a_reassigned_shard_jumps_without_a_duplicate() -> void:
	var world := split_world()
	send(world, "w4", true, "assign_job", "eval:e1:1")
	var evaluation: Bodies.Evaluation = world.evaluations["e1"]
	equal(evaluation.shards.keys(), [1, 2])
	equal(evaluation.shards[1].electron.host, World.worker_host("w4"))


func test_leaving_the_worker_phases_merges_every_piece() -> void:
	var world := split_world()
	world.apply(Effects.EvaluationChanged.new("e1", "building"))
	step(world, 2.0)
	check(world.evaluations["e1"].shards.is_empty(), "all pieces merged")
