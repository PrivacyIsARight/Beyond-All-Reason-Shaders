#version 430

// Shader: Blue Iridescent Tunnel
// Shader Author: Yusef28
// File Author: vexalous
// Source: https://www.shadertoy.com/view/fcVGzD
// License: CC BY-NC-SA 3.0
// Uniforms: u_resolution, u_time, brightness, u_camForward, u_camRightScaled, u_camUpScaled

uniform vec2 u_resolution;
uniform float u_time;
uniform float brightness;

uniform vec3 u_camForward;
uniform vec3 u_camRightScaled;
uniform vec3 u_camUpScaled;

in vec2 uv;
out vec4 fragColor;

#define M(a, s) mat3(cos(a)*(s), 0.0, cos((a)-33.0)*(s), 0.0, (s), 0.0, cos((a)-11.0)*(s), 0.0, cos(a)*(s))

const mat3 M0 = M(2.0, 2.0);
const mat3 M1 = M(4.0, 4.0);
const mat3 M2 = M(8.0, 8.0);
const mat3 M3 = M(16.0, 16.0);
const mat3 M4 = M(32.0, 32.0);
const mat3 M5 = M(64.0, 64.0);
const mat3 M6 = M(128.0, 128.0);
const mat3 M7 = M(256.0, 256.0);

const float C0 = 0.1666666666666667;
const float C1 = -0.0583333333333333;
const float C2 = 0.0204166666666667;
const float C3 = -0.0071458333333333;
const float C4 = 0.0025010416666667;
const float C5 = -0.0008753645833333;
const float C6 = 0.0003063776041667;
const float C7 = -0.0001072321614583;

void main()
{
    vec2 fragCoord = uv * u_resolution;
    vec2 p2 = (2.0 * fragCoord - u_resolution) / u_resolution.y;
    vec3 rd = normalize(u_camForward + p2.x * u_camRightScaled + p2.y * u_camUpScaled);
    vec3 ro = vec3(0.0, 0.0, u_time * 2.0);

    vec3 o = vec3(0.0);
    float i = 0.0, g = 0.0, d = 1.0;

    vec3 t3 = vec3(u_time);
    vec3 P = vec3(0.0);
    float lenPxy = 0.0;

    const vec3 c_offset = vec3(2.0, 1.0, 0.0);
    const float c_scale = 0.0052631578947368;
    const vec3 v1 = vec3(1.0);

    for(; i < 99.0 && d > 1e-4; i++) {
        o += c_scale + sin(6.0 * lenPxy + g * 2.1 + c_offset) * c_scale;

        g += d * 0.5;
        P = ro + g * rd;

        lenPxy = length(P.xy);
        float pz3 = P.z * 0.3;
        d = 1.1 - length(P.xy - vec2(sin(pz3), cos(pz3)) * 0.3);

        d -= abs(dot(sin(M0 * P - t3), v1)) * C0;
        d -= abs(dot(sin(M1 * P - t3), v1)) * C1;
        d -= abs(dot(sin(M2 * P - t3), v1)) * C2;
        d -= abs(dot(sin(M3 * P - t3), v1)) * C3;
        d -= abs(dot(sin(M4 * P - t3), v1)) * C4;
        d -= abs(dot(sin(M5 * P - t3), v1)) * C5;
        d -= abs(dot(sin(M6 * P - t3), v1)) * C6;
        d -= abs(dot(sin(M7 * P - t3), v1)) * C7;
    }

    o += 19.0 / i;

    float distScale = pow(dot(fragCoord, fragCoord), 0.14);
    const vec3 finalMult = vec3(0.0233333333333333, 0.035, 0.07);

    o = (finalMult * distScale) / tanh(o * o);
    fragColor = vec4(o * brightness, 1.0);
}
