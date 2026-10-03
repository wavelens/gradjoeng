// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/noise.gdshaderinc"
#include "res://src/shaders/curve.gdshaderinc"

uniform float energy = 1.0;
uniform float radius = 1.0;
const float FRONT = 0.12;

varying float reach;

vec3 arc(float s, float spread, float height) {
	return normalize(vec3(1.0, (s - 0.5) * spread, 0.0)) * (radius + sin(s * PI) * height);
}

void vertex() {
	vec4 shape = INSTANCE_CUSTOM;
	reach = shape.w * (1.0 + FRONT);
	vec3 at = (MODEL_MATRIX * vec4(arc(UV.x, shape.x, shape.y), 1.0)).xyz;
	vec3 ahead = (MODEL_MATRIX * vec4(arc(UV.x + 0.01, shape.x, shape.y), 1.0)).xyz;
	POSITION = ribbon_position(at, ahead, (UV.y - 0.5) * shape.z, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
	float along = UV.x;
	float across = abs(UV.y * 2.0 - 1.0);
	float strands = pow(noise3(vec3(UV.y * 6.0, along * 6.0 - TIME * 0.35, COLOR.b * 7.0)), 2.0);
	float body = pow(max(1.0 - across, 0.0), 2.5);
	float flow = 0.5 + 0.5 * noise3(vec3(along * 18.0 - TIME * 0.8, COLOR.b * 5.0, 0.0));
	float leg = 1.0 - abs(along * 2.0 - 1.0);
	float ragged = reach + (noise3(vec3(COLOR.b * 11.0, TIME * 0.6, along * 3.0)) - 0.5) * FRONT;
	float filled = 1.0 - smoothstep(ragged - FRONT, ragged, leg);
	float settled = smoothstep(1.0, 1.0 + FRONT, reach);
	float front = exp(-pow((leg - ragged + FRONT * 0.5) / (FRONT * 0.4), 2.0)) * (1.0 - settled);
	float footpoint = exp(-leg * 14.0);
	vec3 plasma = mix(vec3(0.7, 0.05, 0.02), vec3(1.0, 0.25, 0.05), strands + front * 0.6);
	ALBEDO = plasma * body * ((0.35 + strands * 0.9) * flow * filled + front * 0.8 + footpoint * 0.6) * energy;
	ALPHA = COLOR.a;
}
