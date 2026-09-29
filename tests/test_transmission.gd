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
	check(not transmission.telemetry(0.0, null).contains("UNDER HEAVY USE"), "clean link")
	transmission.glitch = 0.8
	check(transmission.telemetry(0.0, null).contains("LINK UNDER HEAVY USE"), "dropout is reported")
	check(transmission.telemetry(1790000000.0, null).contains("2026-09-21 "), "UTC timestamp")


func test_rate_is_the_measured_traffic() -> void:
	var transmission := Transmission.new()
	check(transmission.telemetry(0.0, null).contains("0 bps"), "idle link")
	for i in 100:
		transmission.receive(1_000_000)
		transmission.update(0.1)
	near(transmission.bits_per_second, 80e6, 1e6)
	check(transmission.telemetry(0.0, null).contains("80.0 Mbps"), transmission.telemetry(0.0, null))
	run(transmission, 10.0)
	check(transmission.bits_per_second < 1e3, "falls back when traffic stops")


func test_utilization_is_the_average_worker_traffic() -> void:
	var transmission := Transmission.new()
	check(transmission.telemetry(0.0, 12.34).ends_with("UTIL  12.3 Mbps"), transmission.telemetry(0.0, 12.34))
	check(transmission.telemetry(0.0, null).ends_with(" --"), "unknown without worker samples")


func test_telemetry_lines_keep_a_constant_width() -> void:
	var transmission := Transmission.new()
	var idle := transmission.telemetry(0.0, null).split("\n")
	transmission.glitch = 0.8
	for i in 100:
		transmission.receive(1_000_000)
		transmission.update(0.1)
	var busy := transmission.telemetry(0.0, 1234.5).split("\n")
	for row in idle.size():
		equal(busy[row].length(), idle[row].length())


func test_bitrate_picks_a_readable_unit() -> void:
	equal(Transmission.bitrate(0.0), "0 bps")
	equal(Transmission.bitrate(1500.0), "1.5 kbps")
	equal(Transmission.bitrate(2.5e9), "2.5 Gbps")


func test_messages_add_small_interference_that_stacks_and_decays() -> void:
	var transmission := Transmission.new()
	transmission.update(0.016)
	transmission.receive(10)
	var single := transmission.glitch
	check(single > 0.0 and single <= Transmission.PER_MESSAGE.y, "one message is a tiny blip: %s" % single)
	for i in 200:
		transmission.receive(10)
	check(transmission.glitch > single, "many messages add up")
	check(transmission.glitch <= Transmission.INTERFERENCE_CAP + 1e-6, "capped")
	for i in 60:
		transmission.update(0.05)
	check(transmission.glitch < 0.01, "decays when traffic stops")
