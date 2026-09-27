#version 330
#include camera

in vec2 corner;
in vec3 center;
in float size;
in vec3 tint;
in float kind;
in float spin;

out vec2 local;
out vec3 v_tint;
flat out float v_kind;
out float v_spin;

void main() {
    float radius_px = max(size * focal_pixels() / (distance + to_view(center).z), 1.5);
    gl_Position = clip_position(center, corner * radius_px);
    local = corner;
    v_tint = tint;
    v_kind = kind;
    v_spin = spin;
}
