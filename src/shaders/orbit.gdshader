shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/shaders/curve.gdshaderinc"

uniform float energy = 1.8;

vec3 ring(float s) {
	return vec3(cos(s * TAU), 0.0, sin(s * TAU));
}

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(ring(UV.x), 1.0)).xyz;
	vec3 ahead = (MODEL_MATRIX * vec4(ring(UV.x + 0.01), 1.0)).xyz;
	POSITION = ribbon_position(at, ahead, (UV.y - 0.5) * INSTANCE_CUSTOM.x, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
	ALBEDO = COLOR.rgb * energy;
	ALPHA = COLOR.a;
}
