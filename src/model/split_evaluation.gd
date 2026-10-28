# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name SplitEvaluation
## An evaluation split across workers: shard 0 is the evaluation body itself on the primary worker, every companion shard is a piece on its own worker.

const JOB_ENDS := ["job_completed", "job_failed", "abort_job"]
const SHARD_REPLY := "eval_shard_reply"


static func shard_index(job_id: String) -> int:
	if job_id.get_slice(":", 0) != "eval":
		return -1
	return int(job_id.get_slice(":", 2)) if job_id.get_slice_count(":") > 2 else 0


static func on_message(world: World, evaluation: Bodies.Evaluation, index: int, message: Effects.WorkerMessage, worker: Bodies.Worker) -> void:
	if index == 0:
		evaluation.primary_worker = worker.id
		return
	if message.kind in JOB_ENDS:
		_end(world, evaluation, index)
		return
	if message.kind == "assign_job":
		evaluation.ended_shards.erase(index)
	if not evaluation.ended_shards.has(index):
		_claim(world, evaluation, index, worker)
	if message.kind == SHARD_REPLY and message.outbound:
		_shard_reply(world, evaluation, worker)


static func merge(world: World, evaluation: Bodies.Evaluation) -> void:
	for index in evaluation.shards.keys():
		_end(world, evaluation, index)


static func update(evaluation: Bodies.Evaluation, dt: float) -> void:
	for index in evaluation.shards.keys():
		var shard: Bodies.Shard = evaluation.shards[index]
		shard.electron.update(dt)
		if shard.merging and shard.electron.hop >= 1.0:
			evaluation.shards.erase(index)
			evaluation.flash = maxf(evaluation.flash, 0.6)


static func _claim(world: World, evaluation: Bodies.Evaluation, index: int, worker: Bodies.Worker) -> void:
	var host := World.worker_host(worker.id)
	var shard: Bodies.Shard = evaluation.shards.get(index)
	if shard and shard.electron.host == host:
		return
	if not shard:
		shard = Bodies.Shard.new(worker.id, Electron.new(World.evaluation_host(evaluation.id), world.follow(evaluation.electron), Orbit.new(0.0, 0.0, 0.0, 0.0), evaluation.position))
		evaluation.shards[index] = shard
	shard.worker_id = worker.id
	shard.merging = false
	world.board(shard, worker)


static func _end(world: World, evaluation: Bodies.Evaluation, index: int) -> void:
	evaluation.ended_shards[index] = true
	var shard: Bodies.Shard = evaluation.shards.get(index)
	if not shard or shard.merging:
		return
	shard.merging = true
	shard.electron.jump(World.evaluation_host(evaluation.id), world.follow(evaluation.electron), Orbit.new(0.0, 0.0, 0.0, 0.0))


static func _shard_reply(world: World, evaluation: Bodies.Evaluation, companion: Bodies.Worker) -> void:
	var primary: Bodies.Worker = world.workers.get(evaluation.primary_worker)
	var source := (func() -> Vector3: return primary.position) if primary else world.follow(evaluation.electron)
	var arrive := func() -> void: companion.heat = 1.0
	world.spawn([RingComet.new(source, func() -> Vector3: return companion.position, Palette.SHARD, 0.09, randf_range(1.2, 1.6), arrive)])
