#version 430

// Shader: Bromine Clouds
// Shader Author: Kaso
// File Author: vexalous
// Source: https://fragcoord.xyz/s/b6749csy
// License: CC BY-SA 4.0
// Uniforms: u_resolution, u_time, brightness, u_camForward, u_camRight, u_camUp, u_tanHalfFov

uniform vec2 u_resolution;
uniform float u_time;
uniform float brightness;

uniform vec3 u_camForward;
uniform vec3 u_camRight;
uniform vec3 u_camUp;
uniform float u_tanHalfFov;

in vec2 uv;
out vec4 fragColor;

vec3 hash3(vec3 p) {
    p = fract(p * vec3(123.34, 456.21, 789.12));
    p += dot(p, p + 34.45);
    return fract(vec3(p.x * p.y, p.y * p.z, p.z * p.x));
}

float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float x00 = mix(hash3(i + vec3(0.0,0.0,0.0)).x, hash3(i + vec3(1.0,0.0,0.0)).x, f.x);
    float x10 = mix(hash3(i + vec3(0.0,1.0,0.0)).x, hash3(i + vec3(1.0,1.0,0.0)).x, f.x);
    float x01 = mix(hash3(i + vec3(0.0,0.0,1.0)).x, hash3(i + vec3(1.0,0.0,1.0)).x, f.x);
    float x11 = mix(hash3(i + vec3(0.0,1.0,1.0)).x, hash3(i + vec3(1.0,1.0,1.0)).x, f.x);

    float y0 = mix(x00, x10, f.y);
    float y1 = mix(x01, x11, f.y);

    return mix(y0, y1, f.z);
}

float fbm3D(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise3D(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec3 palette(float t) {
    vec3 a = vec3(0.10, 0.05, 0.15);
    vec3 b = vec3(0.40, 0.35, 0.55);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.10, 0.20);
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    vec2 p_screen = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    p_screen.x *= u_resolution.x / u_resolution.y;

    vec3 dir = normalize(u_camForward + p_screen.x * u_tanHalfFov * u_camRight + p_screen.y * u_tanHalfFov * u_camUp);

    vec3 noisePos = dir * 2.5;
    float t = u_time * 0.05;

    vec3 flow = vec3(
        fbm3D(noisePos * 2.0 + vec3(0.0, t, 0.0)),
        fbm3D(noisePos * 2.0 + vec3(0.0, -t, 0.0)),
        fbm3D(noisePos * 2.0 + vec3(t, 0.0, 0.0))
    );
    vec3 q = noisePos + 0.35 * (flow - 0.5);

    float n1 = fbm3D(q * 1.5 + t);
    float n2 = fbm3D(q * 3.0 - t * 1.3);
    float intensity = smoothstep(0.3, 0.9, n1 + 0.6 * n2);

    float colorField = fbm3D(q * 1.0 + intensity + t);
    vec3 col = palette(colorField + intensity * 0.5);

    col *= intensity * 2.0;
    col = 1.0 - exp(-col);

    fragColor = vec4(col * brightness, 1.0);
}
