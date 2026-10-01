# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func test_cpu_color_runs_green_blue_red() -> void:
	var green := Palette.cpu(0)
	var blue := Palette.cpu(50)
	var red := Palette.cpu(100)
	check(green.g == maxf(green.r, maxf(green.g, green.b)), "0% is green")
	check(blue.b == maxf(blue.r, maxf(blue.g, blue.b)), "50% is blue")
	check(red.r == maxf(red.r, maxf(red.g, red.b)), "100% is red")
	equal(Palette.cpu(150), red)


func test_message_color_matches_kind_fragment() -> void:
	equal(Palette.message("log_chunk"), Color("46ff8c"))
	equal(Palette.message("mystery"), Color("dcdcff"))
