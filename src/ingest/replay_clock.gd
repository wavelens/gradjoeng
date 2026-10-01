# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name ReplayClock
extends RefCounted
## Re-emits recorded events with their original spacing, scaled by `speed` and capped at `max_gap` seconds.

const SPEED_STEPS := [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0]

var speed: float
var max_gap: float
var _events: Array
var _index := 0
var _wait := 0.0
var _previous := NAN

var finished: bool:
	get:
		return _index >= _events.size()


func _init(events: Array, p_speed: float, p_max_gap: float = 1.5) -> void:
	_events = events
	speed = p_speed
	max_gap = p_max_gap
	if not _events.is_empty():
		_gap_before(_events[0])


func advance(dt: float) -> Array:
	_wait -= dt
	var due := []
	while not finished and _wait <= 0.0:
		due.append(_events[_index])
		_index += 1
		if not finished:
			_wait += _gap_before(_events[_index])
	return due


func shift_speed(direction: int) -> void:
	var closest := 0
	for i in SPEED_STEPS.size():
		if absf(SPEED_STEPS[i] - speed) < absf(SPEED_STEPS[closest] - speed):
			closest = i
	speed = SPEED_STEPS[clampi(closest + direction, 0, SPEED_STEPS.size() - 1)]


func _gap_before(event: Dictionary) -> float:
	if not event.get("at") is String:
		return 0.0
	var at := Timestamps.parse(event["at"])
	var gap := 0.0 if is_nan(_previous) else minf(maxf(at - _previous, 0.0) / speed, max_gap)
	_previous = at
	return gap
