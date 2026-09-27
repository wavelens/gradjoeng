extends Suite


func run(transmission: Transmission, seconds: float, dt: float = 0.05) -> Array:
	var samples := []
	for i in ceili(seconds / dt):
		transmission.update(dt)
		samples.append(transmission.glitch)
	return samples


func test_link_stays_clean_without_traffic() -> void:
	check(run(Transmission.new(), 600.0).all(func(g): return g == 0.0), "no random dropouts")


func test_frames_count_up_and_telemetry_reports_link_state() -> void:
	var transmission := Transmission.new()
	run(transmission, 1.0)
	check(transmission.frame > 0, "frames advance")
	transmission.glitch = 0.0
	check(not transmission.telemetry(0.0).contains("UNDER HEAVY USE"), "clean link")
	transmission.glitch = 0.8
	check(transmission.telemetry(0.0).contains("LINK UNDER HEAVY USE"), "dropout is reported")
	check(transmission.telemetry(1790000000.0).contains("2026-09-21 "), "UTC timestamp")


func test_messages_add_small_interference_that_stacks_and_decays() -> void:
	var transmission := Transmission.new()
	transmission.update(0.016)
	transmission.interfere()
	var single := transmission.glitch
	check(single > 0.0 and single <= Transmission.PER_MESSAGE.y, "one message is a tiny blip: %s" % single)
	for i in 200:
		transmission.interfere()
	check(transmission.glitch > single, "many messages add up")
	check(transmission.glitch <= Transmission.INTERFERENCE_CAP + 1e-6, "capped")
	for i in 60:
		transmission.update(0.05)
	check(transmission.glitch < 0.01, "decays when traffic stops")
