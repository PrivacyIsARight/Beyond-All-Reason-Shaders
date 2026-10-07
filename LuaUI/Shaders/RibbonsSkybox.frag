#version 430

// Shader: Ribbons
// Shader Author: lnbg0175
// File Author: vexalous
// Source: https://fragcoord.xyz/s/lnbg0175
// License: CC BY-NC-SA 4.0
// Uniforms: u_resolution, u_time, brightness, u_camForward, u_camRight, u_camUp, u_tanHalfFov

uniform vec2 u_resolution;
uniform float u_time;
uniform float brightness;

uniform vec3 u_camForward;
uniform vec3 u_camRight;
uniform vec3 u_camUp;
uniform float u_tanHalfFov;

out vec4 fragColor;

void main() {
    vec2 p_screen = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    p_screen.x *= u_resolution.x / u_resolution.y;
    vec3 dir = normalize(u_camForward + p_screen.x * u_tanHalfFov * u_camRight + p_screen.y * u_tanHalfFov * u_camUp);

    float t2 = u_time * 0.5;
    const float dScale = 1.0 / 0.9;
    const float dUnscale = 0.9;

    float z = 0.0;
    float d = 0.0;
    float i = 0.0;
    vec3 O = vec3(0.0);

    for (int k = 0; k < 99; k++) {
        vec3 p = z * dir;
        d = 2.0;
        float invD = 0.5;

        for (int j = 0; j < 6; j++) {
            d *= dScale;
            invD *= dUnscale;
            p = p.zxy + sin(p * d + (d + t2)) * invD;
        }

        d = 0.001 + abs(2.0 - mix(z, p.z, 0.4)) * (1.0 / 9.0);
        z += d;

        O += (sin(z + 0.06 * i + vec3(0.0, 1.0, 2.0)) + 1.0) / d;
        i += 1.0;
    }

    fragColor = vec4(tanh(O * (1.0 / 30000.0)) * brightness, 1.0);
}
