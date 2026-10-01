# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name WebSource
extends Node

signal event_received(event: Dictionary)

const RECONNECT_DELAY := 3.0
const MAX_EVENTS_PER_FRAME := 400

var _url: String
var _headers: PackedStringArray
var _socket := WebSocketPeer.new()
var _retry := 0.0


func _init(base: String, token: String) -> void:
	_url = Endpoints.events_url(base)
	_headers = Endpoints.bearer(token)
	_socket.inbound_buffer_size = 1 << 22
	_socket.max_queued_packets = 1 << 14


func _ready() -> void:
	_connect()


func _process(delta: float) -> void:
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_retry -= delta
		if _retry <= 0.0:
			_connect()
		return
	for i in mini(_socket.get_available_packet_count(), MAX_EVENTS_PER_FRAME):
		var event: Variant = EventDecoder.decode(_socket.get_packet().get_string_from_utf8())
		if event != null:
			event_received.emit(event)


func _connect() -> void:
	_retry = RECONNECT_DELAY
	_socket.handshake_headers = _headers
	var error := _socket.connect_to_url(_url)
	if error != OK:
		push_warning("cannot connect to %s: %s" % [_url, error_string(error)])
