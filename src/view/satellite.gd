# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Satellite
extends Node3D
## A cache as a small satellite: gold-foil bus, two solar wings and a dish, all facing the sun.

const PANEL_SHADER := preload("res://src/shaders/solar_panel.gdshader")
const FOIL := Color("c89a3c")
const STRUT := Color("8a8f98")
const NAVIGATION := Color("f2f4ff")
const ALARM := Color("ff2a1f")
const BLINK_PERIOD := 1.2
const STROBE := 9.0
const SIZE := 2.2
const WING := Vector3(1.5, 0.02, 0.55)

var _beacon := StandardMaterial3D.new()


func _init() -> void:
	_part("Bus", _box(Vector3(0.42, 0.42, 0.5)), _metal(FOIL, 0.85, 0.35), Vector3.ZERO)
	for side in [-1, 1]:
		var wing := _part("Panel%d" % side, _box(WING), _panel(), Vector3(side * (0.21 + 0.1 + WING.x / 2.0), 0, 0))
		wing.rotation.x = PI / 2.0
		_part("Strut%d" % side, _box(Vector3(0.2, 0.03, 0.03)), _metal(STRUT, 0.8, 0.5), Vector3(side * 0.31, 0, 0))
	var dish := CylinderMesh.new()
	dish.top_radius = 0.28
	dish.bottom_radius = 0.04
	dish.height = 0.12
	var antenna := _part("Dish", dish, _metal(Color(0.9, 0.9, 0.92), 0.2, 0.3), Vector3(0, 0, -0.33))
	antenna.rotation.x = -PI / 2.0
	var light := SphereMesh.new()
	light.radius = 0.035
	light.height = 0.07
	_beacon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_part("Beacon", light, _beacon, Vector3(0, 0.25, 0.1))


static func beacon(phase: float, flash: float, alarm: float) -> Color:
	if alarm > 0.05:
		return ALARM if fposmod(phase * STROBE, 1.0) < 0.5 else Palette.shade(ALARM, 0.1)
	var blink := 1.0 if fposmod(phase, BLINK_PERIOD) < 0.12 else 0.0
	return Palette.shade(NAVIGATION, maxf(0.1, maxf(blink, flash)))


func place(at: Vector3, time: float, flash: float, alarm: float) -> void:
	transform = Transform3D(Basis.looking_at(-at, Vector3.UP).scaled(Vector3.ONE * SIZE), at)
	_beacon.albedo_color = Palette.shade(beacon(time, flash, alarm), 3.0)


func _part(part_name: String, mesh: Mesh, material: Material, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _panel() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PANEL_SHADER
	return material
