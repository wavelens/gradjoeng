#version 330
uniform sampler2D source;
uniform float threshold;
in vec2 uv;
out vec4 color;

void main() {
    vec3 c = texture(source, uv).rgb;
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    color = vec4(c * max(luma - threshold, 0.0) / max(luma, 1e-4), 1.0);
}
