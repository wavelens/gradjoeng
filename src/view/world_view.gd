# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name WorldView
extends Node3D
## Redraws the whole world every frame around a shader-driven sun: additive billboards for glows and rings,
## cel-shaded discs with depth for bodies, camera-facing segments for trails and links, and shader-bent strips for orbits and flares.

const GLOW_SHADER := preload("res://src/shaders/glow.gdshader")
const BODY_SHADER := preload("res://src/shaders/body.gdshader")
const PLANET_SHADER := preload("res://src/shaders/planet.gdshader")
const RIBBON_SHADER := preload("res://src/shaders/ribbon.gdshader")
const SUN_SHADER := preload("res://src/shaders/sun.gdshader")
const CHROMOSPHERE_SHADER := preload("res://src/shaders/chromosphere.gdshader")
const SKY_SHADER := preload("res://src/shaders/sky.gdshader")
const PROMINENCE_SHADER := preload("res://src/shaders/prominence.gdshader")
const LENS_SHADER := preload("res://src/shaders/lens.gdshader")
const ORBIT_SHADER := preload("res://src/shaders/orbit.gdshader")
const LINK_SHADER := preload("res://src/shaders/link.gdshader")
const COMET_SHADER := preload("res://src/shaders/comet.gdshader")
const COMET_HEAD_SHADER := preload("res://src/shaders/comet_head.gdshader")
const STRANDS := [1.0, 0.93, 1.05, 0.88]
const GLOW_LEVELS := [0.0, 0.3, 0.3, 0.1, 0.0, 0.0, 0.0]

const GLOW := Color(0, 0, 0, 0)
const RING := 1.0
const ORBIT_SEGMENTS := 128
const FLARE_SEGMENTS := 32
const ORBIT_WIDTH := 0.035
const WORKER_RADIUS := 1.2
const EVALUATION_RADIUS := 0.36
const BUILD_RADIUS := 0.17
const CACHE_RADIUS := 2.0
const SUNLIGHT := Color("ff6a3d")
const AMBIENT := Color("8fa3c8")
const RIM_REACH := 1.08
const LINK_LANE := 0.085
const LINK_PACKETS := 40
const SHOCK_WIDTH := 0.35
const LINK_SHARDS := 16
const STRIKES := 28.0
const WARM := 0.85
const OFFLINE_JITTER := 0.35
const OFFLINE_GARBLE := 0.25
const CACHE_DASH := 0.6
const CACHE_GAP := 0.4
const LABEL := Color("e6e6f5")
const CACHE_TEXT := 1.6
const EVALUATION_TEXT := 1.5
const WORKER_TEXT := 1.6

var glows := SpriteBatch.new(GLOW_SHADER)
var bodies := SpriteBatch.new(BODY_SHADER)
var planets := SpriteBatch.new(PLANET_SHADER)
var ribbons := RibbonBatch.new(RIBBON_SHADER)
var links := RibbonBatch.new(LINK_SHADER)
var comets := SpriteBatch.new(COMET_SHADER, SpriteBatch.strip(Comet.TRAIL_SEGMENTS))
var comet_heads := SpriteBatch.new(COMET_HEAD_SHADER)
var orbits := SpriteBatch.new(ORBIT_SHADER, SpriteBatch.strip(ORBIT_SEGMENTS))
var prominences := SpriteBatch.new(PROMINENCE_SHADER, SpriteBatch.strip(FLARE_SEGMENTS))
var labels := LabelPool.new()
var sun := MeshInstance3D.new()
var chromosphere := MeshInstance3D.new()
var lens := ColorRect.new()
var satellites := {}
var eye := Vector3.ZERO


func _ready() -> void:
	prominences.material_override.set_shader_parameter("radius", World.SUN_RADIUS)
	links.material_override.set_shader_parameter("spacing", World.WORKER_RING / LINK_PACKETS)
	for child in [_environment(), _lens(), _sun(), _sunlight(), _chromosphere(), prominences, orbits, links, ribbons, comets, comet_heads, glows, bodies, planets, labels]:
		add_child(child)


func transmit(transmission: Transmission) -> void:
	lens.material.set_shader_parameter("glitch", transmission.glitch)


func draw(world: World, p_eye: Vector3) -> void:
	eye = p_eye
	glows.begin()
	bodies.begin()
	planets.begin()
	ribbons.begin()
	links.begin()
	comets.begin()
	orbits.begin()
	prominences.begin()
	labels.begin()
	_links(world)
	_orbits(world)
	_ripples(world)
	_shockwaves(world)
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
	links.commit()
	comets.commit()
	comet_heads.mirror(comets)
	orbits.commit()
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
	environment.tonemap_exposure = 5.2
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT
	environment.ambient_light_energy = 0.35
	environment.adjustment_enabled = true
	environment.adjustment_color_correction = FilmLut.texture()
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.1
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
	links.material_override.set_shader_parameter("time", world.time)
	for worker in world.workers.values():
		if not worker.connected:
			if worker.link > 0.0:
				_broken_link(World.server_position(), worker.position, worker.link)
			continue
		var lit := flicker(worker.link)
		if lit > 0.0:
			_link(World.server_position(), worker.position, (0.5 + worker.heat) * lit)


static func flicker(progress: float) -> float:
	if progress >= WARM:
		return 1.0
	var strike := floorf(progress * STRIKES)
	var roll := fposmod(sin(strike * 12.9898) * 43758.5453, 1.0)
	return 1.0 + 0.6 * (1.0 - progress) if roll < 0.25 + 0.6 * progress else 0.0


func _broken_link(start: Vector3, end: Vector3, link: float) -> void:
	var side := (end - start).cross(Vector3.UP).normalized()
	var color := Palette.shade(Palette.LINK, link)
	for i in LINK_SHARDS:
		if randf() > link:
			continue
		var jolt := side * randf_range(-1.0, 1.0) * (1.0 - link) * 1.5
		var from := start.lerp(end, float(i) / LINK_SHARDS) + jolt
		var to := start.lerp(end, float(i + 1) / LINK_SHARDS) + jolt
		ribbons.segment(from, to, color, color, LINK_LANE * 2.0 * randf_range(0.3, 1.0))


func _link(start: Vector3, end: Vector3, energy: float) -> void:
	var span := end - start
	var length := span.length()
	var side := span.cross(Vector3.UP).normalized() * LINK_LANE
	var base := Palette.shade(Palette.LINK, 0.5 * energy)
	var rail := Palette.shade(Palette.LINK, 1.0 * energy)
	var packet := Palette.shade(Palette.LINK_PACKET, 0.08 + 0.12 * energy)
	ribbons.segment(start, end, base, base, LINK_LANE * 2.0)
	for direction in [-1, 1]:
		var from: Vector3 = start + side * direction
		var to: Vector3 = end + side * direction
		ribbons.segment(from, to, rail, rail, 0.015)
		links.segment(from, to, packet, packet, 0.035, -1.0, Vector2(0.0, length) if direction > 0 else Vector2(length, 0.0))


func _orbits(world: World) -> void:
	for evaluation in world.evaluations.values():
		var color := Palette.shade(Palette.state(evaluation.phase), 0.035 + evaluation.flash * 0.12)
		_orbit_ring(evaluation.electron, Color(color, evaluation.alpha))
		for build in evaluation.visible_builds():
			if not build.electron.host.begins_with("evaluation:"):
				_orbit_ring(build.electron, Color(Palette.shade(Palette.state(build.state), 0.06), evaluation.alpha))


func _orbit_ring(electron: Electron, color: Color) -> void:
	orbits.add_frame(electron.orbit.frame(), electron.anchor.call(), color, Color(ORBIT_WIDTH, 0, 0, 0))


func _ripples(world: World) -> void:
	for ripple in world.fx:
		if ripple is Ripple and ripple.current_radius > ripple.width:
			var width := minf(ripple.width / ripple.current_radius, 0.5)
			glows.add(ripple.anchor.call(), ripple.current_radius, Color(ripple.color, ripple.fade), Color(RING, width, 0, 0))


func _shockwaves(world: World) -> void:
	for wave in world.fx:
		if not wave is Shockwave or wave.radius <= SHOCK_WIDTH:
			continue
		if wave.toward.is_valid():
			_fading_arc(wave.arc(), Color(wave.color, wave.fade * wave.strength), SHOCK_WIDTH * (0.5 + wave.strength))
		else:
			orbits.add_frame(Basis.from_scale(Vector3(wave.radius, 1.0, wave.radius)), wave.anchor.call(), Color(wave.color, wave.fade * 0.5), Color(SHOCK_WIDTH, 0, 0, 0))


func _fading_arc(points: PackedVector3Array, color: Color, width: float) -> void:
	var last := points.size() - 1
	for i in last:
		var from := Color(color, color.a * sin(PI * i / last))
		var to := Color(color, color.a * sin(PI * (i + 1) / last))
		ribbons.segment(points[i], points[i + 1], from, to, width)


func _comets(world: World) -> void:
	for comet in world.fx:
		if comet is Comet and comet.age > 0.0:
			comets.add_frame(comet.path(), Vector3(comet.tail, comet.progress, comet.size), comet.color)


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
			var frame: Basis = flare.frame()
			var width := clampf(flare.height * 0.12, 0.06, 0.35)
			for strand in STRANDS.size():
				var seed := float(flare.get_instance_id() % 97 + strand * 31) / 128.0
				prominences.add_frame(frame, Vector3.ZERO, Color(0, 0, seed, flare.fade), Color(flare.spread, flare.lifted(STRANDS[strand]), width, flare.reach))


func _caches(world: World) -> void:
	for cache in world.caches.values():
		var link := Palette.shade(Palette.CACHE, 0.25 + cache.flash * 0.5)
		ribbons.dashed(World.server_position(), cache.position, link, 0.025, CACHE_DASH, CACHE_GAP)
		_satellite(cache.id).place(cache.position, world.time, cache.flash, cache.alarm)
		var age: float = world.time - cache.born
		labels.show_text(Detection.decoded(world.cache_label(cache), age, hash(cache.id)), cache.position + Vector3.DOWN * 2.0, Palette.CACHE.lightened(0.3), CACHE_TEXT)
		var stats := "hit %d  miss %d  %.1f MB" % [cache.hits, cache.misses, cache.served / 1e6]
		labels.show_text(Detection.decoded(stats, age - 0.15, hash(stats.length())), cache.position + Vector3.DOWN * 3.0, Palette.CACHE.lightened(0.1), CACHE_TEXT * 0.8)


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
		var offline: float = 1.0 - worker.link
		if worker.unstable:
			at += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.07
			heat = maxf(heat, randf())
		if offline > 0.0:
			var luma := color.get_luminance()
			color = color.lerp(Color(luma, luma, luma), offline)
			at += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * OFFLINE_JITTER * offline
			heat *= worker.link
		var pulse := 0.5 + 0.5 * sin(world.time * 3.0 + at.x)
		var behind := at + (at - eye).normalized() * WORKER_RADIUS
		glows.add(behind, 1.9 + heat * 0.85 + pulse * 0.14, Palette.shade(color.lerp(Palette.ATMOSPHERE, 0.5), (0.7 + heat * 0.6) * 0.3))
		planets.add(at, WORKER_RADIUS, color, Color(planet_seed(worker.id), heat, offline, 0.0 if worker.cpu == null else 1.0))
		var label := world.worker_label(worker)
		if worker.cpu != null and worker.connected:
			label += "  %d%%" % roundi(worker.cpu)
		label = Detection.decoded(label, world.time - worker.born, hash(worker.id))
		labels.show_text(garbled(label, OFFLINE_GARBLE * offline), at + Vector3.UP * (WORKER_RADIUS + 0.9), color, WORKER_TEXT)


static func garbled(text: String, odds: float) -> String:
	if odds <= 0.0:
		return text
	var result := ""
	for character in text:
		result += Detection.GLYPHS[randi() % Detection.GLYPHS.length()] if character != " " and randf() < odds else character
	return result


func _evaluations(world: World) -> void:
	for evaluation in world.evaluations.values():
		var color := Palette.state(evaluation.phase)
		var alpha: float = evaluation.alpha
		var at: Vector3 = evaluation.position
		ribbons.trail(evaluation.electron.trail, Color(color, alpha), 0.15)
		glows.add(at, 0.48 + evaluation.flash * 0.68, Palette.shade(color, alpha * (0.6 + evaluation.flash * 0.8)))
		bodies.add(at, EVALUATION_RADIUS, Color(color, alpha), Color(0.28, 0, 0, 0))
		var age: float = world.time - evaluation.born
		labels.show_text(Detection.decoded(evaluation.label, age, hash(evaluation.label)), at + Vector3.UP * 1.05, Color(LABEL, alpha), EVALUATION_TEXT)
		labels.show_text(Detection.decoded(evaluation.phase, age - 0.15, hash(evaluation.phase)), at + Vector3.DOWN * 0.95, Color(color, alpha), EVALUATION_TEXT * 0.8)
		for build in evaluation.visible_builds():
			_build(build, alpha)


func _build(build: Bodies.Build, alpha: float) -> void:
	var color := Palette.state(build.state)
	ribbons.trail(build.electron.trail, Color(color, alpha * 0.8), 0.06, maxi(build.electron.trail.size() - 10, 0))
	glows.add(build.position, 0.34 + build.flash * 0.42, Palette.shade(color, alpha * (1.1 + build.flash) * 0.5))
	bodies.add(build.position, BUILD_RADIUS, Color(color, alpha), Color(0.35, 0, 0, 0))


func _sparks(world: World) -> void:
	for spark in world.fx:
		if spark is Spark:
			glows.add(spark.position, spark.size * 3.0, Palette.shade(spark.color, spark.fade))
			glows.add(spark.position, spark.size * 0.6, Palette.shade(Color.WHITE, spark.fade))
