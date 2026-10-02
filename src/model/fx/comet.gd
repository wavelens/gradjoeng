# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Comet
extends RefCounted
## A packet flying a bent path from `source` to `target`; its trail covers the last `TRAIL_TIME` seconds of that path.

const TRAIL_SEGMENTS := 13
const TRAIL_TIME := TRAIL_SEGMENTS / 60.0

var source: Callable
var target: Callable
var color: Color
var size: float
var duration: float
var bend: float
var on_arrive: Callable
var age := 0.0

var progress: float:
	get:
		return minf(age / duration, 1.0)

var tail: float:
	get:
		return clampf((age - TRAIL_TIME) / duration, 0.0, 1.0)


func _init(p_source: Callable, p_target: Callable, p_color: Color, p_size: float, p_duration: float, p_bend: float, p_on_arrive: Callable = Callable()) -> void:
	source = p_source
	target = p_target
	color = p_color
	size = p_size
	duration = p_duration
	bend = p_bend
	on_arrive = p_on_arrive


func path() -> Basis:
	var start: Vector3 = source.call()
	var end: Vector3 = target.call()
	var span := end - start
	var control := (start + end) / 2.0 + span.cross(Vector3.UP) * bend + Vector3.UP * absf(bend) * span.length() * 0.5
	return Basis(start, control, end)


func update(dt: float) -> bool:
	age += dt
	if age < duration:
		return true
	if on_arrive.is_valid():
		on_arrive.call()
	return false
