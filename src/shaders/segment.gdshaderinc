// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

// Instance layout from RibbonBatch.segment: model columns hold from, to, (width from, width to, along from) and along to; COLOR and custom hold the end colors.
void segment(inout vec2 uv, inout vec4 color, out vec4 position, mat4 model, vec4 color_to, mat4 view, mat4 inv_view, mat4 projection) {
	vec3 from = model[0].xyz;
	vec3 to = model[1].xyz;
	float t = uv.x;
	vec3 side = normalize(cross(to - from, inv_view[3].xyz - from));
	vec3 at = mix(from, to, t) + side * (uv.y - 0.5) * mix(model[2].x, model[2].y, t);
	position = projection * view * vec4(at, 1.0);
	uv.x = mix(model[2].z, model[3].x, t);
	color = mix(color, color_to, t);
}
