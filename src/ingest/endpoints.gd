class_name Endpoints

const EVENTS_PATH := "api/v1/metrics/events"
const WORKERS_PATH := "api/v1/board/workers"


static func api_url(base: String, path: String) -> String:
	return "%s/%s" % [base.rstrip("/"), path]


static func events_url(base: String) -> String:
	var url := api_url(base, EVENTS_PATH)
	if url.begins_with("https://"):
		return "wss://" + url.trim_prefix("https://")
	if url.begins_with("http://"):
		return "ws://" + url.trim_prefix("http://")
	return url


static func workers_url(base: String) -> String:
	return api_url(base, WORKERS_PATH)


static func bearer(token: String) -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer %s" % token]) if token else PackedStringArray()
