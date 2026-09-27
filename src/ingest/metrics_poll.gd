class_name MetricsPoll
extends Node
## Polls the connected workers every `interval` seconds and emits their load as `worker.metrics` events.

signal event_received(event: Dictionary)

var _url: String
var _headers: PackedStringArray
var _request := HTTPRequest.new()
var _timer := Timer.new()


func _init(base: String, token: String, interval: float) -> void:
	_url = Endpoints.workers_url(base)
	_headers = Endpoints.bearer(token)
	_request.timeout = interval
	_timer.wait_time = interval


func _ready() -> void:
	add_child(_request)
	add_child(_timer)
	_request.request_completed.connect(_on_completed)
	_timer.timeout.connect(_poll)
	_timer.start()
	_poll()


static func worker_events(body: String) -> Array:
	var response: Variant = EventDecoder.decode(body)
	var workers: Variant = response.get("message") if response is Dictionary else null
	if not workers is Array:
		return []
	var events := []
	for worker in workers:
		if worker is Dictionary and worker.get("id") is String:
			events.append({"event": "worker.metrics", "content": {"worker_id": worker["id"], "cpu_usage_pct": worker.get("cpu_usage_pct")}})
	return events


func _poll() -> void:
	if _request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_request.request(_url, _headers)


func _on_completed(result: int, _code: int, _headers_received: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	for event in worker_events(body.get_string_from_utf8()):
		event_received.emit(event)
