class_name TelemetryPanel
extends Control
## Top-right downlink readout: instrument line in accent, status dot on the link line.

const MARGIN := Vector2(24, 22)
const ROW := 19.0
const NOMINAL := Color("5ff2a0")
const DEGRADED := Color("ff5d5d")

var _lines: PackedStringArray = []
var _degraded := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_readout(text: String, degraded: bool) -> void:
	_lines = text.split("\n")
	_degraded = degraded
	queue_redraw()


func _draw() -> void:
	var right := get_viewport_rect().size.x - MARGIN.x
	for row in _lines.size():
		var baseline := MARGIN.y + 12.0 + row * ROW
		var first := row == 0
		var color := Color(DetectionOverlay.ACCENT, 0.95) if first else Color(1, 1, 1, 0.72)
		if row == _lines.size() - 1 and _degraded:
			color = Color(DEGRADED, 0.95)
		var font := Hud.sans(true) if first else Hud.monospace()
		var font_size := 11 if first else 13
		draw_string(font, Vector2(right - 600.0, baseline), _lines[row], HORIZONTAL_ALIGNMENT_RIGHT, 600.0, font_size, color)
		if row == _lines.size() - 1:
			var width := font.get_string_size(_lines[row].lstrip(" "), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_circle(Vector2(right - width - 10.0, baseline - 4.5), 3.0, DEGRADED if _degraded else NOMINAL)
