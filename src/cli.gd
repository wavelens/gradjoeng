# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Cli
extends RefCounted

const USAGE := "usage: gradjoeng (--file FILE | --url URL) [--token TOKEN | --token-file FILE] [--poll SECONDS] [--speed SPEED] [--size WIDTHxHEIGHT] [--banner DECT] [--fullscreen]"

var file := ""
var url := ""
var token := ""
var token_file := ""
var speed := 1.0
var poll := 5.0
var size := Vector2i(1280, 800)
var fullscreen := false
var banner := false
var dect := ""
var error := ""


static func parse(arguments: PackedStringArray) -> Cli:
	var options := Cli.new()
	var index := 0
	while index < arguments.size() and not options.error:
		var flag := arguments[index]
		if flag == "--fullscreen":
			options.fullscreen = true
			index += 1
			continue
		if index + 1 >= arguments.size():
			options.error = "%s needs a value" % flag
			break
		options._assign(flag, arguments[index + 1])
		index += 2
	if not options.error:
		options.error = options._validate()
	if not options.error and options.token_file:
		options.error = options._read_token()
	return options


func _assign(flag: String, value: String) -> void:
	match flag:
		"--file":
			file = value
		"--url":
			url = value
		"--token":
			token = value
		"--token-file":
			token_file = value
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
	if token and token_file:
		return "--token and --token-file are exclusive"
	if (token or token_file) and not url:
		return "--token requires --url"
	return ""


func _read_token() -> String:
	var content := FileAccess.get_file_as_string(token_file)
	if content.is_empty() and FileAccess.get_open_error() != OK:
		return "cannot read --token-file %s" % token_file
	token = content.strip_edges()
	return ""
