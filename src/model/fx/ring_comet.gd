# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name RingComet
extends Comet
## The control point puts the curve's midpoint on the worker ring halfway between both angles.

const LIFT := 0.6

var from_angle: Callable
var sweep: Callable


static func ring_point(angle: float, radius: float = World.WORKER_RING) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle)) * radius + Vector3.UP * LIFT


static func angle_of(position: Vector3) -> float:
	return atan2(position.z, position.x)


func _init(from: Callable, to: Callable, p_color: Color, p_size: float, p_duration: float, p_on_arrive: Callable = Callable()) -> void:
	from_angle = func() -> float: return angle_of(from.call())
	sweep = func() -> float: return wrapf(angle_of(to.call()) - from_angle.call(), -PI, PI)
	super(func() -> Vector3: return ring_point(from_angle.call()), func() -> Vector3: return ring_point(from_angle.call() + sweep.call()), p_color, p_size, p_duration, 0.0, p_on_arrive)


func path() -> Basis:
	var start: float = from_angle.call()
	var half: float = sweep.call() / 2.0
	var control := ring_point(start + half, World.WORKER_RING * (2.0 - cos(half)))
	return Basis(ring_point(start), control, ring_point(start + 2.0 * half))
