#version 330
#include camera

uniform float time;
uniform float energy;
uniform float horizon;
uniform vec2 disk;

out vec4 color;

const int STEPS = 220;
const float ESCAPE = 60.0;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
    float sum = 0.0, amp = 0.5;
    for (int i = 0; i < 5; i++) {
        sum += amp * noise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    return sum;
}

vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}

vec3 stars(vec3 d) {
    vec3 light = vec3(0.0);
    for (int layer = 0; layer < 3; layer++) {
        float density = 90.0 + 110.0 * float(layer);
        vec3 cell = floor(d * density);
        vec3 seed = hash3(cell + float(layer) * 31.7);
        if (seed.x < 0.996) continue;
        vec3 star = (cell + 0.5 + (seed - 0.5) * 0.6) / density;
        float spread = length(d - normalize(star)) * density;
        float brightness = pow(seed.y, 8.0) * 0.6 + 0.06;
        vec3 tint = mix(vec3(0.65, 0.75, 1.0), vec3(1.0, 0.82, 0.6), seed.z);
        light += tint * brightness * exp(-spread * spread * 160.0);
    }
    return light;
}


vec3 blackbody(float heat) {
    vec3 cool = vec3(1.0, 0.28, 0.05);
    vec3 warm = vec3(1.0, 0.62, 0.25);
    vec3 hot = vec3(1.0, 0.93, 0.85);
    return heat < 0.5 ? mix(cool, warm, heat * 2.0) : mix(warm, hot, heat * 2.0 - 1.0);
}

vec4 disk_emission(vec3 hit, vec3 ray) {
    float r = length(hit.xz);
    float heat = clamp((disk.y - r) / (disk.y - disk.x), 0.0, 1.0);
    float spin = time * 1.6 / pow(r, 1.5);
    float c = cos(spin), s = sin(spin);
    vec2 swirl = mat2(c, -s, s, c) * hit.xz;
    float turbulence = fbm(vec2(r * 2.2, 0.0) + swirl * 1.3);
    vec3 orbit = normalize(vec3(-hit.z, 0.0, hit.x));
    float beta = clamp(0.7 / sqrt(r), 0.0, 0.6);
    float doppler = pow(1.0 / (1.0 - beta * dot(orbit, -normalize(ray))), 3.0);
    float edge = smoothstep(disk.x, disk.x + 0.4, r) * smoothstep(disk.y, disk.y - 1.6, r);
    vec3 glow = blackbody(heat) * (0.25 + 1.6 * turbulence * turbulence) * (0.6 + 2.4 * heat * heat) * doppler * energy;
    return vec4(glow * 0.4, edge * (0.45 + 0.55 * turbulence));
}

void main() {
    vec2 p = (gl_FragCoord.xy - 0.5 * resolution) / focal_pixels();
    vec3 ray = normalize(to_world(vec3(p, 1.0)));
    vec3 pos = to_world(vec3(0.0, 0.0, -distance)) / horizon;
    vec3 momentum = cross(pos, ray);
    float h2 = dot(momentum, momentum);

    vec3 light = vec3(0.0);
    float alpha = 0.0;
    float depth = 1.0;
    bool captured = false;

    for (int i = 0; i < STEPS; i++) {
        float r = length(pos);
        if (r < 1.0) {
            captured = true;
            depth = min(depth, window_depth(pos * horizon));
            break;
        }
        if (r > ESCAPE && dot(pos, ray) > 0.0) break;
        float dt = clamp(0.07 * r, 0.015, 2.5);
        vec3 next = pos + ray * dt;
        ray += -1.5 * h2 * pos / pow(r, 5.0) * dt;
        if (pos.y * next.y < 0.0) {
            vec3 hit = mix(pos, next, pos.y / (pos.y - next.y));
            float radius = length(hit.xz);
            if (radius > disk.x && radius < disk.y) {
                vec4 emission = disk_emission(hit, ray);
                light += (1.0 - alpha) * emission.rgb * emission.a;
                alpha += (1.0 - alpha) * emission.a;
                if (alpha > 0.6) depth = min(depth, window_depth(hit * horizon));
            }
        }
        pos = next;
    }

    if (!captured) light += (1.0 - alpha) * stars(normalize(ray));
    color = vec4(light, 1.0);
    gl_FragDepth = depth;
}
