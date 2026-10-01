// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type canvas_item;

const int MAX_GLITCHES = 8;
const float TEAR = 60.0;
const float SPLIT = 5.0;

uniform vec4 glitches[MAX_GLITCHES];
uniform vec2 canvas = vec2(1152.0, 648.0);

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float strength(vec2 pixel) {
	float total = 0.0;
	for (int i = 0; i < MAX_GLITCHES; i++) {
		vec4 glitch = glitches[i];
		vec2 reach = vec2(glitch.z * 2.0 + 230.0, glitch.z * 2.0 + 60.0);
		float falloff = 1.0 - smoothstep(0.6, 1.0, length((pixel - glitch.xy) / reach));
		total = max(total, glitch.w * falloff);
	}
	return total;
}

vec4 ink(sampler2D source, vec2 pixel) {
	return texture(source, pixel / canvas);
}

void fragment() {
	vec2 pixel = UV * canvas;
	float s = strength(pixel);
	if (s <= 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float tick = floor(TIME * 30.0);
		float row = floor(pixel.y / mix(3.0, 14.0, random(vec2(tick, 1.0))));
		float tear = step(1.0 - s * 0.6, random(vec2(row, tick))) * (random(vec2(row, tick + 7.0)) - 0.5) * TEAR * s;
		vec2 at = pixel + vec2(tear, 0.0);
		vec4 red = ink(TEXTURE, at + vec2(SPLIT * s, 0.0));
		vec4 green = ink(TEXTURE, at);
		vec4 blue = ink(TEXTURE, at - vec2(SPLIT * s, 0.0));
		float alpha = max(max(red.a, green.a), blue.a);
		vec3 color = vec3(red.r * red.a, green.g * green.a, blue.b * blue.a) / max(alpha, 0.001);
		float dropout = step(random(vec2(floor(pixel.y / 2.0), tick + 11.0)), s * 0.25);
		COLOR = vec4(color, alpha * (1.0 - dropout * 0.8));
	}
}
