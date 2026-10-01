// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/billboard.gdshaderinc"

const float GLOW = 0.0;
const float RING = 1.0;

uniform float energy = 1.6;

varying flat float kind;
varying float width;
varying vec4 tint;

void vertex() {
	billboard(MODELVIEW_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	kind = INSTANCE_CUSTOM.x;
	width = INSTANCE_CUSTOM.y;
	tint = COLOR;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float shape;
	if (kind < RING - 0.5) {
		shape = pow(max(1.0 - r, 0.0), 2.4);
	} else {
		shape = smoothstep(width, width * 0.3, abs(r - (1.0 - width)));
	}
	ALBEDO = tint.rgb * energy;
	ALPHA = clamp(shape * tint.a, 0.0, 1.0);
}
