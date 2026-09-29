class_name NameDirectory
extends Node
## Lists caches as `directory.caches` and resolves worker and evaluation ids to display names as `directory.names` events.

signal event_received(event: Dictionary)

const REFRESH := 60.0
const CACHES_PATH := "api/v1/caches?per_page=100"
const PROJECTS_PATH := "api/v1/projects?per_page=100"
const EVALUATION_PATH := "api/v1/evals/%s"

var _base: String
var _headers: PackedStringArray
var _timer := Timer.new()
var _evaluations := {}


func _init(base: String, token: String) -> void:
	_base = base
	_headers = Endpoints.bearer(token)
	_timer.wait_time = REFRESH


func _ready() -> void:
	add_child(_timer)
	_timer.timeout.connect(_refresh)
	_timer.start()
	_refresh()


static func names_event(names: Dictionary) -> Dictionary:
	return {"event": "directory.names", "content": {"names": names}}


static func caches_event(caches: Dictionary) -> Dictionary:
	return {"event": "directory.caches", "content": {"caches": caches}}


static func cache_names(body: String) -> Dictionary:
	var names := {}
	for cache in _items(body):
		if cache is Dictionary and cache.get("id") is String:
			var display: String = cache.get("display_name") if cache.get("display_name") is String else ""
			names[cache["id"]] = display if display else str(cache.get("name", cache["id"]))
	return names


static func project_names(body: String) -> Array:
	var names := []
	for project in _items(body):
		if project is Dictionary and project.get("name") is String:
			names.append(project["name"])
	return names


static func evaluation_names(evaluation_id: String, body: String) -> Dictionary:
	var evaluation: Variant = _message(body)
	var repository: Variant = evaluation.get("repository") if evaluation is Dictionary else null
	return {evaluation_id: Bodies.repository_label(repository)} if repository is String and repository else {}


static func unnamed_evaluation(event: Dictionary) -> String:
	var content: Variant = event.get("content")
	if not content is Dictionary or content.get("repository") is String:
		return ""
	var evaluation: Variant = content.get("evaluation_id")
	return evaluation if evaluation is String else ""


static func worker_names(body: String) -> Dictionary:
	var workers: Variant = _message(body)
	var names := {}
	for worker in workers if workers is Array else []:
		if worker is Dictionary and worker.get("worker_id") is String and worker.get("display_name") is String and worker["display_name"]:
			names[worker["worker_id"]] = worker["display_name"]
	return names


static func _message(body: String) -> Variant:
	var response: Variant = EventDecoder.decode(body)
	return response.get("message") if response is Dictionary else null


static func _items(body: String) -> Array:
	var message: Variant = _message(body)
	if message is Dictionary:
		message = message.get("items")
	return message if message is Array else []


func observe(event: Dictionary) -> void:
	var evaluation := unnamed_evaluation(event)
	if not evaluation or _evaluations.has(evaluation):
		return
	_evaluations[evaluation] = true
	_fetch(EVALUATION_PATH % evaluation.uri_encode(), func(body: String) -> void: _publish(evaluation_names(evaluation, body)))


func _refresh() -> void:
	_fetch(CACHES_PATH, func(body: String) -> void: _publish_caches(cache_names(body)))
	_fetch(PROJECTS_PATH, func(body: String) -> void:
		for project in project_names(body):
			_fetch("api/v1/projects/%s/workers" % project.uri_encode(), func(workers: String) -> void: _publish(worker_names(workers))))


func _publish(names: Dictionary) -> void:
	if not names.is_empty():
		event_received.emit(names_event(names))


func _publish_caches(caches: Dictionary) -> void:
	if not caches.is_empty():
		event_received.emit(caches_event(caches))


func _fetch(path: String, on_body: Callable) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers_received: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			on_body.call(body.get_string_from_utf8())
		else:
			push_warning("name lookup %s failed: result %d, HTTP %d" % [path, result, code])
		request.queue_free())
	request.request(Endpoints.api_url(_base, path), _headers)
