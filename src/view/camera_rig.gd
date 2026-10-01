# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name CameraRig
extends Camera3D
## Looks at the server from above the worker ring; drifts slowly, drag to orbit, wheel to zoom.

const DISTANCE := 82.0
const PITCH := 0.2
const SWAY := 0.22
const SWAY_PERIOD := 150.0
const DRAG := 0.005
const ZOOM := 1.1
const DISTANCE_RANGE := Vector2(18.0, 400.0)
const PITCH_RANGE := Vector2(-0.2, 1.45)
const SHAKE := 0.3
const FIT_WIDTH := 150.0

var yaw := 0.0
var pitch := PITCH
var distance := DISTANCE
var _time := 0.0


func _init() -> void:
	fov = 38.0
	near = 0.05
	far = 3000.0


func follow(shake: float, delta: float) -> void:
	_time += delta
	var size := get_viewport().get_visible_rect().size
	var fit := maxf(1.0, FIT_WIDTH / (size.aspect() * DISTANCE))
	var heading := yaw + sin(_time * TAU / SWAY_PERIOD) * SWAY
	var direction := Vector3(sin(heading) * cos(pitch), sin(pitch), cos(heading) * cos(pitch))
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * SHAKE
	position = direction * distance * fit + jitter
	look_at(jitter, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * DRAG
		pitch = clampf(pitch + event.relative.y * DRAG, PITCH_RANGE.x, PITCH_RANGE.y)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance / ZOOM, DISTANCE_RANGE.x, DISTANCE_RANGE.y)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * ZOOM, DISTANCE_RANGE.x, DISTANCE_RANGE.y)
