class_name Hud
extends CanvasLayer

const TITLE := "GRADIENT CI // LIVE"
const SUBTITLE := ["Nix-CI for Teams", "GitHub: wavelens/gradient"]
const BANNER_HEADLINE := "Want to see your Nix Flake building?"
const MATRIX := "Matrix: @derdennisop:matrix.org"
const TITLE_COLOR := Color("c8beff")
const SUBTITLE_COLOR := Color("8c96be")
const BANNER_COLOR := Color("e6dcff")
const HEADLINE_FADE := 20.0
const LOG_GLOW := Color(1, 1, 1, 0.3)
const MESSAGE_FADE := 6.0

const BACKDROP := Color(0, 0, 0, 0.6)

static var _font: SystemFont
static var _sans: SystemFont
static var _sans_bold: FontVariation

var _headlines: Array[Label] = []
var _messages: Array[Label] = []
var _banner: VBoxContainer
var _contact: String
var _telemetry := TelemetryPanel.new()
var _detections := DetectionScreen.new()


func _init(banner: bool, dect: String) -> void:
	if banner:
		_banner = VBoxContainer.new()
		_contact = contact_line(dect)


static func contact_line(dect: String) -> String:
	return "%s   Dect: %s" % [MATRIX, dect] if dect else MATRIX


static func sans(bold: bool = false) -> Font:
	if _sans == null:
		_sans = SystemFont.new()
		_sans.font_names = PackedStringArray(["Inter", "DejaVu Sans", "sans-serif"])
		_sans_bold = FontVariation.new()
		_sans_bold.base_font = _sans
		_sans_bold.variation_embolden = 0.5
		_sans_bold.spacing_glyph = 2
	return _sans_bold if bold else _sans


static func monospace(bold: bool = false) -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["DejaVu Sans Mono", "monospace"])
	if not bold:
		return _font
	var variation := FontVariation.new()
	variation.base_font = _font
	variation.variation_embolden = 0.8
	return variation


func _ready() -> void:
	var sensor := CanvasLayer.new()
	sensor.layer = -1
	sensor.add_child(_detections)
	add_child(sensor)
	var header := VBoxContainer.new()
	header.position = Vector2(20, 14)
	header.add_theme_constant_override("separation", 0)
	header.add_child(_label(TITLE, 32, TITLE_COLOR, true))
	for line in SUBTITLE:
		header.add_child(_label(line, 17, SUBTITLE_COLOR))
	add_child(header)

	var feed := VBoxContainer.new()
	feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	feed.position += Vector2(18, -18)
	feed.add_theme_constant_override("separation", 0)
	for i in World.MAX_HEADLINES:
		var line := _label("", 15, Color.WHITE)
		feed.add_child(line)
		_headlines.push_front(line)
	sensor.add_child(feed)

	var traffic := VBoxContainer.new()
	traffic.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	traffic.grow_vertical = Control.GROW_DIRECTION_BEGIN
	traffic.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	traffic.position += Vector2(-18, -18)
	traffic.add_theme_constant_override("separation", 0)
	for i in World.MAX_MESSAGES:
		var line := _label("", 12, Color.WHITE)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_theme_color_override("font_shadow_color", LOG_GLOW)
		line.add_theme_constant_override("shadow_outline_size", 7)
		line.add_theme_constant_override("shadow_offset_x", 0)
		line.add_theme_constant_override("shadow_offset_y", 0)
		traffic.add_child(line)
		_messages.push_front(line)
	sensor.add_child(traffic)

	sensor.add_child(_telemetry)

	if _banner:
		_build_banner()


func _build_banner() -> void:
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.alignment = BoxContainer.ALIGNMENT_END
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _backdrop())
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	for line in [_label(BANNER_HEADLINE, 48, BANNER_COLOR, true), _label(_contact, 24, SUBTITLE_COLOR)]:
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.add_child(line)
	panel.add_child(lines)
	_banner.add_child(panel)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 0.05 * DisplayServer.window_get_size().y
	_banner.add_child(spacer)
	add_child(_banner)


func draw(world: World, transmission: Transmission, camera: Camera3D) -> void:
	_detections.track(world, camera)
	_telemetry.show_readout(transmission.telemetry(Time.get_unix_time_from_system(), world.average_network()), transmission.glitch > Transmission.DEGRADED)
	_fill(_headlines, world.headlines, world.time, HEADLINE_FADE, Palette.tone, world.describe)
	_fill(_messages, world.messages, world.time, MESSAGE_FADE, Palette.message, world.describe)
	if _banner:
		_banner.visible = world.banner > 0.0
		_banner.modulate.a = world.banner


func _fill(labels: Array[Label], lines: Array[Bodies.Headline], now: float, fade_time: float, color_of: Callable, describe: Callable) -> void:
	for row in labels.size():
		var label := labels[row]
		if row >= lines.size():
			label.text = ""
			continue
		var line := lines[row]
		label.text = describe.call(line)
		var fade := maxf(1.0 - (now - line.born) / fade_time, 0.15) * (1.0 - row * 0.05)
		label.modulate = Color(color_of.call(line.tone), fade)


func _backdrop() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKDROP
	style.set_content_margin_all(24)
	return style


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", monospace(bold))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
