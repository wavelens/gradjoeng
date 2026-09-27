shader_type sky;

uniform float star_light = 0.25;

vec3 hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}

void sky() {
	vec3 light = vec3(0.0);
	for (int layer = 0; layer < 3; layer++) {
		float density = 110.0 + 130.0 * float(layer);
		vec3 cell = floor(EYEDIR * density);
		vec3 seed = hash3(cell + float(layer) * 31.7);
		if (seed.x < 0.994) {
			continue;
		}
		vec3 star = (cell + 0.5 + (seed - 0.5) * 0.6) / density;
		float spread = length(EYEDIR - normalize(star)) * density;
		float brightness = pow(seed.y, 10.0) * 0.5 + 0.04;
		vec3 tint = mix(vec3(0.65, 0.75, 1.0), vec3(1.0, 0.85, 0.65), seed.z);
		light += tint * brightness * exp(-spread * spread * 220.0);
	}
	COLOR = light * star_light;
}
