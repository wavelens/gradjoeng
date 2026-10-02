// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/curve.gdshaderinc"

uniform float energy = 1.8;

void vertex() {
	float t = comet_time(MODEL_MATRIX, UV.x);
	vec3 at = comet_point(MODEL_MATRIX, t);
	POSITION = ribbon_position(at, at + comet_heading(MODEL_MATRIX, t), (UV.y - 0.5) * MODEL_MATRIX[3].z * max(UV.x, 0.2), VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX);
	COLOR.a *= UV.x;
}

void fragment() {
	ALBEDO = COLOR.rgb * energy;
	ALPHA = COLOR.a;
}
