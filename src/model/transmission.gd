class_name Transmission
extends RefCounted
## Downlink of the observing satellite: clean, except for small interference from traffic, reporting the measured traffic rate.

const INSTRUMENT := "GRDX-1  ·  AIA 304 Å"
const CADENCE := 12.0
const PER_MESSAGE := Vector2(0.01, 0.04)
const INTERFERENCE_CAP := 0.3
const INTERFERENCE_DECAY := 0.02
const DEGRADED := 0.25
const RATE_SMOOTHING := 0.5
const UNITS := ["bps", "kbps", "Mbps", "Gbps", "Tbps"]

var glitch := 0.0
var frame := 0
var _frame_clock := 0.0
var _interference := 0.0
var _received := 0
var bits_per_second := 0.0


func update(dt: float) -> void:
	_frame_clock += dt * CADENCE
	frame += int(_frame_clock)
	_frame_clock = fmod(_frame_clock, 1.0)
	_interference *= pow(INTERFERENCE_DECAY, dt)
	glitch = _interference
	if dt > 0.0:
		bits_per_second += (_received * 8.0 / dt - bits_per_second) * (1.0 - exp(-dt / RATE_SMOOTHING))
		_received = 0


func receive(size: int) -> void:
	_received += size
	_interfere()


static func bitrate(bps: float) -> String:
	var unit := 0
	while bps >= 1000.0 and unit < UNITS.size() - 1:
		bps /= 1000.0
		unit += 1
	return "%d %s" % [roundi(bps), UNITS[unit]] if unit == 0 else "%.1f %s" % [bps, UNITS[unit]]


func _interfere() -> void:
	_interference = minf(_interference + randf_range(PER_MESSAGE.x, PER_MESSAGE.y), INTERFERENCE_CAP)
	glitch = _interference


func telemetry(unix_time: float, worker_mbps: Variant) -> String:
	var stamp := Time.get_datetime_string_from_unix_time(int(unix_time), true) + ".%03d UTC" % int(fmod(unix_time, 1.0) * 1000.0)
	var link := "LINK UNDER HEAVY USE" if glitch > DEGRADED else "LINK NOMINAL"
	var utilization := "--" if worker_mbps == null else "%.1f Mbps" % worker_mbps
	return "%s\n%s\nFRAME %07d  ·  EXP 2.90 s\n%s  ·  %s  ·  UTIL %s" % [INSTRUMENT, stamp, frame, link, bitrate(bits_per_second), utilization]
