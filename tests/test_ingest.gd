# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func event(at: String, name: String = "graph.requeued") -> Dictionary:
	return {"event": name, "at": at, "content": {}}


func names(events: Array) -> Array:
	return events.map(func(e): return e["event"])


func test_parse_timestamp_handles_nanoseconds_and_zulu() -> void:
	var earlier := Timestamps.parse("2026-09-26T23:22:44.842033933Z")
	var later := Timestamps.parse("2026-09-26T23:22:45.342033933Z")
	near(later - earlier, 0.5)


func test_decode_skips_malformed_lines() -> void:
	equal(EventDecoder.decode("not json"), null)
	equal(EventDecoder.decode("[1, 2]"), null)
	equal(EventDecoder.decode('{"event": "ok"}'), {"event": "ok"})


func test_replay_waits_scaled_and_capped_gaps() -> void:
	var replay := ReplayClock.new([
		event("2026-01-01T00:00:00Z", "a"),
		event("2026-01-01T00:00:02Z", "b"),
		event("2026-01-01T00:01:00Z", "c"),
		{"event": "d", "content": {}},
	], 2.0, 5.0)
	equal(names(replay.advance(0.0)), ["a"])
	equal(names(replay.advance(0.9)), [])
	equal(names(replay.advance(0.2)), ["b"])
	equal(names(replay.advance(4.8)), [])
	equal(names(replay.advance(0.2)), ["c", "d"])
	check(replay.finished, "replay finished")


func test_replay_speed_changes_apply_to_following_gaps() -> void:
	var replay := ReplayClock.new([event("2026-01-01T00:00:00Z", "a"), event("2026-01-01T00:00:01Z", "b"), event("2026-01-01T00:00:02Z", "c")], 1.0)
	replay.advance(0.0)
	replay.speed = 4.0
	equal(names(replay.advance(1.0)), ["b"])
	equal(names(replay.advance(0.25)), ["c"])


func test_replay_speed_steps_walk_and_clamp() -> void:
	var replay := ReplayClock.new([], 1.0)
	replay.shift_speed(1)
	equal(replay.speed, 2.0)
	for i in 20:
		replay.shift_speed(-1)
	equal(replay.speed, 0.25)


func test_events_url_maps_base_url_to_websocket_endpoint() -> void:
	equal(Endpoints.events_url("https://gradient.example"), "wss://gradient.example/api/v1/metrics/events")
	equal(Endpoints.events_url("http://127.0.0.1:3000/"), "ws://127.0.0.1:3000/api/v1/metrics/events")
	equal(Endpoints.workers_url("https://gradient.example/"), "https://gradient.example/api/v1/board/workers")


func test_bearer_header_only_with_token() -> void:
	equal(Endpoints.bearer("secret"), PackedStringArray(["Authorization: Bearer secret"]))
	equal(Endpoints.bearer(""), PackedStringArray())


func test_worker_metrics_events_from_board_response() -> void:
	var body := JSON.stringify({"error": false, "message": [
		{"id": "w1", "cpu_usage_pct": 42.5},
		{"id": null, "cpu_usage_pct": 10},
		{"id": "w2", "cpu_usage_pct": null},
	]})
	equal(MetricsPoll.worker_events(body), [
		{"event": "worker.metrics", "content": {"worker_id": "w1", "cpu_usage_pct": 42.5}},
		{"event": "worker.metrics", "content": {"worker_id": "w2", "cpu_usage_pct": null}},
	])
	equal(MetricsPoll.worker_events("garbage"), [])
	equal(MetricsPoll.worker_events('{"message": 3}'), [])


func test_worker_network_events_from_board_network_response() -> void:
	var body := JSON.stringify({"error": false, "message": {"nar_egress": [], "http": [], "workers": [
		{"worker_id": "w1", "network_speed_mbps": 88.5, "disk_speed_mbps": 3.0},
		{"worker_id": null, "network_speed_mbps": 1.0},
		{"worker_id": "w2", "network_speed_mbps": null},
	]}})
	equal(MetricsPoll.network_events(body), [
		{"event": "worker.network", "content": {"worker_id": "w1", "network_speed_mbps": 88.5}},
		{"event": "worker.network", "content": {"worker_id": "w2", "network_speed_mbps": null}},
	])
	equal(MetricsPoll.network_events("garbage"), [])
	equal(Endpoints.network_url("https://gradient.example/"), "https://gradient.example/api/v1/board/network")
