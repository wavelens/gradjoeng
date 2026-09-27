#version 330
uniform sampler2D overlay;
in vec2 uv;
out vec4 color;

void main() { color = texture(overlay, uv); }
