# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func step(world: World, seconds: float, dt: float = 0.05) -> void:
	for i in ceili(seconds / dt):
		world.update(dt)


func comets(world: World) -> Array:
	return world.fx.filter(func(effect): return effect is Comet)


func vm(world: World, state: String, job_id: String = "", id: String = "v1") -> void:
	world.apply(Effects.VmChanged.new("w1", id, state, job_id))


func test_vm_lifecycle_warm_running_stopped() -> void:
	var world := World.new()
	vm(world, "warm")
	var moon: Bodies.Vm = world.vms["v1"]
	equal(moon.electron.host, World.worker_host("w1"))
	check(not moon.lit, "warm moon is dark")
	vm(world, "running", "exec:j1")
	check(moon.lit, "running moon glows")
	vm(world, "stopped", "exec:j1")
	step(world, World.EVAL_FADE + 0.5)
	check(not world.vms.has("v1"), "stopped moon removed")


func test_the_stop_of_an_unseen_vm_spawns_no_moon() -> void:
	var world := World.new()
	vm(world, "stopped")
	check(world.vms.is_empty(), "no phantom moon")


func test_moons_fade_when_their_worker_disconnects() -> void:
	var world := World.new()
	vm(world, "warm")
	world.apply(Effects.WorkerLink.new("w1", false))
	step(world, World.EVAL_FADE + 0.5)
	check(world.vms.is_empty(), "moons of an offline worker removed")


func test_reconnect_snapshot_keeps_a_live_moon() -> void:
	var world := World.new()
	vm(world, "warm")
	world.apply(Effects.WorkerLink.new("w1", false))
	step(world, 0.5)
	world.apply(Effects.WorkerLink.new("w1", true))
	vm(world, "warm")
	step(world, World.EVAL_FADE + 0.5)
	check(world.vms.has("v1"), "live moon kept after reconnect")


func test_fallback_moon_ends_with_the_job_messages() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1", true, "assign_job", 300, "exec:j1"))
	world.update(0.1)
	world.apply(Effects.WorkerMessage.new("w1", false, "job_completed", 50, "exec:j1"))
	step(world, World.EVAL_LINGER + World.EVAL_FADE + 0.5)
	check(world.vms.is_empty(), "fallback moon removed without exec_job events")


func test_running_vm_gets_a_comet_from_its_evaluation() -> void:
	var world := World.new()
	world.apply(Effects.EvaluationChanged.new("e1", "building"))
	world.apply(Effects.ExecJobChanged.new("exec:j1", "e1", "queued", "train"))
	vm(world, "running", "exec:j1")
	var from_evaluation := comets(world).filter(func(comet): return comet.source.call() == world.evaluations["e1"].position)
	equal(from_evaluation.size(), 1)


func test_fallback_moon_without_vm_events() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1", true, "assign_job", 300, "exec:j1"))
	world.update(0.1)
	check(world.vms.has("exec:j1"), "fallback moon spawned")
	check(world.vms["exec:j1"].lit, "fallback moon glows")
	world.apply(Effects.ExecJobChanged.new("exec:j1", "e1", "completed", "train"))
	step(world, World.EVAL_LINGER + World.EVAL_FADE + 0.5)
	check(not world.vms.has("exec:j1"), "fallback moon removed after the job ended")


func test_real_vm_replaces_the_fallback_moon() -> void:
	var world := World.new()
	world.apply(Effects.WorkerMessage.new("w1", true, "assign_job", 300, "exec:j1"))
	world.update(0.1)
	vm(world, "running", "exec:j1")
	equal(world.vms.keys(), ["v1"])


func test_exec_client_message_chains_moon_worker_server() -> void:
	var world := World.new()
	vm(world, "running", "exec:j1")
	step(world, 2.0)
	world.fx.clear()
	world.apply(Effects.WorkerMessage.new("w1", false, "job_phase", 20, "exec:j1"))
	world.update(0.01)
	var first: Comet = comets(world)[0]
	equal(comets(world).size(), 1)
	near(first.target.call().distance_to(world.workers["w1"].position), 0.0)
	step(world, first.duration + 0.1)
	var second := comets(world).filter(func(comet): return comet.target.call() == World.server_position())
	equal(second.size(), 1)
