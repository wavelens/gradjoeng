# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func test_file_replay_options() -> void:
	var options := Cli.parse(["--file", "events/1.log", "--speed", "4", "--size", "800x600"])
	equal([options.file, options.speed, options.size], ["events/1.log", 4.0, Vector2i(800, 600)])
	equal(options.error, "")


func test_url_takes_base_and_poll_interval() -> void:
	var options := Cli.parse(["--url", "https://gradient.example", "--token", "t", "--poll", "2.5"])
	equal([options.url, options.token, options.poll], ["https://gradient.example", "t", 2.5])
	equal(Cli.parse(["--url", "https://gradient.example"]).poll, 5.0)


func test_requires_exactly_one_source() -> void:
	check(Cli.parse([]).error != "", "no source")
	check(Cli.parse(["--file", "a", "--url", "b"]).error != "", "two sources")


func test_rejects_token_without_url_and_unknown_flags() -> void:
	check(Cli.parse(["--file", "x", "--token", "t"]).error != "", "token without url")
	check(Cli.parse(["--file", "x", "--bogus"]).error != "", "unknown flag")
	check(Cli.parse(["--file"]).error != "", "missing value")


func test_banner_is_off_without_flag() -> void:
	equal(Cli.parse(["--file", "x"]).banner, false)


func test_banner_takes_dect_number_or_empty() -> void:
	var with_dect := Cli.parse(["--file", "x", "--banner", "1234"])
	equal([with_dect.banner, with_dect.dect, with_dect.error], [true, "1234", ""])
	var without_dect := Cli.parse(["--file", "x", "--banner", ""])
	equal([without_dect.banner, without_dect.dect, without_dect.error], [true, "", ""])
