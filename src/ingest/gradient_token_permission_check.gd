# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name GradientTokenPermissionCheck
extends HTTPRequest
## Check once at startup that Gradient accepts the token. Check that the key has live view permission.

signal gradient_token_refused(message: String)

var _url: String
var _headers: PackedStringArray


func _init(base: String, token: String) -> void:
	_url = Endpoints.api_url(base, Endpoints.EVENTS_PATH)
	_headers = Endpoints.bearer(token)


func _ready() -> void:
	request_completed.connect(_on_completed)
	request(_url, _headers)


static func api_key_permission_error_message(code: int, body: String) -> String:
	match code:
		HTTPClient.RESPONSE_UNAUTHORIZED:
			return "Gradient rejected the API token. Pass a valid token with --token or --token-file."
		HTTPClient.RESPONSE_FORBIDDEN:
			var response: Variant = EventDecoder.decode(body)
			if not response is Dictionary:
				response = {}
			if response.get("code") != "superuser_required":
				return "Gradient rejected the API key: %s" % str(response.get("message", body))
			var missing: Variant = response.get("missing_permissions")
			var names := ", ".join(PackedStringArray(missing)) if missing is Array else "readSuperuser"
			return "The API key doesn't have the %s permission. Only a key owned by a Gradient superuser can have this permission. Pins to a project or a cache also prevent the grant." % names
	return ""


func _on_completed(result: int, code: int, _headers_received: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	var message := api_key_permission_error_message(code, body.get_string_from_utf8())
	if message:
		gradient_token_refused.emit(message)
