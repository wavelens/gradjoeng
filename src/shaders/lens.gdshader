shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float distortion = 0.08;
uniform float dispersion = 0.007;
uniform float vignette = 0.75;
uniform float grain = 0.045;
uniform float scanlines = 0.08;
uniform float jitter = 0.6;
uniform float halation = 0.35;
uniform float glitch = 0.0;
uniform float seed = 0.0;

const float BLOCK = 16.0;
const float TEAR = 120.0;

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 barrel(vec2 uv, float amount, float aspect) {
	vec2 centered = (uv - 0.5) * vec2(aspect, 1.0);
	centered *= 1.0 + amount * dot(centered, centered);
	return centered / vec2(aspect, 1.0) * (1.0 - amount * 0.25) + 0.5;
}

float channel(vec2 uv, int index) {
	bool inside = all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)));
	return inside ? texture(screen, uv)[index] : 0.0;
}

float tear(float row) {
	float height = mix(2.0, 40.0, random(vec2(seed, 7.0)));
	float band = floor(row / height + random(vec2(floor(row / 90.0), seed)) * 3.0);
	float hit = step(1.0 - glitch * 0.45, random(vec2(band, seed + 1.0)));
	return hit * (random(vec2(band, seed + 2.0)) - 0.5) * 2.0 * TEAR * glitch;
}

vec2 downlink(vec2 uv, vec2 pixel_size) {
	vec2 pixel = uv / pixel_size;
	float wobble = (random(vec2(floor(pixel.y / 3.0), floor(TIME * 24.0))) - 0.5) * jitter;
	uv.x += (tear(pixel.y) + wobble) * pixel_size.x;
	vec2 block = floor(pixel / BLOCK);
	if (random(block + seed) < glitch * 0.04) {
		uv += (vec2(random(block + seed + 2.0), random(block + seed + 3.0)) - 0.5) * BLOCK * 3.0 * pixel_size;
	}
	return uv;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = downlink(SCREEN_UV, SCREEN_PIXEL_SIZE);
	float spread = dispersion + glitch * 0.03;
	vec3 color = vec3(
		channel(barrel(uv, distortion + spread, aspect), 0),
		channel(barrel(uv, distortion, aspect), 1),
		channel(barrel(uv, distortion - spread, aspect), 2));
	vec3 bleed = textureLod(screen, uv, 5.0).rgb;
	color += max(bleed - 0.25, 0.0) * vec3(1.0, 0.45, 0.3) * halation;
	if (glitch > 0.0 && random(floor(SCREEN_UV / SCREEN_PIXEL_SIZE / BLOCK) + seed + 5.0) < glitch * 0.03) {
		color = floor(color * 5.0) / 5.0;
	}
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 offset = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	color *= 1.0 - vignette * smoothstep(0.25, 1.05, length(offset) * 1.25);
	color *= 1.0 - scanlines * (0.5 + 0.5 * sin(pixel.y * 3.14159));
	color += step(0.99997, random(floor(pixel))) * 0.35;
	color += (random(pixel * 0.731 + fract(TIME)) - 0.5) * (grain + glitch * 0.06);
	COLOR = vec4(color, 1.0);
}
