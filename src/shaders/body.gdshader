shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://src/shaders/billboard.gdshaderinc"

uniform vec3 sun = vec3(0.0);
uniform float energy = 1.0;

varying vec4 tint;
varying float core;
varying vec3 light;

float bayer(vec2 pixel) {
	int index = int(mod(pixel.x, 4.0)) + int(mod(pixel.y, 4.0)) * 4;
	float matrix[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (matrix[index] + 0.5) / 16.0;
}

void vertex() {
	vec3 center = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	light = normalize((VIEW_MATRIX * vec4(sun, 1.0)).xyz - center);
	billboard(MODELVIEW_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	tint = COLOR;
	core = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || tint.a < bayer(FRAGCOORD.xy)) {
		discard;
	}
	vec3 normal = vec3(p.x, -p.y, sqrt(1.0 - r * r));
	float lambert = dot(normal, light);
	float band = lambert > 0.45 ? 1.0 : lambert > 0.05 ? 0.62 : 0.07;
	vec3 color = tint.rgb * band;
	color = mix(color, vec3(1.0), smoothstep(core, core * 0.6, r) * clamp(lambert * 2.0 + 0.2, 0.0, 1.0));
	color += vec3(1.0, 0.6, 0.3) * pow(1.0 - normal.z, 3.0) * max(dot(normal.xy, light.xy), 0.0) * 0.8;
	ALBEDO = color * energy;
}
