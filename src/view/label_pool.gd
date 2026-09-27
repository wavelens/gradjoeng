class_name LabelPool
extends Node3D
## Reuses billboard labels across frames; labels not shown in a frame are hidden.

const FONT_SIZE := 48
const PIXEL_SIZE := 0.013

var _labels: Array[Label3D] = []
var _used := 0


func begin() -> void:
	_used = 0


func show_text(text: String, at: Vector3, color: Color, scale_factor: float = 1.0) -> void:
	if _used == _labels.size():
		_labels.append(_create())
	var label := _labels[_used]
	label.text = text
	label.position = at
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, color.a)
	label.pixel_size = PIXEL_SIZE * scale_factor
	label.visible = true
	_used += 1


func commit() -> void:
	for i in range(_used, _labels.size()):
		_labels[i].visible = false


func _create() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = Hud.monospace()
	label.font_size = FONT_SIZE
	label.outline_size = 12
	label.double_sided = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	return label
