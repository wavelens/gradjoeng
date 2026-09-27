#version 330
uniform sampler2D source;
uniform vec2 direction;
in vec2 uv;
out vec4 color;

const float WEIGHTS[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

void main() {
    vec2 step = direction / vec2(textureSize(source, 0));
    vec3 sum = texture(source, uv).rgb * WEIGHTS[0];
    for (int i = 1; i < 5; i++) {
        sum += texture(source, uv + step * float(i)).rgb * WEIGHTS[i];
        sum += texture(source, uv - step * float(i)).rgb * WEIGHTS[i];
    }
    color = vec4(sum, 1.0);
}
