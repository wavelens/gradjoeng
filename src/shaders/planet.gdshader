shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://src/shaders/billboard.gdshaderinc"
#include "res://src/shaders/noise.gdshaderinc"

const float SEA = 0.5;
const vec3 SUNLIGHT = vec3(1.0, 0.86, 0.72);
const vec3 SKY = vec3(0.3, 0.55, 1.0);
const vec3 CITY = vec3(1.0, 0.68, 0.3);

uniform vec3 sun = vec3(0.0);
uniform float spin = 0.1;
uniform float energy = 1.0;

varying vec4 tint;
varying float seed;
varying float heat;
varying vec3 light;
varying float offline;
varying float loaded;

float bayer(vec2 pixel) {
	int index = int(mod(pixel.x, 4.0)) + int(mod(pixel.y, 4.0)) * 4;
	float matrix[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (matrix[index] + 0.5) / 16.0;
}

vec3 turn(vec3 p, float angle) {
	return vec3(cos(angle) * p.x - sin(angle) * p.z, p.y, sin(angle) * p.x + cos(angle) * p.z);
}

vec3 terrain(vec3 ground, float height, float land) {
	vec3 origin = ground * 2.0 + seed * 23.0;
	vec3 ocean = mix(vec3(0.01, 0.04, 0.16), vec3(0.03, 0.2, 0.4), smoothstep(SEA - 0.14, SEA, height));
	float dry = fbm3(origin * 1.4 + 5.0) + (1.0 - abs(ground.y)) * 0.12;
	vec3 lowland = mix(vec3(0.07, 0.3, 0.09), vec3(0.58, 0.46, 0.22), smoothstep(0.5, 0.66, dry));
	vec3 ground_color = mix(lowland, vec3(0.4, 0.34, 0.3), smoothstep(SEA + 0.1, SEA + 0.22, height));
	vec3 color = mix(ocean, ground_color, land);
	float ice = smoothstep(0.74, 0.8, abs(ground.y) + 0.2 * (fbm3(origin * 4.0) - 0.5));
	return mix(color, vec3(0.9, 0.94, 1.0), ice);
}

float cities(vec3 ground, float land) {
	vec3 origin = ground * 2.0 + seed * 23.0;
	float regions = smoothstep(0.45, 0.62, fbm3(origin * 2.5 + 9.0));
	float sprawl = smoothstep(0.72, 0.9, noise3(origin * 70.0));
	float polar = 1.0 - smoothstep(0.6, 0.72, abs(ground.y));
	return regions * sprawl * land * polar;
}

void vertex() {
	light = normalize(sun - MODEL_MATRIX[3].xyz);
	billboard(MODELVIEW_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	tint = COLOR;
	seed = INSTANCE_CUSTOM.x;
	heat = INSTANCE_CUSTOM.y;
	offline = INSTANCE_CUSTOM.z;
	loaded = INSTANCE_CUSTOM.w;
}

vec2 torn(vec2 uv) {
	float frame = floor(TIME * 24.0);
	float tear = hash13(vec3(floor(uv.y * 14.0), frame, seed * 97.0));
	return uv + vec2(step(0.55, tear) * (tear - 0.75) * 0.6 * offline, 0.0);
}

void fragment() {
	vec2 p = torn(UV) * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || tint.a < bayer(FRAGCOORD.xy)) {
		discard;
	}
	vec3 facing = vec3(p.x, -p.y, sqrt(1.0 - r * r));
	vec3 normal = normalize(mat3(INV_VIEW_MATRIX) * facing);
	vec3 eye = normalize(mat3(INV_VIEW_MATRIX) * vec3(0.0, 0.0, 1.0));
	float lambert = dot(normal, light);
	float day = smoothstep(-0.1, 0.3, lambert);

	vec3 ground = turn(normal, TIME * spin + seed * 6.2831853);
	vec3 origin = ground * 2.0 + seed * 23.0;
	float height = fbm3(origin) * 0.75 + fbm3(origin * 3.1) * 0.35;
	float land = smoothstep(SEA, SEA + 0.015, height);
	vec3 surface = terrain(ground, height, land);

	vec3 sky = turn(normal, TIME * spin * 1.7 + seed * 6.2831853 + 1.3);
	float cloud = smoothstep(0.52, 0.78, fbm3(sky * 3.2 + seed * 11.0 + vec3(0.0, 0.0, TIME * 0.015)));
	surface = mix(surface, vec3(1.0), cloud * 0.85);

	vec3 color = surface * SUNLIGHT * (0.025 + 1.15 * day * max(lambert, 0.0));
	float glint = pow(max(dot(reflect(-light, normal), eye), 0.0), 40.0);
	color += SUNLIGHT * glint * (1.0 - land) * (1.0 - cloud) * day * 0.6;
	color += CITY * cities(ground, land) * (1.0 - day) * (1.0 - cloud * 0.7) * (0.3 + 0.9 * heat);
	color += vec3(1.0, 0.38, 0.12) * exp(-abs(lambert) * 18.0) * 0.06;

	vec3 atmosphere = mix(SKY, tint.rgb, 0.45);
	float rim = pow(1.0 - facing.z, 4.0);
	color = mix(color, atmosphere, rim * (0.08 + 0.6 * smoothstep(-0.2, 0.4, lambert)));
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, tint.rgb * luma * 2.2, loaded * 0.8);
	color = mix(color, vec3(luma), offline);
	color *= 1.0 - 0.6 * offline * step(0.8, hash13(vec3(floor(UV.y * 40.0), floor(TIME * 24.0), 3.0)));
	ALBEDO = color * energy;
}
