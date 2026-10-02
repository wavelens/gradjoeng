// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

vec4 ribbon_position(vec3 at, vec3 ahead, float offset, mat4 view, mat4 inv_view, mat4 projection) {
	vec3 side = normalize(cross(ahead - at, inv_view[3].xyz - at));
	return projection * view * vec4(at + side * offset, 1.0);
}

float comet_time(mat4 path, float along) {
	float progress = mix(path[3].x, path[3].y, along);
	return progress * progress * (3.0 - 2.0 * progress);
}

vec3 comet_point(mat4 path, float t) {
	return mix(mix(path[0].xyz, path[1].xyz, t), mix(path[1].xyz, path[2].xyz, t), t);
}

vec3 comet_heading(mat4 path, float t) {
	return mix(path[1].xyz - path[0].xyz, path[2].xyz - path[1].xyz, t);
}
