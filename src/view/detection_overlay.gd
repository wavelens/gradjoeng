# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name DetectionOverlay
extends Control
## Screen-space tracking reticles the camera draws around newly discovered bodies.

const ACCENT := Color("7fe7ff")
const INK := Color(1, 1, 1)
const PANEL := Color(0.03, 0.05, 0.08, 0.55)
const LEADER := Vector2(26, -26)
const PILL_WIDTH := 172.0
const PILL_HEIGHT := 42.0
const STREAMS := 4
const COLUMN_ROWS := 4

var _targets: Array[Dictionary] = []
var _pill := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.bg_color = PANEL
	_pill.border_color = Color(INK, 0.18)
	_pill.set_border_width_all(1)
	_pill.set_corner_radius_all(10)
	_pill.anti_aliasing = true


func track(world: World, camera: Camera3D) -> void:
	_targets.clear()
	for worker in world.workers.values():
		_add(camera, worker.position, WorldView.WORKER_RADIUS, world.time - worker.born, "WORKER", world.worker_label(worker))
	for evaluation in world.evaluations.values():
		_add(camera, evaluation.position, WorldView.EVALUATION_RADIUS, world.time - evaluation.born, "EVALUATION", evaluation.label)
	for cache in world.caches.values():
		_add(camera, cache.position, WorldView.CACHE_RADIUS, world.time - cache.born, "CACHE", world.cache_label(cache))
	queue_redraw()


func _add(camera: Camera3D, at: Vector3, radius: float, age: float, kind: String, name: String) -> void:
	if not Detection.active(age) or camera.is_position_behind(at):
		return
	var center := camera.unproject_position(at)
	var edge := camera.unproject_position(at + camera.global_basis.x * radius)
	_targets.append({"center": center, "radius": maxf(center.distance_to(edge) * 1.8, 12.0), "age": age, "kind": kind, "name": name, "seed": hash(name)})


func tracking() -> bool:
	return not _targets.is_empty()


func glitches() -> Array[Vector4]:
	var result: Array[Vector4] = []
	for target in _targets:
		var strength := Detection.distortion(target.age, target.seed)
		if strength > 0.0:
			result.append(Vector4(target.center.x, target.center.y, target.radius, strength))
	return result


func _draw() -> void:
	for target in _targets:
		_reticle(target)


func _reticle(target: Dictionary) -> void:
	var age: float = target.age
	var center: Vector2 = target.center
	var leaving := Detection.beat(age, "exit")
	var fade := 1.0 - leaving
	var snap := _back(Detection.beat(age, "snap"))
	var half: float = target.radius * lerpf(2.6, 1.0, snap) * (1.0 - _expo(leaving))
	var flash := 1.0 - Detection.beat(age, "flash")
	var blink := Detection.beat(age, "blink")
	var blinking := blink > 0.0 and blink < 1.0 and int(blink * 4.0) % 2 == 1

	if not blinking and half > 1.0:
		var box := Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0)
		draw_rect(box, Color(INK, (0.75 + 0.25 * flash) * fade), false, 1.0)
		if flash > 0.0:
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var tip: Vector2 = center + corner * half
				draw_line(tip, tip - Vector2(corner.x * 8.0, 0), Color(ACCENT, flash), 2.0)
				draw_line(tip, tip - Vector2(0, corner.y * 8.0), Color(ACCENT, flash), 2.0)
	draw_line(center - Vector2(3, 0), center + Vector2(3, 0), Color(INK, 0.8 * fade), 1.0)
	draw_line(center - Vector2(0, 3), center + Vector2(0, 3), Color(INK, 0.8 * fade), 1.0)

	var sweep := Detection.beat(age, "sweep")
	if sweep > 0.0 and sweep < 1.0:
		var screen := get_viewport_rect().size
		var sweep_color := Color(ACCENT, 0.5 * (1.0 - sweep))
		draw_line(Vector2(0, center.y), Vector2(screen.x, center.y), sweep_color, 1.0)
		draw_line(Vector2(center.x, 0), Vector2(center.x, screen.y), sweep_color, 1.0)

	var rail := Detection.beat(age, "rail")
	if rail > 0.0 and half > 1.0:
		var start := center + Vector2(-half, -half - 4.0)
		draw_line(start, start + Vector2(half * 2.0 * _expo(rail), 0), Color(ACCENT, 0.9 * fade), 1.0)

	_fragments(target, center, target.radius, fade)
	var leader := Detection.beat(age, "leader")
	if leader <= 0.0:
		return
	var side := -1.0 if center.x + half + LEADER.x + PILL_WIDTH > get_viewport_rect().size.x - 16.0 else 1.0
	var anchor := center + Vector2(side, -1.0) * half
	var elbow := anchor + LEADER * Vector2(side, 1.0)
	draw_line(anchor, anchor.lerp(elbow, _expo(leader)), Color(INK, 0.5 * fade), 1.0)
	var width := PILL_WIDTH * _expo(Detection.beat(age, "pill")) * (1.0 - _expo(leaving))
	if width < 12.0:
		return
	var left := elbow.x if side > 0.0 else elbow.x - width
	var rect := Rect2(Vector2(left, elbow.y - PILL_HEIGHT / 2.0), Vector2(width, PILL_HEIGHT))
	var style := _pill.duplicate()
	style.bg_color = Color(PANEL, PANEL.a * fade)
	style.border_color = Color(INK, 0.18 * fade)
	draw_style_box(style, rect)
	var text_left := rect.position.x + 10.0
	var kind := Detection.beat(age, "kind")
	if kind >= 1.0 or (kind > 0.0 and int(age * 60.0) % 2 == 0):
		draw_string(Hud.sans(true), Vector2(text_left, rect.position.y + 12.0), target.kind, HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 7, Color(ACCENT, fade))
	draw_string(Hud.sans(), Vector2(text_left, rect.position.y + 12.0), "%.1f%%" % Detection.confidence(age), HORIZONTAL_ALIGNMENT_RIGHT, width - 20.0, 7, Color(INK, 0.55 * fade))
	var solved := Detection.solving(age) >= 1.0
	draw_string(Hud.monospace(), Vector2(text_left, rect.position.y + 25.0), Detection.decoded(target.name, age, target.seed), HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 10, Color(INK if solved else ACCENT, 0.95 * fade))
	draw_string(Hud.monospace(), Vector2(text_left, rect.position.y + 36.0), _solver_line(target, age), HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 6, Color(INK, 0.45 * fade))
	var column_x := rect.end.x + 6.0 if side > 0.0 else rect.position.x - 38.0
	for row in COLUMN_ROWS:
		var line := Detection.stream(target.seed * 31 + row, age, 8, Detection.IDENTIFY + row * 0.04)
		draw_string(Hud.monospace(), Vector2(column_x, rect.position.y + 8.0 + row * 8.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(ACCENT, 0.45))


static func _expo(t: float) -> float:
	return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)


static func _back(t: float) -> float:
	var overshoot := 1.70158
	return 1.0 + (overshoot + 1.0) * pow(t - 1.0, 3.0) + overshoot * pow(t - 1.0, 2.0)


func _solver_line(target: Dictionary, age: float) -> String:
	var progress := Detection.solving(age)
	var digest: int = Detection.bits(target.seed, int(age * Detection.FLICKER), 32).bin_to_int() if progress < 1.0 else target.seed & 0xFFFFFFFF
	var residual := 0.5 * pow(1.0 - progress, 2.0) + 0.0004
	return "H %08x  M %d/%d  ε %.4f" % [digest, Detection.candidates(age), Detection.SEARCH, residual]


func _fragments(target: Dictionary, center: Vector2, radius: float, fade: float) -> void:
	var rng := RandomNumberGenerator.new()
	for k in STREAMS:
		rng.seed = hash([target.seed, k])
		var direction := Vector2.from_angle(rng.randf() * TAU)
		var spot := center + direction * radius * rng.randf_range(1.5, 2.4)
		var length := rng.randi_range(8, 18)
		var text := Detection.stream(target.seed + k, target.age, length, 0.1 + rng.randf() * 0.25)
		var align := HORIZONTAL_ALIGNMENT_LEFT if direction.x >= 0.0 else HORIZONTAL_ALIGNMENT_RIGHT
		var box := 110.0
		var origin := spot if direction.x >= 0.0 else spot - Vector2(box, 0)
		draw_string(Hud.monospace(), origin, text, align, box, 7, Color(ACCENT if k % 2 == 0 else INK, 0.55))
