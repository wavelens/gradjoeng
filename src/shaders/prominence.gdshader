shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/noise.gdshaderinc"

uniform float energy = 1.0;

void fragment() {
	float along = UV.x;
	float across = abs(UV.y * 2.0 - 1.0);
	float strands = pow(noise3(vec3(UV.y * 6.0, along * 6.0 - TIME * 0.35, COLOR.b * 7.0)), 2.0);
	float body = pow(max(1.0 - across, 0.0), 2.5);
	float flow = 0.5 + 0.5 * noise3(vec3(along * 18.0 - TIME * 0.8, COLOR.b * 5.0, 0.0));
	vec3 plasma = mix(vec3(0.7, 0.05, 0.02), vec3(1.0, 0.25, 0.05), strands);
	ALBEDO = plasma * body * (0.35 + strands * 0.9) * flow * energy;
	ALPHA = COLOR.a;
}
