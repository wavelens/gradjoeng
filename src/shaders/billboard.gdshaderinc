void billboard(inout mat4 modelview, mat4 view, mat4 inv_view, mat4 model) {
	modelview = view * mat4(inv_view[0], inv_view[1], inv_view[2], model[3]);
	modelview = modelview * mat4(
		vec4(length(model[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(model[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(model[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}
