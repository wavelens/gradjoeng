# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name DetectionScreen
extends Control
## Renders the detection overlay offscreen so its reticles can tear, split and jump on their own.

const SHADER := preload("res://src/shaders/detection_glitch.gdshader")
const MAX_GLITCHES := 8

var _viewport := SubViewport.new()
var _overlay := DetectionOverlay.new()
var _screen := TextureRect.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size_2d_override_stretch = true
	_viewport.add_child(_overlay)
	add_child(_viewport)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture = _viewport.get_texture()
	_screen.material = ShaderMaterial.new()
	_screen.material.shader = SHADER
	add_child(_screen)


static func strongest(glitches: Array[Vector4], limit: int) -> PackedVector4Array:
	var ranked := glitches.duplicate()
	ranked.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.w > b.w)
	var result := PackedVector4Array(ranked.slice(0, limit))
	result.resize(limit)
	return result


func track(world: World, camera: Camera3D) -> void:
	_fit()
	_overlay.track(world, camera)
	_screen.material.set_shader_parameter("glitches", strongest(_overlay.glitches(), MAX_GLITCHES))
	_screen.material.set_shader_parameter("canvas", get_viewport_rect().size)


func _fit() -> void:
	var pixels := get_window().size
	var canvas := Vector2i(get_viewport_rect().size)
	if _viewport.size != pixels or _viewport.size_2d_override != canvas:
		_viewport.size = pixels
		_viewport.size_2d_override = canvas
