// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type sky;

#include "res://src/shaders/noise.gdshaderinc"

uniform float star_light = 0.4;
uniform float galaxy_light = 0.035;
uniform vec3 galactic_pole = vec3(0.35, 0.8, 0.45);

vec3 hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}

vec3 stars(vec3 direction, float crowding) {
	vec3 light = vec3(0.0);
	for (int layer = 0; layer < 3; layer++) {
		float density = 110.0 + 130.0 * float(layer);
		vec3 cell = floor(direction * density);
		vec3 seed = hash3(cell + float(layer) * 31.7);
		if (seed.x < 0.993 - crowding * 0.012) {
			continue;
		}
		vec3 star = (cell + 0.5 + (seed - 0.5) * 0.6) / density;
		float spread = length(direction - normalize(star)) * density;
		float brightness = pow(seed.y, 10.0) * 2.0 + 0.08;
		vec3 tint = mix(vec3(0.65, 0.75, 1.0), vec3(1.0, 0.85, 0.65), seed.z);
		light += tint * brightness * exp(-spread * spread * 120.0);
	}
	return light;
}

void sky() {
	float band = exp(-pow(dot(EYEDIR, normalize(galactic_pole)), 2.0) * 14.0);
	float dust = fbm3(EYEDIR * 3.0 + 7.0);
	float lanes = smoothstep(0.45, 0.7, fbm3(EYEDIR * 9.0));
	vec3 galaxy = mix(vec3(0.55, 0.6, 0.8), vec3(1.0, 0.82, 0.62), dust) * band * dust * (1.0 - 0.7 * lanes);
	COLOR = stars(EYEDIR, band) * star_light + galaxy * galaxy_light;
}
