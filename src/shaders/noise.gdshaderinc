// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), u.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y),
		u.z);
}

float fbm3(vec3 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amplitude * noise3(p);
		p = p * 2.02 + 11.7;
		amplitude *= 0.5;
	}
	return sum;
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

vec2 cells(vec3 p, float time) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 offset = vec3(float(x), float(y), float(z));
				vec3 seed = hash33(i + offset);
				vec3 point = offset + 0.5 + 0.4 * sin(time * (0.6 + seed) + seed * 6.2831853);
				float d = length(point - f);
				if (d < first) {
					second = first;
					first = d;
				} else if (d < second) {
					second = d;
				}
			}
		}
	}
	return vec2(first, second);
}
