class_name Transmission
extends RefCounted
## Downlink of the observing satellite: clean, except for small interference from traffic.

const INSTRUMENT := "GRDX-1  ·  AIA 304 Å"
const CADENCE := 12.0
const PER_MESSAGE := Vector2(0.01, 0.04)
const INTERFERENCE_CAP := 0.3
const INTERFERENCE_DECAY := 0.02
const BASE_RATE := 48.0
const DEGRADED := 0.25

var glitch := 0.0
var frame := 0
var _frame_clock := 0.0
var _interference := 0.0


func update(dt: float) -> void:
	_frame_clock += dt * CADENCE
	frame += int(_frame_clock)
	_frame_clock = fmod(_frame_clock, 1.0)
	_interference *= pow(INTERFERENCE_DECAY, dt)
	glitch = _interference


func interfere() -> void:
	_interference = minf(_interference + randf_range(PER_MESSAGE.x, PER_MESSAGE.y), INTERFERENCE_CAP)
	glitch = _interference


func telemetry(unix_time: float) -> String:
	var stamp := Time.get_datetime_string_from_unix_time(int(unix_time), true) + ".%03d UTC" % int(fmod(unix_time, 1.0) * 1000.0)
	var loss := 0.1 + glitch * 38.0
	var rate := BASE_RATE * (1.0 - glitch * 0.8)
	var link := "LINK UNDER HEAVY USE" if glitch > DEGRADED else "LINK NOMINAL"
	return "%s\n%s\nFRAME %07d  ·  EXP 2.90 s\n%s  ·  %.1f gbps  ·  UTIL %.1f %%" % [INSTRUMENT, stamp, frame, link, rate, loss]
