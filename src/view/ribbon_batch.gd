# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name RibbonBatch
extends SpriteBatch
## Camera-facing segments (trails, links, dashes) as instances; the shader turns each into a quad facing the eye.


func _init(shader: Shader) -> void:
	super(shader, SpriteBatch.strip(1))


func trail(points: PackedVector3Array, color: Color, width: float, first: int = 0) -> void:
	var segments := points.size() - 1 - first
	for i in segments:
		var fade_from := float(i) / segments
		var fade_to := float(i + 1) / segments
		segment(points[first + i], points[first + i + 1], Color(color, color.a * fade_from), Color(color, color.a * fade_to), width * maxf(fade_from, 0.2), width * maxf(fade_to, 0.2), Vector2(fade_from, fade_to))


func segment(from: Vector3, to: Vector3, color_from: Color, color_to: Color, width_from: float, width_to: float = -1.0, along: Vector2 = Vector2(0, 1)) -> void:
	var i := _reserve()
	_buffer[i] = from.x
	_buffer[i + 1] = to.x
	_buffer[i + 2] = width_from
	_buffer[i + 3] = along.y
	_buffer[i + 4] = from.y
	_buffer[i + 5] = to.y
	_buffer[i + 6] = width_from if width_to < 0.0 else width_to
	_buffer[i + 7] = 0.0
	_buffer[i + 8] = from.z
	_buffer[i + 9] = to.z
	_buffer[i + 10] = along.x
	_buffer[i + 11] = 0.0
	_tint(i, color_from, color_to)


func dashed(from: Vector3, to: Vector3, color: Color, width: float, dash: float, gap: float) -> void:
	var length := from.distance_to(to)
	var start := 0.0
	while start < length:
		segment(from.lerp(to, start / length), from.lerp(to, minf(start + dash, length) / length), color, color, width)
		start += dash + gap
