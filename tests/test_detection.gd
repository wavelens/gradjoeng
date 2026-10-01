# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func test_every_beat_is_snappy() -> void:
	for name in Detection.BEATS:
		var beat: Vector2 = Detection.BEATS[name]
		check(beat.y <= 0.2 + 1e-5, "%s lasts %.2fs" % [name, beat.y])
		check(beat.x + beat.y <= Detection.DURATION + 1e-5, "%s ends inside the detection" % name)


func test_beats_progress_from_zero_to_one() -> void:
	var snap: Vector2 = Detection.BEATS["snap"]
	near(Detection.beat(0.0, "snap"), 0.0)
	near(Detection.beat(snap.x + snap.y, "snap"), 1.0)
	var pill: Vector2 = Detection.BEATS["pill"]
	near(Detection.beat(pill.x - 0.01, "pill"), 0.0)
	check(Detection.beat(pill.x + pill.y / 2.0, "pill") > 0.0 and Detection.beat(pill.x + pill.y / 2.0, "pill") < 1.0, "mid beat")


func test_detection_starts_and_ends_quickly() -> void:
	check(Detection.active(0.0) and not Detection.active(Detection.DURATION + 0.01), "active window")
	near(Detection.beat(Detection.DURATION - 0.02, "exit"), 1.0)
	near(Detection.beat(Detection.DURATION - 0.3, "exit"), 0.0)


func test_name_decodes_out_of_noise_and_settles() -> void:
	var name := "worker adbaf9ad"
	var early := Detection.decoded(name, Detection.IDENTIFY, 5)
	equal(early.length(), name.length())
	check(early != name, "starts scrambled: %s" % early)
	var middle := Detection.decoded(name, Detection.IDENTIFY + Detection.SOLVE * 0.5, 5)
	var locked := 0
	for i in name.length():
		locked += int(middle[i] == name[i])
	check(locked > 0 and locked < name.length(), "locks in gradually: %s" % middle)
	equal(Detection.decoded(name, Detection.IDENTIFY + Detection.SOLVE + 0.01, 5), name)
	equal(Detection.decoded(name, 0.0, 5), "")


func test_solver_narrows_candidates_to_one() -> void:
	check(Detection.candidates(Detection.IDENTIFY) > 500, "wide search first")
	equal(Detection.candidates(Detection.IDENTIFY + Detection.SOLVE), 1)


func test_confidence_climbs_to_near_certainty() -> void:
	check(Detection.confidence(0.0) < 30.0, "starts uncertain")
	check(Detection.confidence(Detection.IDENTIFY + Detection.SOLVE) > 97.0, "certain when solved")
	check(Detection.confidence(Detection.IDENTIFY + Detection.SOLVE) <= 100.0, "bounded")


func test_bits_are_binary_stable_per_slot_and_flicker_between_slots() -> void:
	var bits := Detection.bits(7, 3, 12)
	equal(bits.length(), 12)
	check(Array(bits.split("")).all(func(c): return c == "0" or c == "1"), "binary only: %s" % bits)
	equal(Detection.bits(7, 3, 12), bits)
	check(Detection.bits(7, 4, 12) != bits, "changes with the next slot")


func test_streams_calculate_quickly_then_uncalculate() -> void:
	check(Detection.stream(3, 0.05, 16).length() < Detection.stream(3, 0.12, 16).length(), "prints progressively")
	equal(Detection.stream(3, 16.0 / Detection.PRINT_RATE + 0.01, 16).length(), 16)
	check(16.0 / Detection.PRINT_RATE < 0.2, "a full line prints within 200ms")
	var closing := Detection.stream(3, Detection.DURATION - 0.05, 16)
	check(closing.length() > 0 and closing.length() < 16, "un-prints at the end: '%s'" % closing)
	equal(Detection.stream(3, Detection.DURATION, 16), "")


func test_distortion_hits_on_lock_then_settles_and_collapses_on_exit() -> void:
	near(Detection.distortion(0.0, 1), 1.0)
	equal(Detection.distortion(2.0, 1), 0.0)
	check(Detection.distortion(Detection.DURATION - 0.02, 1) > 0.8, "collapses on exit")
	for i in 200:
		var value := Detection.distortion(i * Detection.DURATION / 200.0, i)
		check(value >= 0.0 and value <= 1.0, "bounded at %d" % i)


func test_distortion_crackles_while_decoding() -> void:
	var crackles := 0
	for slot in 18:
		crackles += int(Detection.distortion(Detection.IDENTIFY + slot / Detection.FLICKER, 7) > 0.0)
	check(crackles > 0 and crackles < 18, "intermittent bursts: %d" % crackles)
