class_name Bodies

const UNSTABLE_CPU := 90.0
const TERMINAL_PHASES := ["completed", "failed", "aborted"]


class Worker:
	var id: String
	var target: float
	var angle: float
	var heat := 1.0
	var position := Vector3.ZERO
	var cpu: Variant = null
	var network: Variant = null
	var connected := true
	var link := 1.0
	var born: float

	var unstable: bool:
		get:
			return cpu != null and cpu >= UNSTABLE_CPU

	func _init(p_id: String, p_angle: float, p_born: float) -> void:
		id = p_id
		angle = p_angle
		born = p_born


class Cache:
	var id: String
	var position := Vector3.ZERO
	var flash := 1.0
	var alarm := 0.0
	var hits := 0
	var misses := 0
	var served := 0
	var born: float

	func _init(p_id: String, p_born: float) -> void:
		id = p_id
		born = p_born


class Offer:
	var arrived := false
	var answered := false
	var score: Variant = null


class Build:
	var id: String
	var derivation_build: String
	var state := "created"
	var index: int
	var electron: Electron
	var flash := 1.0
	var incoming := false
	var absorbed := false

	var position: Vector3:
		get:
			return electron.position

	var visible: bool:
		get:
			return state != "created" and not incoming and not absorbed

	var finished: bool:
		get:
			return state in EventParser.GOOD or state in EventParser.BAD or state == "skipped"

	func _init(p_id: String, p_index: int, p_electron: Electron) -> void:
		id = p_id
		index = p_index
		electron = p_electron


class Evaluation:
	var id: String
	var phase := "queued"
	var label: String
	var slot: int
	var group: String
	var electron: Electron
	var builds := {}
	var flash := 1.0
	var idle := 0.0
	var alpha := 1.0
	var born: float

	var position: Vector3:
		get:
			return electron.position

	var finished: bool:
		get:
			return phase in TERMINAL_PHASES

	var busy: bool:
		get:
			return electron.host.begins_with("worker:") or builds.values().any(func(build: Build): return build.state == "building")

	func _init(p_id: String, p_label: String, p_slot: int, p_group: String, p_electron: Electron, p_born: float) -> void:
		id = p_id
		born = p_born
		label = p_label
		slot = p_slot
		group = p_group
		electron = p_electron

	func visible_builds() -> Array:
		return builds.values().filter(func(build: Build): return build.visible)


class Headline:
	var text: String
	var tone: String
	var born: float
	var subject: String
	var fallback: String

	func _init(p_text: String, p_tone: String, p_born: float, p_subject: String = "", p_fallback: String = "") -> void:
		text = p_text
		tone = p_tone
		born = p_born
		subject = p_subject
		fallback = p_fallback
