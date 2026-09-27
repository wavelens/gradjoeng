#version 330
uniform sampler2D scene;
uniform sampler2D bloom;
uniform vec2 shake;
uniform float exposure;
uniform float time;
in vec2 uv;
out vec4 color;

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec2 at = uv + shake;
    vec2 offset = (at - 0.5) * 0.0012;
    vec3 hdr = vec3(texture(scene, at + offset).r, texture(scene, at).g, texture(scene, at - offset).b);
    hdr += texture(bloom, at).rgb * 0.9;
    vec3 mapped = pow(aces(hdr * exposure), vec3(1.0 / 2.2));
    float vignette = smoothstep(1.25, 0.35, length(uv - 0.5) * 1.4);
    float grain = fract(sin(dot(uv * 1000.0 + time, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    color = vec4(mapped * vignette + grain * 0.012, 1.0);
}
