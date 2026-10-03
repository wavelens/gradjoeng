# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Flare
extends RefCounted
## A prominence loop whose plasma climbs both legs from the surface, holds, then rains back down.

const FOOTPOINTS := 0.9
const CLIMB := 0.35
const DRAIN := 0.6

var root: Vector3
var tangent: Vector3
var radius: float
var height: float
var spread: float
var color: Color
var life: float
var age := 0.0

var fade: float:
	get:
		return clampf(minf(age / (life * 0.08), (1.0 - age / life) / 0.08), 0.0, 1.0)

var reach: float:
	get:
		var t := age / life
		if t < DRAIN:
			return 1.0 - pow(1.0 - minf(t / CLIMB, 1.0), 2.0)
		return 1.0 - pow(minf((t - DRAIN) / (1.0 - DRAIN), 1.0), 2.0)

var growth: float:
	get:
		return 1.0 - pow(1.0 - minf(age / (life * 0.45), 1.0), 3.0)


func _init(p_root: Vector3, p_radius: float, p_height: float, p_color: Color, p_life: float) -> void:
	root = p_root.normalized()
	tangent = root.cross(Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1))).normalized()
	radius = p_radius
	height = p_height
	spread = clampf(p_height / p_radius * FOOTPOINTS, 0.02, 0.45)
	color = p_color
	life = p_life


func frame() -> Basis:
	return Basis(root, tangent, root.cross(tangent))


func lifted(lift: float = 1.0) -> float:
	return height * lift * growth


func points(segments: int = 24, lift: float = 1.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in segments + 1:
		var s := float(i) / segments
		var base := (root + tangent * (s - 0.5) * spread).normalized()
		result.append(base * (radius + sin(s * PI) * lifted(lift)))
	return result


func update(dt: float) -> bool:
	age += dt
	return age < life
