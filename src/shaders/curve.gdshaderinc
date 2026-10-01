// SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
//
// SPDX-License-Identifier: MIT

vec4 ribbon_position(vec3 at, vec3 ahead, float offset, mat4 view, mat4 inv_view, mat4 projection) {
	vec3 side = normalize(cross(ahead - at, inv_view[3].xyz - at));
	return projection * view * vec4(at + side * offset, 1.0);
}
