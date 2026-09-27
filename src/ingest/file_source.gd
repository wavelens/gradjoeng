class_name FileSource
extends Node

signal event_received(event: Dictionary)

var clock: ReplayClock


func _init(path: String, speed: float) -> void:
	var events := []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var event: Variant = EventDecoder.decode(line)
		if event != null:
			events.append(event)
	clock = ReplayClock.new(events, speed)


func _process(delta: float) -> void:
	for event in clock.advance(delta):
		event_received.emit(event)
