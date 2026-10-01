// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/billboard.gdshaderinc"
#include "res://src/shaders/noise.gdshaderinc"

uniform float inner = 0.8;
uniform float energy = 1.0;

void vertex() {
	billboard(MODELVIEW_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) / inner;
	if (r < 0.99) {
		discard;
	}
	vec2 around = p / max(length(p), 1e-4);
	float spicules = noise3(vec3(around * 420.0, TIME * 0.3));
	float rim = exp(-(r - 1.0) * 180.0) * (0.5 + 0.9 * spicules);
	ALBEDO = vec3(0.8, 0.06, 0.02) * rim * energy;
	ALPHA = 1.0;
}
