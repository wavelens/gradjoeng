// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/curve.gdshaderinc"

const float HALO = 4.0;
const float CORE = 1.2;

uniform float energy = 1.6;

void vertex() {
	vec3 head = comet_point(MODEL_MATRIX, comet_time(MODEL_MATRIX, 1.0));
	vec4 center = VIEW_MATRIX * vec4(head, 1.0);
	POSITION = PROJECTION_MATRIX * (center + vec4(VERTEX.xy * MODEL_MATRIX[3].z * HALO * 2.0, 0.0, 0.0));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float halo = clamp(pow(max(1.0 - r, 0.0), 2.4) * COLOR.a, 0.0, 1.0);
	float core = clamp(pow(max(1.0 - r * HALO / CORE, 0.0), 2.4), 0.0, 1.0);
	ALBEDO = (COLOR.rgb * 0.8 * halo + vec3(core)) * energy;
	ALPHA = 1.0;
}
