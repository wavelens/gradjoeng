// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/segment.gdshaderinc"

uniform float energy = 1.8;
uniform float time = 0.0;
uniform float speed = 7.5;
uniform float spacing = 1.0;
uniform float dash = 0.3;

void vertex() {
	segment(UV, COLOR, POSITION, MODEL_MATRIX, INSTANCE_CUSTOM, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
	float packet = step(fract((UV.x - time * speed) / spacing) * spacing, dash);
	ALBEDO = COLOR.rgb * energy * packet;
	ALPHA = COLOR.a * packet;
}
