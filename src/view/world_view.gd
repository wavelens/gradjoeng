class_name WorldView
extends Node3D
## Redraws the whole world every frame around a shader-driven sun: additive billboards for glows and rings,
## cel-shaded discs with depth for bodies, camera-facing ribbons for trails, orbits and flares.

const GLOW_SHADER := preload("res://src/shaders/glow.gdshader")
const BODY_SHADER := preload("res://src/shaders/body.gdshader")
const PLANET_SHADER := preload("res://src/shaders/planet.gdshader")
const RIBBON_SHADER := preload("res://src/shaders/ribbon.gdshader")
const SUN_SHADER := preload("res://src/shaders/sun.gdshader")
const CHROMOSPHERE_SHADER := preload("res://src/shaders/chromosphere.gdshader")
const SKY_SHADER := preload("res://src/shaders/sky.gdshader")
const PROMINENCE_SHADER := preload("res://src/shaders/prominence.gdshader")
const LENS_SHADER := preload("res://src/shaders/lens.gdshader")
const STRANDS := [1.0, 0.93, 1.05, 0.88]
const GLOW_LEVELS := [0.0, 0.3, 0.3, 0.1, 0.0, 0.0, 0.0]

const GLOW := Color(0, 0, 0, 0)
const RING := 1.0
const ORBIT_SEGMENTS := 128
const WORKER_RADIUS := 1.2
const EVALUATION_RADIUS := 0.36
const BUILD_RADIUS := 0.17
const CACHE_RADIUS := 2.0
const SUNLIGHT := Color("ff6a3d")
const RIM_REACH := 1.08
const LINK_LANE := 0.085
const LINK_PACKETS := 40
const LINK_DASH := 0.3
const LINK_SPEED := 7.5
const CACHE_DASH := 0.6
const CACHE_GAP := 0.4
const LABEL := Color("e6e6f5")

var glows := SpriteBatch.new(GLOW_SHADER)
var bodies := SpriteBatch.new(BODY_SHADER)
var planets := SpriteBatch.new(PLANET_SHADER)
var ribbons := RibbonBatch.new(RIBBON_SHADER)
var prominences := RibbonBatch.new(PROMINENCE_SHADER)
var labels := LabelPool.new()
var sun := MeshInstance3D.new()
var chromosphere := MeshInstance3D.new()
var lens := ColorRect.new()
var satellites := {}
var eye := Vector3.ZERO


func _ready() -> void:
	for child in [_environment(), _lens(), _sun(), _sunlight(), _chromosphere(), prominences, ribbons, glows, bodies, planets, labels]:
		add_child(child)


func transmit(transmission: Transmission) -> void:
	lens.material.set_shader_parameter("glitch", transmission.glitch)
	if transmission.glitch > 0.0:
		lens.material.set_shader_parameter("seed", float(randi() % 997))


func draw(world: World, p_eye: Vector3) -> void:
	eye = p_eye
	glows.begin()
	bodies.begin()
	planets.begin()
	ribbons.begin(eye)
	prominences.begin(eye)
	labels.begin()
	_links(world)
	_orbits(world)
	_ripples(world)
	_comets(world)
	_echoes(world)
	_server(world)
	_caches(world)
	_workers(world)
	_evaluations(world)
	_sparks(world)
	glows.commit()
	bodies.commit()
	planets.commit()
	ribbons.commit()
	prominences.commit()
	labels.commit()


static func planet_seed(worker_id: String) -> float:
	return float(absi(hash(worker_id)) % 997) / 997.0


func _environment() -> WorldEnvironment:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_color_correction = FilmLut.texture()
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.4
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for level in GLOW_LEVELS.size():
		environment.set_glow_level(level, GLOW_LEVELS[level])
	var node := WorldEnvironment.new()
	node.environment = environment
	return node


func _lens() -> CanvasLayer:
	lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens.material = _material(LENS_SHADER)
	var layer := CanvasLayer.new()
	layer.layer = 0
	layer.add_child(lens)
	return layer


func _sun() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = World.SUN_RADIUS
	sphere.height = World.SUN_RADIUS * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	sun.mesh = sphere
	sun.material_override = _material(SUN_SHADER)
	return sun


func _sunlight() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = SUNLIGHT
	light.light_energy = 6.0
	light.omni_range = 400.0
	light.omni_attenuation = 0.4
	return light


func _chromosphere() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * World.SUN_RADIUS * RIM_REACH * 2.0
	chromosphere.mesh = quad
	chromosphere.material_override = _material(CHROMOSPHERE_SHADER)
	chromosphere.material_override.set_shader_parameter("inner", 1.0 / RIM_REACH)
	return chromosphere


func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _links(world: World) -> void:
	for worker in world.workers.values():
		_link(world, World.server_position(), worker.position, 0.5 + worker.heat)


func _link(world: World, start: Vector3, end: Vector3, energy: float) -> void:
	var span := end - start
	var length := maxf(span.length(), 0.01)
	var side := span.cross(Vector3.UP).normalized() * LINK_LANE
	var base := Palette.shade(Palette.LINK, 0.5 * energy)
	ribbons.segment(start, end, base, base, LINK_LANE * 2.0)
	for direction in [-1, 1]:
		var lane := func(t: float) -> Vector3: return start + span * t + side * direction
		var rail := Palette.shade(Palette.LINK, 1.0 * energy)
		ribbons.segment(lane.call(0.0), lane.call(1.0), rail, rail, 0.015)
		for i in LINK_PACKETS:
			var flow := fposmod(float(i) / LINK_PACKETS + world.time * LINK_SPEED * direction / length, 1.0)
			var packet := Palette.shade(Palette.LINK_PACKET, 0.08 + 0.12 * energy)
			ribbons.segment(lane.call(flow), lane.call(minf(flow + LINK_DASH / length, 1.0)), packet, packet, 0.035)


func _orbits(world: World) -> void:
	for evaluation in world.evaluations.values():
		var color := Palette.shade(Palette.state(evaluation.phase), 0.06 + evaluation.flash * 0.18)
		_orbit_ring(evaluation.electron, Color(color, evaluation.alpha))
		for build in evaluation.visible_builds():
			if not build.electron.host.begins_with("evaluation:"):
				_orbit_ring(build.electron, Color(Palette.shade(Palette.state(build.state), 0.1), evaluation.alpha))


func _orbit_ring(electron: Electron, color: Color) -> void:
	var center: Vector3 = electron.anchor.call()
	var points := electron.orbit.path(ORBIT_SEGMENTS)
	for i in points.size():
		points[i] += center
	ribbons.strip(points, color, 0.05, true)


func _ripples(world: World) -> void:
	for ripple in world.fx:
		if ripple is Ripple and ripple.current_radius > ripple.width:
			var width := minf(ripple.width / ripple.current_radius, 0.5)
			glows.add(ripple.anchor.call(), ripple.current_radius, Color(ripple.color, ripple.fade), Color(RING, width, 0, 0))


func _comets(world: World) -> void:
	for comet in world.fx:
		if comet is Comet and not comet.trail.is_empty():
			ribbons.strip(comet.trail, comet.color, comet.size, false, true)
			var head: Vector3 = comet.trail[comet.trail.size() - 1]
			glows.add(head, comet.size * 4.0, Palette.shade(comet.color, 0.8))
			glows.add(head, comet.size * 1.2, Color.WHITE)


func _echoes(world: World) -> void:
	for echo in world.fx:
		if echo is Echo:
			var at: Vector3 = echo.position
			var swell := sin(PI * echo.progress)
			glows.add(at, 0.2 + 0.42 * echo.strength, Palette.shade(echo.color, echo.strength * 0.9))
			for ring in 3:
				var fade: float = echo.strength * (1.0 - ring / 3.0) * (0.4 + 0.6 * swell)
				glows.add(at, 0.09 + ring * 0.15 + swell * 0.2, Color(echo.color, fade), Color(RING, 0.15, 0, 0))


func _server(world: World) -> void:
	chromosphere.material_override.set_shader_parameter("energy", 1.0 + world.core_flash * 0.3)
	for flare in world.fx:
		if flare is Flare:
			for strand in STRANDS.size():
				var seed := float(flare.get_instance_id() % 97 + strand * 31) / 128.0
				var width := clampf(flare.height * 0.12, 0.06, 0.35)
				prominences.strip(flare.points(32, STRANDS[strand]), Color(0, 0, seed, flare.fade), width)


func _caches(world: World) -> void:
	for cache in world.caches.values():
		var link := Palette.shade(Palette.CACHE, 0.25 + cache.flash * 0.5)
		ribbons.dashed(World.server_position(), cache.position, link, 0.025, CACHE_DASH, CACHE_GAP)
		_satellite(cache.id).place(cache.position, world.time, cache.flash, cache.alarm)
		var age: float = world.time - cache.born
		labels.show_text(Detection.decoded(world.cache_label(cache), age, hash(cache.id)), cache.position + Vector3.DOWN * 1.6, Palette.CACHE.lightened(0.3))
		var stats := "hit %d  miss %d  %.1f MB" % [cache.hits, cache.misses, cache.served / 1e6]
		labels.show_text(Detection.decoded(stats, age - 0.15, hash(stats.length())), cache.position + Vector3.DOWN * 2.3, Palette.CACHE.lightened(0.1), 0.75)


func _satellite(cache_id: String) -> Satellite:
	if not satellites.has(cache_id):
		satellites[cache_id] = Satellite.new()
		add_child(satellites[cache_id])
	return satellites[cache_id]


func _workers(world: World) -> void:
	for worker in world.workers.values():
		var color: Color = Palette.WORKER if worker.cpu == null else Palette.cpu(worker.cpu)
		var at: Vector3 = worker.position
		var heat: float = worker.heat
		if worker.unstable:
			at += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.07
			heat = maxf(heat, randf())
		var pulse := 0.5 + 0.5 * sin(world.time * 3.0 + at.x)
		var behind := at + (at - eye).normalized() * WORKER_RADIUS
		glows.add(behind, 1.9 + heat * 0.85 + pulse * 0.14, Palette.shade(color.lerp(Palette.ATMOSPHERE, 0.5), (0.7 + heat * 0.6) * 0.3))
		planets.add(at, WORKER_RADIUS, color, Color(planet_seed(worker.id), heat, 0, 0))
		var label := world.worker_label(worker)
		if worker.cpu != null:
			label += "  %d%%" % roundi(worker.cpu)
		labels.show_text(Detection.decoded(label, world.time - worker.born, hash(worker.id)), at + Vector3.UP * (WORKER_RADIUS + 0.7), color)


func _evaluations(world: World) -> void:
	for evaluation in world.evaluations.values():
		var color := Palette.state(evaluation.phase)
		var alpha: float = evaluation.alpha
		var at: Vector3 = evaluation.position
		ribbons.strip(evaluation.electron.trail, Color(color, alpha), 0.15, false, true)
		glows.add(at, 0.48 + evaluation.flash * 0.68, Palette.shade(color, alpha * (0.6 + evaluation.flash * 0.8)))
		bodies.add(at, EVALUATION_RADIUS, Color(color, alpha), Color(0.28, 0, 0, 0))
		var age: float = world.time - evaluation.born
		labels.show_text(Detection.decoded(evaluation.label, age, hash(evaluation.label)), at + Vector3.UP * 0.85, Color(LABEL, alpha))
		labels.show_text(Detection.decoded(evaluation.phase, age - 0.15, hash(evaluation.phase)), at + Vector3.DOWN * 0.8, Color(color, alpha), 0.8)
		for build in evaluation.visible_builds():
			_build(build, alpha)


func _build(build: Bodies.Build, alpha: float) -> void:
	var color := Palette.state(build.state)
	var trail := build.electron.trail.slice(maxi(build.electron.trail.size() - 10, 0))
	ribbons.strip(trail, Color(color, alpha * 0.8), 0.06, false, true)
	glows.add(build.position, 0.34 + build.flash * 0.42, Palette.shade(color, alpha * (1.1 + build.flash) * 0.5))
	bodies.add(build.position, BUILD_RADIUS, Color(color, alpha), Color(0.35, 0, 0, 0))


func _sparks(world: World) -> void:
	for spark in world.fx:
		if spark is Spark:
			glows.add(spark.position, spark.size * 3.0, Palette.shade(spark.color, spark.fade))
			glows.add(spark.position, spark.size * 0.6, Palette.shade(Color.WHITE, spark.fade))
