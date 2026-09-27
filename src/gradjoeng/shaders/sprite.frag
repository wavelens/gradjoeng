#version 330
in vec2 local;
in vec3 v_tint;
flat in float v_kind;
in float v_spin;

out vec4 color;

const float TAU = 6.2831853;

float arcs(float r, float angle) {
    float shape = 0.0;
    for (int i = 0; i < 3; i++) {
        float direction = (i % 2 == 0) ? 1.0 : -1.0;
        float start = v_spin * (1.2 + 0.7 * float(i)) * direction + 2.1 * float(i);
        float within = step(mod(angle - start, TAU), 1.9);
        shape += smoothstep(0.05, 0.0, abs(r - (0.55 + 0.2 * float(i)))) * within;
    }
    return shape;
}

void main() {
    float r = length(local);
    if (r > 1.0) discard;
    float shape;
    if (v_kind < 0.5) shape = pow(1.0 - r, 2.4);
    else if (v_kind < 1.5) shape = smoothstep(1.0, 0.75, r);
    else shape = arcs(r, atan(local.y, local.x));
    color = vec4(v_tint * shape, 1.0);
}
