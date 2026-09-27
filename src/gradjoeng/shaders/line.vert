#version 330
#include camera

in vec3 in_pos;
in vec3 in_color;
out vec3 v_color;

void main() {
    gl_Position = clip_position(in_pos, vec2(0.0));
    v_color = in_color;
}
