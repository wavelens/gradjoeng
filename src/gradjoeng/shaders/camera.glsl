uniform vec2 resolution;
uniform float yaw;
uniform float pitch;
uniform float distance;
uniform float focal;

const float NEAR = 0.5;
const float FAR = 400.0;

vec3 rot_x(vec3 v, float a) {
    float c = cos(a), s = sin(a);
    return vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

vec3 rot_y(vec3 v, float a) {
    float c = cos(a), s = sin(a);
    return vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

vec3 to_view(vec3 p) { return rot_x(rot_y(p, -yaw), pitch); }

vec3 to_world(vec3 v) { return rot_y(rot_x(v, -pitch), yaw); }

float focal_pixels() { return focal * min(resolution.x, resolution.y); }

float ndc_depth(float depth) {
    return (FAR + NEAR) / (FAR - NEAR) - 2.0 * FAR * NEAR / ((FAR - NEAR) * depth);
}

float window_depth(vec3 world) {
    return ndc_depth(distance + to_view(world).z) * 0.5 + 0.5;
}

vec4 clip_position(vec3 world, vec2 offset_px) {
    vec3 v = to_view(world);
    float depth = distance + v.z;
    vec2 px = v.xy * focal_pixels() / depth + offset_px;
    return vec4(px / (0.5 * resolution) * depth, ndc_depth(depth) * depth, depth);
}
