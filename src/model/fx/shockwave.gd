# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Shockwave
extends RefCounted
## A flat front leaving `anchor` at constant speed: a full ring, or an eighth circle facing `toward`; `on_arrive` fires at `reach`.

var anchor: Callable
var color: Color
var reach: float
var duration: float
var on_arrive: Callable
var toward: Callable
var strength: float
var age := 0.0

var progress: float:
	get:
		return minf(age / duration, 1.0)

var radius: float:
	get:
		return reach * progress

var fade: float:
	get:
		return 1.0 - 0.7 * progress


func _init(p_anchor: Callable, p_color: Color, p_reach: float, p_duration: float, p_on_arrive: Callable = Callable(), p_toward: Callable = Callable(), p_strength: float = 1.0) -> void:
	anchor = p_anchor
	color = p_color
	reach = p_reach
	duration = p_duration
	on_arrive = p_on_arrive
	toward = p_toward
	strength = p_strength


func arc(segments: int = 24) -> PackedVector3Array:
	var center: Vector3 = anchor.call()
	var heading := ((toward.call() as Vector3) - center) * Vector3(1, 0, 1)
	var result := PackedVector3Array()
	for i in segments + 1:
		var angle := -PI / 8 + PI / 4 * i / segments
		result.append(center + heading.normalized().rotated(Vector3.UP, angle) * radius)
	return result


func update(dt: float) -> bool:
	age += dt
	if age < duration:
		return true
	if on_arrive.is_valid():
		on_arrive.call()
	return false
