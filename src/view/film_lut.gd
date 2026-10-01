# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name FilmLut
## Film-emulation grade baked into a 3D lookup texture for the environment's color correction.

const SIZE := 33
const TOE := 0.018
const SHOULDER := 0.95
const CONTRAST := 0.35
const SATURATION := 0.9
const SHADOW_TINT := Color(-0.012, 0.004, 0.022)
const HIGHLIGHT_TINT := Color(0.03, 0.008, -0.03)


static func grade(color: Color) -> Color:
	var rgb := Vector3(color.r, color.g, color.b)
	var curved := rgb.lerp(rgb * rgb * (Vector3.ONE * 3.0 - rgb * 2.0), CONTRAST)
	var luma := curved.dot(Vector3(0.2126, 0.7152, 0.0722))
	var saturation := SATURATION * (1.0 - 0.35 * smoothstep(0.6, 1.0, luma))
	var toned := Vector3.ONE * luma + (curved - Vector3.ONE * luma) * saturation
	var shadow := 1.0 - smoothstep(0.0, 0.5, luma)
	var highlight := smoothstep(0.45, 1.0, luma)
	toned += Vector3(SHADOW_TINT.r, SHADOW_TINT.g, SHADOW_TINT.b) * shadow + Vector3(HIGHLIGHT_TINT.r, HIGHLIGHT_TINT.g, HIGHLIGHT_TINT.b) * highlight
	var film := Vector3.ONE * TOE + toned * (SHOULDER - TOE)
	return Color(clampf(film.x, 0.0, 1.0), clampf(film.y, 0.0, 1.0), clampf(film.z, 0.0, 1.0))


static func slices(size: int = SIZE) -> Array[Image]:
	var result: Array[Image] = []
	var scale := 1.0 / (size - 1)
	for blue in size:
		var slice := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
		for green in size:
			for red in size:
				slice.set_pixel(red, green, grade(Color(red * scale, green * scale, blue * scale)))
		result.append(slice)
	return result


static func texture() -> ImageTexture3D:
	var lut := ImageTexture3D.new()
	lut.create(Image.FORMAT_RGB8, SIZE, SIZE, SIZE, false, slices())
	return lut
