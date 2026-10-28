# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func step(world: World, seconds: float, dt: float = 0.1) -> void:
	for i in ceili(seconds / dt):
		world.update(dt)


func dispatched_build(world: World) -> Bodies.Build:
	world.apply(Effects.EvaluationChanged.new("e1", "building"))
	world.apply(Effects.BuildChanged.new("b1", "e1", "queued", "d1"))
	world.apply(Effects.JobDispatched.new("w1", "e1", "d1"))
	return world.evaluations["e1"].builds["b1"]


func test_dispatched_build_without_start_survives_stale() -> void:
	var world := World.new()
	var build := dispatched_build(world)
	step(world, World.EVAL_STALE + World.EVAL_FADE + 1.0)
	check(world.evaluations.has("e1"), "evaluation kept")
	equal(build.electron.host, World.worker_host("w1"))


func test_build_traffic_keeps_evaluation_awake() -> void:
	var world := World.new()
	dispatched_build(world)
	step(world, 5.0)
	world.apply(Effects.WorkerMessage.new("w1", false, "log_chunk", 10, "build:d1"))
	step(world, 0.1)
	check(world.evaluations["e1"].idle < 1.0, "idle reset by build traffic")
