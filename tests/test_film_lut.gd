# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func gray(level: float) -> Color:
	return FilmLut.grade(Color(level, level, level))


func test_grade_keeps_tonal_order() -> void:
	var previous := -1.0
	for step in 21:
		var graded := gray(step / 20.0)
		var luma := graded.r * 0.3 + graded.g * 0.59 + graded.b * 0.11
		check(luma > previous, "brighter input stays brighter at %d" % step)
		previous = luma


func test_blacks_lift_and_whites_roll_off_like_film() -> void:
	check(gray(0.0).g > 0.0, "black point is lifted")
	check(gray(1.0).g < 1.0 and gray(1.0).g > 0.9, "whites roll off below clipping")


func test_split_tone_cools_shadows_and_warms_highlights() -> void:
	check(gray(0.15).b > gray(0.15).r, "shadows lean teal")
	check(gray(0.85).r > gray(0.85).b, "highlights lean warm")


func test_lut_slices_bake_the_grade() -> void:
	var slices := FilmLut.slices(9)
	equal([slices.size(), slices[0].get_width(), slices[0].get_height()], [9, 9, 9])
	var sample := slices[4].get_pixel(2, 6)
	var expected := FilmLut.grade(Color(2.0 / 8.0, 6.0 / 8.0, 4.0 / 8.0))
	near(sample.r, expected.r, 0.01, "red")
	near(sample.g, expected.g, 0.01, "green")
	near(sample.b, expected.b, 0.01, "blue")
