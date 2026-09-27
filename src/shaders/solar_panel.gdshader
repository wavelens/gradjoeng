shader_type spatial;
render_mode cull_disabled;

uniform vec2 cells = vec2(8.0, 3.0);

void fragment() {
	vec2 grid = abs(fract(UV * cells) - 0.5);
	float frame = step(0.44, max(grid.x, grid.y));
	ALBEDO = mix(vec3(0.03, 0.06, 0.16), vec3(0.55, 0.55, 0.6), frame);
	METALLIC = mix(0.55, 0.9, frame);
	ROUGHNESS = mix(0.18, 0.4, frame);
	SPECULAR = 0.8;
}
