class_name Cli
extends RefCounted

const USAGE := "usage: gradjoeng (--file FILE | --url URL) [--token TOKEN] [--poll SECONDS] [--speed SPEED] [--size WIDTHxHEIGHT] [--banner DECT]"

var file := ""
var url := ""
var token := ""
var speed := 1.0
var poll := 5.0
var size := Vector2i(1280, 800)
var banner := false
var dect := ""
var error := ""


static func parse(arguments: PackedStringArray) -> Cli:
	var options := Cli.new()
	var index := 0
	while index < arguments.size() and not options.error:
		var flag := arguments[index]
		if index + 1 >= arguments.size():
			options.error = "%s needs a value" % flag
			break
		options._assign(flag, arguments[index + 1])
		index += 2
	if not options.error:
		options.error = options._validate()
	return options


func _assign(flag: String, value: String) -> void:
	match flag:
		"--file":
			file = value
		"--url":
			url = value
		"--token":
			token = value
		"--speed":
			speed = value.to_float()
		"--poll":
			poll = value.to_float()
		"--banner":
			banner = true
			dect = value
		"--size":
			size = Vector2i(value.get_slice("x", 0).to_int(), value.get_slice("x", 1).to_int())
		_:
			error = "unknown option %s" % flag


func _validate() -> String:
	if file.is_empty() == url.is_empty():
		return "exactly one of --file or --url is required"
	if token and not url:
		return "--token requires --url"
	return ""
