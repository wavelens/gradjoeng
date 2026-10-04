// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://src/shaders/noise.gdshaderinc"

uniform float intensity = 1.0;
uniform float rotation = 0.004;
uniform float flow_speed = 0.06;

varying vec3 local;

vec3 convection(vec3 p, float time) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 nearest = vec3(8.0, 8.0, 0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 offset = vec3(float(x), float(y), float(z));
				vec3 seed = hash33(i + offset);
				vec3 point = offset + 0.5 + 0.4 * sin(time * (0.4 + seed * 0.5) + seed * 6.2831853);
				float d = length(point - f);
				if (d < nearest.x) {
					nearest = vec3(d, nearest.x, seed.x);
				} else if (d < nearest.y) {
					nearest.y = d;
				}
			}
		}
	}
	return nearest;
}

vec3 flow(vec3 p, float time) {
	vec3 q = p * 1.7 + time;
	return vec3(fbm3(q + 3.1), fbm3(q + 17.9), fbm3(q + 41.3)) - 0.5;
}

float temperature(vec3 p, float time) {
	vec3 cell = convection(p * 58.0, time * 0.5);
	float pulse = 0.55 + 0.45 * sin(time * (0.8 + cell.z * 1.4) + cell.z * 40.0);
	float upwelling = (1.0 - smoothstep(0.0, 0.75, cell.x)) * pulse;
	float lanes = smoothstep(0.0, 0.3, cell.y - cell.x);
	float plumes = pow(1.0 - abs(fbm3(p * 5.0 + time * 0.03) * 2.0 - 1.0), 5.0);
	float filaments = fbm3(p * 9.0 - time * 0.04);
	return clamp(0.12 + 0.28 * upwelling * lanes + 0.45 * plumes + 0.35 * filaments - 0.06 * (1.0 - lanes), 0.0, 1.0);
}

vec3 glow(float heat) {
	vec3 crust = vec3(0.12, 0.01, 0.005);
	vec3 ember = vec3(0.55, 0.04, 0.01);
	vec3 magma = vec3(0.95, 0.16, 0.02);
	vec3 core = vec3(1.0, 0.42, 0.08);
	vec3 color = heat < 0.35 ? mix(crust, ember, heat / 0.35) : heat < 0.7 ? mix(ember, magma, (heat - 0.35) / 0.35) : mix(magma, core, (heat - 0.7) / 0.3);
	return color * (0.6 + 1.6 * heat * heat);
}

void vertex() {
	local = normalize(VERTEX);
}

void fragment() {
	float spin = TIME * rotation;
	vec3 p = vec3(cos(spin) * local.x - sin(spin) * local.z, local.y, sin(spin) * local.x + cos(spin) * local.z);

	float heat = temperature(p + flow(p, TIME * flow_speed) * 0.06, TIME);

	float spots = smoothstep(0.62, 0.72, fbm3(p * 1.8 + vec3(4.0, 1.5, TIME * 0.002)));
	heat *= 1.0 - spots * 0.8;

	float mu = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float limb = pow(mu, 0.55);
	ALBEDO = glow(heat) * limb * intensity;
}
