# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name VmMoons
## VMs orbit their worker as moons; an exec job is the lit moon. Logs without `vm.state` get a moon keyed by the exec job.

const ORBIT := World.WORKER_ORBIT_MAX + 1.5
const TERMINAL := ["completed", "failed", "aborted"]


static func vm_changed(world: World, change: Effects.VmChanged) -> void:
	if change.job_id and world.vms.has(change.job_id):
		world.vms.erase(change.job_id)
	var moon := _moon(world, change.vm, change.worker_id)
	moon.flash = 1.0
	moon.link = 1.0
	match change.state:
		"warm":
			moon.lit = false
		"running":
			_light(world, moon, change.job_id)
		"stopped":
			moon.fading = true


static func exec_job_changed(world: World, change: Effects.ExecJobChanged) -> void:
	world.exec_jobs[change.job_id] = change
	var moon := _moon_of(world, change.job_id)
	if not moon:
		return
	moon.link = 1.0
	if change.state not in TERMINAL:
		return
	var color := Palette.state(change.state)
	moon.color = color
	moon.flash = 1.0
	if change.state in EventParser.BAD:
		world.spawn(Spark.burst(moon.position, color, 45, 6.4, 1.3))
	else:
		world.spawn(Spark.burst(moon.position, color, 18, 3.8, 0.9))
	if moon.synthetic:
		moon.linger = World.EVAL_LINGER


static func exec_message(world: World, message: Effects.WorkerMessage, worker: Bodies.Worker) -> bool:
	if not message.job_id.begins_with("exec:"):
		return false
	var moon := _moon_of(world, message.job_id)
	if not moon and message.outbound and message.kind == "assign_job":
		moon = _moon(world, message.job_id, worker.id)
		moon.synthetic = true
		_light(world, moon, message.job_id)
	if not moon:
		return false
	moon.link = 1.0
	var at_moon := func() -> Vector3: return moon.position
	var at_worker := func() -> Vector3: return worker.position
	var color := Palette.message(message.kind)
	var size := (1.5 + log(message.size + 1.0) / log(10.0) * 0.9) * 0.034
	if message.outbound:
		_chain(world, World.server_position, at_worker, at_moon, color, size, func() -> void: moon.flash = 1.0)
	else:
		_chain(world, at_moon, at_worker, World.server_position, color, size, func() -> void: world.core_flash = maxf(world.core_flash, 0.35))
	return true


static func update(world: World, dt: float) -> void:
	for id in world.vms.keys():
		var moon: Bodies.Vm = world.vms[id]
		moon.electron.update(dt)
		moon.flash *= pow(0.1, dt)
		moon.link *= pow(0.25, dt)
		if moon.linger >= 0.0:
			moon.linger -= dt
			moon.fading = moon.fading or moon.linger < 0.0
		if moon.fading:
			moon.alpha -= dt / World.EVAL_FADE
		if moon.alpha <= 0.0:
			world.vms.erase(id)


static func _moon(world: World, id: String, worker_id: String) -> Bodies.Vm:
	if world.vms.has(id):
		return world.vms[id]
	var worker := world.worker_body(worker_id)
	var index := world.vms.values().filter(func(moon): return moon.worker_id == worker_id).size()
	var radius := ORBIT + 0.4 * (index % 3)
	var orbit := Orbit.new(radius, randf_range(0.1, 0.4), randf() * TAU, Orbit.kepler_speed(radius, 1) * 1.3, randf() * TAU)
	var moon := Bodies.Vm.new(id, worker_id, Electron.new(World.worker_host(worker_id), func() -> Vector3: return worker.position, orbit, worker.position, 0.0))
	world.vms[id] = moon
	return moon


static func _moon_of(world: World, job_id: String) -> Bodies.Vm:
	for moon in world.vms.values():
		if moon.job_id == job_id:
			return moon
	return null


static func _light(world: World, moon: Bodies.Vm, job_id: String) -> void:
	moon.lit = true
	moon.job_id = job_id
	var job: Effects.ExecJobChanged = world.exec_jobs.get(job_id)
	var evaluation: Bodies.Evaluation = world.evaluations.get(job.evaluation_id) if job else null
	moon.color = Palette.state(evaluation.phase) if evaluation else Palette.state("evaluating")
	if evaluation:
		world.spawn([Comet.new(world.follow(evaluation.electron), func() -> Vector3: return moon.position, moon.color, 0.09, randf_range(1.0, 1.3), randf_range(-0.3, 0.3))])


static func _chain(world: World, from: Callable, via: Callable, to: Callable, color: Color, size: float, arrive: Callable) -> void:
	var second := func() -> void: world.spawn([Comet.new(via, to, color, size, randf_range(0.55, 0.9), randf_range(-0.3, 0.3), arrive)])
	world.spawn([Comet.new(from, via, color, size, randf_range(0.3, 0.45), randf_range(-0.3, 0.3), second)])
