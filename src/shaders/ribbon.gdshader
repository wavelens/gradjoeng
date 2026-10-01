// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy = 1.8;

void fragment() {
	ALBEDO = COLOR.rgb * energy;
	ALPHA = COLOR.a;
}
