class_name MetricsPoll
extends Node
## Polls worker load and network throughput every `interval` seconds as `worker.metrics` and `worker.network` events.

signal event_received(event: Dictionary)

var _headers: PackedStringArray
var _timer := Timer.new()
var _feeds := {}


func _init(base: String, token: String, interval: float) -> void:
	_headers = Endpoints.bearer(token)
	_timer.wait_time = interval
	_feeds[Endpoints.workers_url(base)] = worker_events
	_feeds[Endpoints.network_url(base)] = network_events
	for url in _feeds:
		var request := HTTPRequest.new()
		request.timeout = interval
		request.set_meta("url", url)
		add_child(request)


func _ready() -> void:
	add_child(_timer)
	for request in _requests():
		request.request_completed.connect(_on_completed.bind(_feeds[request.get_meta("url")]))
	_timer.timeout.connect(_poll)
	_timer.start()
	_poll()


static func worker_events(body: String) -> Array:
	var workers: Variant = _message(body)
	var events := []
	for worker in workers if workers is Array else []:
		if worker is Dictionary and worker.get("id") is String:
			events.append({"event": "worker.metrics", "content": {"worker_id": worker["id"], "cpu_usage_pct": worker.get("cpu_usage_pct")}})
	return events


static func network_events(body: String) -> Array:
	var message: Variant = _message(body)
	var workers: Variant = message.get("workers") if message is Dictionary else null
	var events := []
	for worker in workers if workers is Array else []:
		if worker is Dictionary and worker.get("worker_id") is String:
			events.append({"event": "worker.network", "content": {"worker_id": worker["worker_id"], "network_speed_mbps": worker.get("network_speed_mbps")}})
	return events


static func _message(body: String) -> Variant:
	var response: Variant = EventDecoder.decode(body)
	return response.get("message") if response is Dictionary else null


func _requests() -> Array:
	return get_children().filter(func(child): return child is HTTPRequest)


func _poll() -> void:
	for request in _requests():
		if request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			request.request(request.get_meta("url"), _headers)


func _on_completed(result: int, _code: int, _headers_received: PackedStringArray, body: PackedByteArray, to_events: Callable) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	for event in to_events.call(body.get_string_from_utf8()):
		event_received.emit(event)
