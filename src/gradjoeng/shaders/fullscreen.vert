#version 330
in vec2 in_pos;
out vec2 uv;

void main() {
    uv = in_pos * 0.5 + 0.5;
    gl_Position = vec4(in_pos, 0.0, 1.0);
}
