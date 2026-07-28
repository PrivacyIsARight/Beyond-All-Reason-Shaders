local version = "1.0 Black Hole Skybox"

function widget:GetInfo()
   return {
      name      = "Black Hole Skybox",
      desc      = "Shader by erpprog",
      author    = "vexalous",
      date      = "2026",
      license   = "CC BY-NC-SA 4.0",
      layer     = -10001,
      enabled   = true
   }
end

local ELMOS_PER_RS = 3000.0
local BH_BASE_X = 50
local BH_BASE_Y = -10
local BH_BASE_Z = 50

local C_THEME = { brightness = 1.0 }
local SPIN_RADIUS = math.abs(0.997114514 * 0.5)

local isInitialized = false
local shader, fullTexQuad, currVsx, currVsy
local skyDebugWarned = false
local startClock = 0
local universeSign = 1.0
local prevRelPos = nil

local skyVs = [[
#version 430
const vec2 vertices[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));
out vec2 uv;
void main() {
    gl_Position = vec4(vertices[gl_VertexID], 0.99999, 1.0);
    uv = vertices[gl_VertexID] * 0.5 + 0.5;
}
]]

local skyFs = [[
#version 430

uniform float u_time;
uniform float brightness;
uniform vec3 u_camPos_Rs;
uniform vec3 u_camForward;
uniform vec3 u_camRight;
uniform vec3 u_camUp;
uniform float u_tanHalfFov;
uniform float u_universeSign;
uniform vec2 u_resolution;

in vec2 uv;
out vec4 fragColor;

#define iTime u_time
#define iResolution u_resolution
#define iQuality 1.0
#define iBlackHoleTime (2.0*iTime)
#define iBlackHoleMassSol (1e7)
#define iSpin 0.997114514
#define iQ 0.0
#define iMu 1.0
#define iAccretionRate (5e-4)
#define iBackShiftMax 2.0
#define iInterRadiusRs 2.0
#define iOuterRadiusRs 20.0
#define iThinRs 0.75
#define iHopper 0.24
#define iBrightmut 1.0
#define iDarkmut 0.5
#define iReddening 0.3
#define iSaturation 0.5
#define iBlackbodyIntensityExponent 0.5
#define iRedShiftColorExponent 3.0
#define iRedShiftIntensityExponent 4.0
#define iBackgroundBrightmut 1.0
#define iPhotonRingBoost 7.0
#define iPhotonRingColorTempBoost 2.0
#define iBoostRot 0.75
#define iJetRedShiftIntensityExponent 2.0
#define iJetBrightmut 1.0
#define iJetSaturation 0.0
#define iJetShiftMax 3.0

const float kPi = 3.1415926535897932384626433832795;
const float k2Pi = 6.283185307179586476925286766559;
const float CONST_M = 0.5;
const float EPSILON = 1e-6;

float RandomStep(vec2 Input, float Seed) { return fract(sin(dot(Input + fract(11.4514 * sin(Seed)), vec2(12.9898, 78.233))) * 43758.5453); }
float CubicInterpolate(float x) { return x * x * (3.0 - 2.0 * x); }
float PerlinNoise(vec3 Position) {
    vec3 PosInt = floor(Position); vec3 PosFloat = fract(Position);
    float Sx = CubicInterpolate(PosFloat.x); float Sy = CubicInterpolate(PosFloat.y); float Sz = CubicInterpolate(PosFloat.z);
    float v000 = 2.0 * fract(sin(dot(vec3(PosInt.x, PosInt.y, PosInt.z), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    float v100 = 2.0 * fract(sin(dot(vec3(PosInt.x + 1.0, PosInt.y, PosInt.z), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    float v010 = 2.0 * fract(sin(dot(vec3(PosInt.x, PosInt.y + 1.0, PosInt.z), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    float v110 = 2.0 * fract(sin(dot(vec3(PosInt.x + 1.0, PosInt.y + 1.0, PosInt.z), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    float v001 = 2.0 * fract(sin(dot(vec3(PosInt.x, PosInt.y, PosInt.z + 1.0), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    float v101 = 2.0 * fract(sin(dot(vec3(PosInt.x + 1.0, PosInt.y, PosInt.z + 1.0), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    float v011 = 2.0 * fract(sin(dot(vec3(PosInt.x, PosInt.y + 1.0, PosInt.z + 1.0), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    float v111 = 2.0 * fract(sin(dot(vec3(PosInt.x + 1.0, PosInt.y + 1.0, PosInt.z + 1.0), vec3(12.9898, 78.233, 213.765))) * 43758.5453) - 1.0;
    return mix(mix(mix(v000, v100, Sx), mix(v010, v110, Sx), Sy), mix(mix(v001, v101, Sx), mix(v011, v111, Sx), Sy), Sz);
}
float SoftSaturate(float x) { return 1.0 - 1.0 / (max(x, 0.0) + 1.0); }
float PerlinNoise1D(float Position) {
    float PosInt = floor(Position); float PosFloat = fract(Position);
    float v0 = 2.0 * fract(sin(PosInt * 12.9898) * 43758.5453) - 1.0;
    float v1 = 2.0 * fract(sin((PosInt + 1.0) * 12.9898) * 43758.5453) - 1.0;
    return v1 * CubicInterpolate(PosFloat) + v0 * CubicInterpolate(1.0 - PosFloat);
}
float GenerateAccretionDiskNoise(vec3 Position, float NoiseStartLevel, float NoiseEndLevel, float ContrastLevel) {
    float NoiseAccumulator = 10.0;
    int iStart = int(floor(NoiseStartLevel)); int iEnd = int(ceil(NoiseEndLevel));
    for (int delta = 0; delta < 20; delta++) {
        if (delta >= (iEnd - iStart)) break;
        int i = iStart + delta; float iFloat = float(i);
        float w = max(0.0, min(NoiseEndLevel, iFloat + 1.0) - max(NoiseStartLevel, iFloat));
        if (w <= 0.0) continue;
        float noise = PerlinNoise(pow(3.0, iFloat) * Position);
        NoiseAccumulator *= (1.0 + 0.1 * noise * w);
    }
    return log(1.0 + pow(0.1 * NoiseAccumulator, ContrastLevel));
}
float Vec2ToTheta(vec2 v1, vec2 v2) {
    float VecDot = dot(v1, v2); float VecCross = v1.x * v2.y - v1.y * v2.x;
    float Angle = asin(0.999999 * VecCross / max(1e-9, length(v1) * length(v2)));
    float Dx = step(0.0, VecDot); float Cx = step(0.0, VecCross);
    return mix(mix(-kPi - Angle, kPi - Angle, Cx), Angle, Dx);
}
float Shape(float x, float Alpha, float Beta) {
    float k = pow(Alpha + Beta, Alpha + Beta) / (pow(Alpha, Alpha) * pow(Beta, Beta));
    return k * pow(x, Alpha) * pow(1.0 - x, Beta);
}

vec4 hash43x(vec3 p) {
    uvec3 x = uvec3(ivec3(p));
    x = 1103515245U*((x.xyz >> 1U)^(x.yzx));
    uint h = 1103515245U*((x.x^x.z)^(x.y>>3U));
    uvec4 rz = uvec4(h, h*16807U, h*48271U, h*69621U);
    return vec4((rz >> 1) & uvec4(0x7fffffffU))/float(0x7fffffff);
}

vec3 stars(vec3 p) {
    vec3 col = vec3(0);
    float rad = 0.087 * iResolution.y;
    float dens = 0.15; float id = 0.0; float z = 1.0;
    const mat3 rot = mat3(0.86564, -0.28535, 0.41140, 0.50033, 0.46255, -0.73193, 0.01856, 0.83942, 0.54317);
    for (float i = 0.0; i < 5.0; i++) {
        p *= rot;
        vec3 q = abs(p); vec3 p2 = p/max(q.x, max(q.y,q.z)); p2 *= rad;
        vec3 ip = floor(p2 + 1e-5); vec3 fp = fract(p2 + 1e-5);
        vec4 rand = hash43x(ip*283.1); vec3 q2 = abs(p2);
        vec3 pl = 1.0- step(max(q2.x, max(q2.y, q2.z)), q2);
        vec3 pp = fp - ((rand.xyz-0.5)*0.6 + 0.5)*pl;
        float pr = length(ip) - rad;
        if (rand.w > (dens - dens*pr*0.035)) pp += 1e6;
        float d = dot(pp, pp) / max(0.25, (pow(fract(rand.w*172.1), 32.0) + 0.25));
        float bri = dot(rand.xyz*(1.0-pl),vec3(1.0));
        id = fract(rand.w*101.0);
        col += bri*z*0.00009/pow(d + 0.025, 3.0)*(mix(vec3(1.0,0.45,0.1),vec3(0.75,0.85,1.0), id)*0.6+0.4);
        rad = floor(rad*1.08); dens *= 1.45; z *= 0.6; p = p.yxz;
    }
    return col;
}

vec3 KelvinToRgb(float Kelvin) {
    if (Kelvin < 400.01) return vec3(0.0);
    float Teff = (Kelvin - 6500.0) / (6500.0 * Kelvin * 2.2);
    vec3 RgbColor = vec3(exp(2.05539304e4 * Teff), exp(2.63463675e4 * Teff), exp(3.30145739e4 * Teff));
    float BrightnessScale = 1.0 / max(max(1.5 * RgbColor.r, RgbColor.g), max(RgbColor.b, 1e-6));
    if (Kelvin < 1000.0) BrightnessScale *= (Kelvin - 400.0) / 600.0;
    return RgbColor * BrightnessScale;
}

vec3 WavelengthToRgb(float wavelength) {
    vec3 color = vec3(0.0);
    if (wavelength <= 380.0 ) { color.r = 1.0; color.g = 0.0; color.b = 1.0; }
    else if (wavelength < 440.0) { color.r = -(wavelength - 440.0) / 60.0; color.g = 0.0; color.b = 1.0; }
    else if (wavelength < 490.0) { color.r = 0.0; color.g = (wavelength - 440.0) / 50.0; color.b = 1.0; }
    else if (wavelength < 510.0) { color.r = 0.0; color.g = 1.0; color.b = -(wavelength - 510.0) / 20.0; }
    else if (wavelength < 580.0) { color.r = (wavelength - 510.0) / 70.0; color.g = 1.0; color.b = 0.0; }
    else if (wavelength < 645.0) { color.r = 1.0; color.g = -(wavelength - 645.0) / 65.0; color.b = 0.0; }
    else { color.r = 1.0; color.g = 0.0; color.b = 0.0; }

    float factor = 0.3;
    if (wavelength >= 380.0 && wavelength < 420.0) factor = 0.3 + 0.7 * (wavelength - 380.0) / 40.0;
    else if (wavelength >= 420.0 && wavelength < 645.0) factor = 1.0;
    else if (wavelength >= 645.0 && wavelength <= 750.0) factor = 0.3 + 0.7 * (750.0 - wavelength) / 105.0;
    return color * factor / pow(color.r * color.r + 2.25 * color.g * color.g + 0.36 * color.b * color.b, 0.5) * (0.1 * (color.r + color.g + color.b) + 0.9);
}

vec4 SampleBackground(vec3 Dir, float Shift, float Status) {
    vec4 Backcolor = vec4(stars(Dir), 1.0);
    vec3 Rcolor = Backcolor.r * 1.0 * WavelengthToRgb(max(453.0, 645.0 / Shift));
    vec3 Gcolor = Backcolor.g * 1.5 * WavelengthToRgb(max(416.0, 510.0 / Shift));
    vec3 Bcolor = Backcolor.b * 0.6 * WavelengthToRgb(max(380.0, 440.0 / Shift));
    vec3 Scolor = Rcolor + Gcolor + Bcolor;
    float OStrength = 0.3 * Backcolor.r + 0.6 * Backcolor.g + 0.1 * Backcolor.b;
    float RStrength = 0.3 * Scolor.r + 0.6 * Scolor.g + 0.1 * Scolor.b;
    Scolor *= OStrength / max(RStrength, 0.001);
    return iBackgroundBrightmut * vec4(Scolor, Backcolor.a) * pow(Shift, 4.0);
}

vec4 ApplyToneMapping(vec4 Result,float shift) {
    float sum = Result.r + Result.g + Result.b + 1e-6;
    float invSum = 3.0 / sum;
    float RedFactor = Result.r * invSum;
    float GreenFactor = Result.g * invSum;
    float BlueFactor = Result.b * invSum;
    float BloomMax = max(8.0, shift) + log(max(shift - 7.0, 1.0));
    vec4 Mapped;
    Mapped.r = min(-4.0 * log(1.0 - pow(clamp(Result.r, 0.0, 0.999), 2.2)), BloomMax * RedFactor);
    Mapped.g = min(-4.0 * log(1.0 - pow(clamp(Result.g, 0.0, 0.999), 2.2)), BloomMax * GreenFactor);
    Mapped.b = min(-4.0 * log(1.0 - pow(clamp(Result.b, 0.0, 0.999), 2.2)), BloomMax * BlueFactor);
    Mapped.rgb = max(Mapped.rgb, Result.rgb);
    Mapped.a = 1.0;
    return Mapped;
}

float GetKeplerianAngularVelocity(float Radius, float Rs, float PhysicalSpinA, float PhysicalQ) {
    float M = 0.5 * Rs;
    float Mr_minus_Q2 = M * Radius - PhysicalQ * PhysicalQ;
    if (Mr_minus_Q2 < 0.0) return 0.0;
    float sqrt_Term = sqrt(Mr_minus_Q2);
    float denominator = Radius * Radius + PhysicalSpinA * sqrt_Term;
    return sqrt_Term / max(EPSILON, denominator);
}

float KerrSchildRadius(vec3 p, float PhysicalSpinA, float r_sign) {
    float r_sign_len = r_sign * length(p);
    if (PhysicalSpinA == 0.0) return r_sign_len;
    float a2 = PhysicalSpinA * PhysicalSpinA;
    float b = dot(p, p) - a2;
    float y2 = p.y * p.y;
    float det = sqrt(b * b + 4.0 * a2 * y2);
    float r2 = (b >= 0.0) ? 0.5 * (b + det) : (2.0 * a2 * y2) / max(1e-20, det - b);
    return r_sign * sqrt(r2);
}

struct KerrGeometry {
    float r; float r2; float a2; float f;
    vec3 grad_r; vec3 grad_f;
    vec4 l_up; vec4 l_down;
    float inv_r2_a2; float inv_den_f; float num_f;
};

void ComputeGeometryScalars(vec3 X, float PhysicalSpinA, float PhysicalQ, float fade, float r_sign, bool isOutgoing, out KerrGeometry geo) {
    geo.a2 = PhysicalSpinA * PhysicalSpinA;
    float dirSign = isOutgoing ? -1.0 : 1.0;
    if (PhysicalSpinA == 0.0) {
        geo.r = r_sign * length(X);
        geo.r2 = geo.r * geo.r;
        float inv_r = 1.0 / max(1e-9, geo.r);
        float inv_r2 = inv_r * inv_r;
        geo.l_up = vec4(dirSign * X * inv_r, -1.0);
        geo.l_down = vec4(dirSign * X * inv_r, 1.0);
        geo.num_f = (2.0 * CONST_M * geo.r - PhysicalQ * PhysicalQ);
        geo.f = (2.0 * CONST_M * inv_r - (PhysicalQ * PhysicalQ) * inv_r2) * fade;
        geo.inv_r2_a2 = inv_r2;
        geo.inv_den_f = inv_r2 * inv_r2;
        return;
    }
    geo.r = KerrSchildRadius(X, PhysicalSpinA, r_sign);
    geo.r2 = geo.r * geo.r;
    float r3 = geo.r2 * geo.r;
    float z_coord = X.y; float z2 = z_coord * z_coord;
    geo.inv_r2_a2 = 1.0 / max(1e-9, geo.r2 + geo.a2);

    float lx = (dirSign * geo.r * X.x - PhysicalSpinA * X.z) * geo.inv_r2_a2;
    float ly = (dirSign * X.y) / max(1e-9, geo.r);
    float lz = (dirSign * geo.r * X.z + PhysicalSpinA * X.x) * geo.inv_r2_a2;

    geo.l_up = vec4(lx, ly, lz, -1.0);
    geo.l_down = vec4(lx, ly, lz, 1.0);
    geo.num_f = 2.0 * CONST_M * r3 - PhysicalQ * PhysicalQ * geo.r2;
    float den_f = geo.r2 * geo.r2 + geo.a2 * z2;
    geo.inv_den_f = 1.0 / max(1e-20, den_f);
    geo.f = (geo.num_f * geo.inv_den_f) * fade;
}

void ComputeGeometryGradients(vec3 X, float PhysicalSpinA, float PhysicalQ, float fade, inout KerrGeometry geo) {
    if (PhysicalSpinA == 0.0) {
        float inv_r = 1.0 / max(1e-9, geo.r); float inv_r2 = inv_r * inv_r;
        geo.grad_r = X * inv_r;
        float df_dr = (-2.0 * CONST_M + 2.0 * PhysicalQ * PhysicalQ * inv_r) * inv_r2 * fade;
        geo.grad_f = df_dr * geo.grad_r;
        return;
    }
    float inv_denom_grad = geo.r * geo.inv_den_f;
    geo.grad_r = vec3(X.x * geo.r2, X.y * (geo.r2 + geo.a2), X.z * geo.r2) * inv_denom_grad;
    float z_coord = X.y; float z2 = z_coord * z_coord;
    float term_M = -2.0 * CONST_M * geo.r2 * geo.r2 * geo.r;
    float term_Q = 2.0 * PhysicalQ * PhysicalQ * geo.r2 * geo.r2;
    float term_Ma = 6.0 * CONST_M * geo.a2 * geo.r * z2;
    float term_Qa = -2.0 * PhysicalQ * PhysicalQ * geo.a2 * z2;
    float df_dr_num_reduced = term_M + term_Q + term_Ma + term_Qa;
    float df_dr = (geo.r * df_dr_num_reduced) * (geo.inv_den_f * geo.inv_den_f);
    float df_dy = -(geo.num_f * 2.0 * geo.a2 * z_coord) * (geo.inv_den_f * geo.inv_den_f);
    geo.grad_f = df_dr * geo.grad_r; geo.grad_f.y += df_dy; geo.grad_f *= fade;
}

vec4 RaiseIndex(vec4 P_cov, KerrGeometry geo) {
    vec4 P_flat = vec4(P_cov.xyz, -P_cov.w);
    float L_dot_P = dot(geo.l_up, P_cov);
    return P_flat - geo.f * L_dot_P * geo.l_up;
}
vec4 LowerIndex(vec4 P_contra, KerrGeometry geo) {
    vec4 P_flat = vec4(P_contra.xyz, -P_contra.w);
    float L_dot_P = dot(geo.l_down, P_contra);
    return P_flat + geo.f * L_dot_P * geo.l_down;
}

vec4 GetInitialMomentum(vec3 RayDir, vec4 X, float universesign, float PhysicalSpinA, float PhysicalQ, float GravityFade, bool isOutgoing) {
    KerrGeometry geo;
    ComputeGeometryScalars(X.xyz, PhysicalSpinA, PhysicalQ, GravityFade, universesign, isOutgoing, geo);
    float g_tt = -1.0 + geo.f;
    float time_comp = 1.0 / sqrt(max(1e-9, -g_tt));
    vec4 U_up = vec4(0.0, 0.0, 0.0, time_comp);

    vec4 U_down = LowerIndex(U_up, geo);
    vec3 m_r = -normalize(X.xyz);
    vec3 WorldUp = vec3(0.0, 1.0, 0.0);
    if (abs(dot(m_r, WorldUp)) > 0.999) WorldUp = vec3(1.0, 0.0, 0.0);
    vec3 m_phi = normalize(cross(WorldUp, m_r));
    vec3 m_theta = cross(m_phi, m_r);
    float k_r = dot(RayDir, m_r); float k_theta = dot(RayDir, m_theta); float k_phi = dot(RayDir, m_phi);

    vec4 e1 = vec4(m_r, 0.0); e1 += dot(e1, U_down) * U_up; vec4 e1_d = LowerIndex(e1, geo);
    float n1 = sqrt(max(1e-9, dot(e1, e1_d))); e1 /= n1; e1_d /= n1;

    vec4 e2 = vec4(m_theta, 0.0); e2 += dot(e2, U_down) * U_up; e2 -= dot(e2, e1_d) * e1; vec4 e2_d = LowerIndex(e2, geo);
    float n2 = sqrt(max(1e-9, dot(e2, e2_d))); e2 /= n2; e2_d /= n2;

    vec4 e3 = vec4(m_phi, 0.0); e3 += dot(e3, U_down) * U_up; e3 -= dot(e3, e1_d) * e1; e3 -= dot(e3, e2_d) * e2; vec4 e3_d = LowerIndex(e3, geo);
    float n3 = sqrt(max(1e-9, dot(e3, e3_d))); e3 /= n3;

    vec4 P_up = U_up - (k_r * e1 + k_theta * e2 + k_phi * e3);
    return LowerIndex(P_up, geo);
}

void transformKerrSchild_YSpin(inout vec4 X, in float r_sign, inout vec4 P, float M, float a, float Q, bool out_to_in) {
    float x = X.x, y = X.y, z = X.z, t = X.w;
    float px = P.x, py = P.y, pz = P.z, pt = P.w;
    float a2 = a * a; float M2 = M * M; float Q2 = Q * Q;

    float R2 = dot(X.xyz, X.xyz); float u = R2 - a2; float v = 4.0 * a2 * y * y;
    float r2 = (u >= 0.0) ? 0.5 * (u + sqrt(u*u + v)) : 0.5 * v / max(1e-20, sqrt(u*u + v) - u);
    float r = r_sign * sqrt(max(r2, 0.0));

    float Delta = r*r - 2.0*M*r + a2 + Q2;
    float safe_Delta = sign(Delta) * max(abs(Delta), 1e-16); if (safe_Delta == 0.0) safe_Delta = 1e-16;

    float r3 = r * r * r; float D = r3 * r + a2 * y * y; float safe_D = max(D, 1e-12);
    vec3 grad_r = vec3(r3 * x / safe_D, r * (r*r + a2) * y / safe_D, r3 * z / safe_D);

    float delta_disc = M2 - a2 - Q2; float F_r = 0.0; float g_r = 0.0; float abs_Delta_safe = max(abs(Delta), 1e-16);

    if (delta_disc > 1e-16) {
        float K = sqrt(delta_disc); float r_plus = M + K; float r_minus = M - K;
        float frac = abs(r - r_plus) / max(abs(r - r_minus), 1e-16);
        F_r = 2.0 * M * log(abs_Delta_safe) + ((2.0 * M2 - Q2) / K) * log(max(frac, 1e-16));
        g_r = (a / K) * log(max(frac, 1e-16));
    } else if (delta_disc < -1e-16) {
        float K = sqrt(-delta_disc); float atan_arg = atan((r - M) / K);
        F_r = 2.0 * M * log(abs_Delta_safe) + (2.0 * (2.0 * M2 - Q2) / K) * atan_arg;
        g_r = (2.0 * a / K) * atan_arg;
    } else {
        float rM = r - M; float safe_rM = sign(rM) * max(abs(rM), 1e-16); if (safe_rM == 0.0) safe_rM = 1e-16;
        F_r = 4.0 * M * log(max(abs(rM), 1e-16)) - 2.0 * (2.0 * M2 - Q2) / safe_rM;
        g_r = -2.0 * a / safe_rM;
    }
    g_r += 2.0 * atan(a, max(1e-9, r));

    float F_prime = 2.0 * (2.0 * M * r - Q2) / safe_Delta;
    float g_prime = 2.0 * a / safe_Delta - 2.0 * a / max(1e-9, (r * r + a * a));
    float Ly = z * px - x * pz;
    float K_p = F_prime * pt + g_prime * Ly;
    float dir = out_to_in ? -1.0 : 1.0;

    float angle = -dir * g_r; float time_shift = -dir * F_r;
    vec3 P_tilde = vec3(px, py, pz) + dir * grad_r * K_p;

    float cos_a = cos(angle); float sin_a = sin(angle);
    X.x = x * cos_a + z * sin_a; X.y = y; X.z = z * cos_a - x * sin_a; X.w = t + time_shift;
    P.x = P_tilde.z * sin_a + P_tilde.x * cos_a; P.y = P_tilde.y; P.z = - P_tilde.x * sin_a + P_tilde.z * cos_a; P.w = pt;
}

struct State { vec4 X; vec4 P; };

void ApplyHamiltonianCorrection(inout vec4 P, vec4 X, float E, KerrGeometry geo) {
    P.w = -E; vec3 p = P.xyz;
    float L_dot_p_s = dot(geo.l_up.xyz, p); float Pt = P.w;
    float p2 = dot(p, p);
    float Coeff_A = p2 - geo.f * L_dot_p_s * L_dot_p_s;
    float Coeff_B = 2.0 * geo.f * L_dot_p_s * Pt;
    float Coeff_C = -Pt * Pt * (1.0 + geo.f);
    float disc = Coeff_B * Coeff_B - 4.0 * Coeff_A * Coeff_C;
    if (disc >= 0.0) {
        float sqrtDisc = sqrt(disc); float denom = 2.0 * Coeff_A;
        if (abs(denom) > 1e-9) {
            float k1 = (-Coeff_B + sqrtDisc) / denom; float k2 = (-Coeff_B - sqrtDisc) / denom;
            float k = (abs(k1 - 1.0) < abs(k2 - 1.0)) ? k1 : k2;
            P.xyz *= mix(k, 1.0, clamp(abs(k - 1.0) / 0.1 - 1.0, 0.0, 1.0));
        }
    }
}

State GetDerivativesAnalytic(State S, float PhysicalSpinA, float PhysicalQ, float fade, bool isOutgoing, inout KerrGeometry geo) {
    State deriv;
    ComputeGeometryGradients(S.X.xyz, PhysicalSpinA, PhysicalQ, fade, geo);
    float l_dot_P = dot(geo.l_up.xyz, S.P.xyz) + geo.l_up.w * S.P.w;
    deriv.X = RaiseIndex(S.P, geo);
    vec3 grad_A = (-2.0 * geo.r * geo.inv_r2_a2) * geo.inv_r2_a2 * geo.grad_r;
    float dirSign = isOutgoing ? -1.0 : 1.0;
    float rx_az = dirSign * geo.r * S.X.x - PhysicalSpinA * S.X.z;
    float rz_ax = dirSign * geo.r * S.X.z + PhysicalSpinA * S.X.x;
    vec3 d_num_lx = dirSign * S.X.x * geo.grad_r; d_num_lx.x += dirSign * geo.r; d_num_lx.z -= PhysicalSpinA;
    vec3 grad_lx = geo.inv_r2_a2 * d_num_lx + rx_az * grad_A;
    vec3 grad_ly = dirSign * (geo.r * geo.inv_den_f) * vec3(-S.X.x * S.X.y, geo.r2 - S.X.y * S.X.y, -S.X.z * S.X.y);
    vec3 d_num_lz = dirSign * S.X.z * geo.grad_r; d_num_lz.z += dirSign * geo.r; d_num_lz.x += PhysicalSpinA;
    vec3 grad_lz = geo.inv_r2_a2 * d_num_lz + rz_ax * grad_A;
    vec3 P_dot_grad_l = S.P.x * grad_lx + S.P.y * grad_ly + S.P.z * grad_lz;
    vec3 Force = 0.5 * ( (l_dot_P * l_dot_P) * geo.grad_f + (2.0 * geo.f * l_dot_P) * P_dot_grad_l );
    deriv.P = vec4(Force, 0.0);
    return deriv;
}

float GetIntermediateSign(vec4 StartX, vec4 CurrentX, float CurrentSign, float PhysicalSpinA) {
    if (StartX.y * CurrentX.y < 0.0) {
        float t = StartX.y / max(1e-9, (StartX.y - CurrentX.y));
        if (length(mix(StartX.xz, CurrentX.xz, t)) < abs(PhysicalSpinA)) return -CurrentSign;
    }
    return CurrentSign;
}

void StepGeodesicRK4_Optimized(inout vec4 X, inout vec4 P, float E, float dt, float PhysicalSpinA, float PhysicalQ, float fade, float r_sign, bool isOutgoing, KerrGeometry geo0, State k1, out KerrGeometry geoFinal) {
    State s0; s0.X = X; s0.P = P;
    State s1; s1.X = s0.X + 0.5 * dt * k1.X; s1.P = s0.P + 0.5 * dt * k1.P;
    float sign1 = GetIntermediateSign(s0.X, s1.X, r_sign, PhysicalSpinA);
    KerrGeometry geo1; ComputeGeometryScalars(s1.X.xyz, PhysicalSpinA, PhysicalQ, fade, sign1, isOutgoing, geo1);
    State k2 = GetDerivativesAnalytic(s1, PhysicalSpinA, PhysicalQ, fade, isOutgoing, geo1);

    State s2; s2.X = s0.X + 0.5 * dt * k2.X; s2.P = s0.P + 0.5 * dt * k2.P;
    float sign2 = GetIntermediateSign(s0.X, s2.X, r_sign, PhysicalSpinA);
    KerrGeometry geo2; ComputeGeometryScalars(s2.X.xyz, PhysicalSpinA, PhysicalQ, fade, sign2, isOutgoing, geo2);
    State k3 = GetDerivativesAnalytic(s2, PhysicalSpinA, PhysicalQ, fade, isOutgoing, geo2);

    State s3; s3.X = s0.X + dt * k3.X; s3.P = s0.P + dt * k3.P;
    float sign3 = GetIntermediateSign(s0.X, s3.X, r_sign, PhysicalSpinA);
    KerrGeometry geo3; ComputeGeometryScalars(s3.X.xyz, PhysicalSpinA, PhysicalQ, fade, sign3, isOutgoing, geo3);
    State k4 = GetDerivativesAnalytic(s3, PhysicalSpinA, PhysicalQ, fade, isOutgoing, geo3);

    vec4 finalX = s0.X + (dt / 6.0) * (k1.X + 2.0 * k2.X + 2.0 * k3.X + k4.X);
    vec4 finalP = s0.P + (dt / 6.0) * (k1.P + 2.0 * k2.P + 2.0 * k3.P + k4.P);

    float finalSign = GetIntermediateSign(s0.X, finalX, r_sign, PhysicalSpinA);
    ComputeGeometryScalars(finalX.xyz, PhysicalSpinA, PhysicalQ, fade, finalSign, isOutgoing, geoFinal);
    if(finalSign > 0.0) ApplyHamiltonianCorrection(finalP, finalX, E, geoFinal);
    X = finalX; P = finalP;
}

float ComputeStepSize(float DistanceToBlackHole, float OuterRadius) {
    float ssb = max(OuterRadius, 12.0);
    float ssb2 = 2.0 * ssb;
    float stepFactor = 0.15 + 0.25 * clamp(0.5 * (0.5 * DistanceToBlackHole / max(10.0, ssb) - 1.0), 0.0, 1.0);
    float sz = 1.0;
    if (DistanceToBlackHole >= ssb2) {
        sz = stepFactor * DistanceToBlackHole;
    } else if (DistanceToBlackHole >= ssb) {
        float t = 1.0 + 0.25 * max(DistanceToBlackHole - 12.0, 0.0);
        sz = stepFactor * (t * (ssb2 - DistanceToBlackHole) + DistanceToBlackHole * (DistanceToBlackHole - ssb)) / ssb;
    } else {
        sz = stepFactor * min(1.0 + 0.25 * max(DistanceToBlackHole - 12.0, 0.0), DistanceToBlackHole);
    }
    return max(0.01, sz);
}

vec4 DiskColor(vec4 BaseColor, vec4 RayPos, vec4 LastRayPos, vec4 iP_cov, vec4 lastiP_cov, float iE_obs,
               float InterRadius, float OuterRadius, float Thin, float Hopper, float Brightmut, float Darkmut, float Reddening, float Saturation, float DiskTemperatureArgument,
               float BlackbodyIntensityExponent, float RedShiftColorExponent, float RedShiftIntensityExponent,
               float PeakTemperature, float ShiftMax, float PhysicalSpinA, float PhysicalQ, bool isoutgoing,
               float ThetaInShell, inout float RayMarchPhase)
{
    vec4 CurrentResult = BaseColor;
    float MaxDiskHalfHeight = Thin + max(0.0, Hopper * OuterRadius) + 2.0;
    if ((LastRayPos.y > MaxDiskHalfHeight && RayPos.y > MaxDiskHalfHeight) || (LastRayPos.y < -MaxDiskHalfHeight && RayPos.y < -MaxDiskHalfHeight)) return BaseColor;

    vec2 P0 = LastRayPos.xz; vec2 P1 = RayPos.xz; vec2 V = P1 - P0; float LenSq = dot(V, V);
    vec2 ClosestPoint = P0 + V * ((LenSq > 1e-8) ? clamp(-dot(P0, V) / LenSq, 0.0, 1.0) : 0.0);
    if (dot(ClosestPoint, ClosestPoint) > (OuterRadius * 1.1) * (OuterRadius * 1.1)) return BaseColor;

    vec3 StartPos = LastRayPos.xyz; vec3 EndPos = RayPos.xyz; vec3 ChordDelta = EndPos - StartPos;
    vec3 MidPos = 0.5 * (StartPos + EndPos);
    KerrGeometry geo_mid; ComputeGeometryScalars(MidPos, PhysicalSpinA, PhysicalQ, 1.0, 1.0, isoutgoing, geo_mid);
    float proper_dist = sqrt(max(1e-9, dot(ChordDelta, ChordDelta) + geo_mid.f * pow(dot(geo_mid.l_down.xyz, ChordDelta), 2.0)));
    if (max(KerrSchildRadius(StartPos, PhysicalSpinA, 1.0), KerrSchildRadius(EndPos, PhysicalSpinA, 1.0)) < InterRadius * 0.9) return BaseColor;

    float TotalDist = proper_dist; float TraveledDist = 0.0;

    float aR = 1.0; float aG = 1.0 + Reddening * 2.0; float aB = 1.0 + Reddening * 5.0;
    float a_param = max(1.0, (OuterRadius - InterRadius) / 10.0);
    float denom = 2.0 * a_param - 2.0;
    float safeDenom = abs(denom) < 1e-5 ? 1.0 : denom;
    bool useX = abs(denom) < 1e-5;
    float outRad07 = 0.02 * pow(OuterRadius, 0.7);

    for (int SafetyLoopCount = 0; SafetyLoopCount < 1000; SafetyLoopCount++) {
        if (CurrentResult.a > 0.99 || TraveledDist >= TotalDist) break;

        vec3 CurrentPos = mix(StartPos, EndPos, clamp(TraveledDist / max(1e-9, TotalDist), 0.0, 1.0));
        float DistanceToBlackHole = length(CurrentPos);
        float StepSize = ComputeStepSize(DistanceToBlackHole, OuterRadius);

        float DistToNextSample = RayMarchPhase * StepSize;
        float NextTarget = min(TotalDist, TraveledDist + DistToNextSample);

        bool shouldSample = false;
        if (NextTarget < TotalDist) { shouldSample = true; RayMarchPhase = 1.0; TraveledDist = NextTarget; }
        else { RayMarchPhase = max(0.0, RayMarchPhase - (TotalDist - TraveledDist) / max(1e-9, StepSize)); TraveledDist = TotalDist; }

        if (shouldSample) {
            float TimeInterpolant = min(1.0, TraveledDist / max(1e-9, TotalDist));
            vec4 Sample_X = vec4(mix(StartPos, EndPos, TimeInterpolant), mix(LastRayPos.w, RayPos.w, TimeInterpolant));
            vec4 Sample_P_cov = mix(lastiP_cov, iP_cov, TimeInterpolant);

            if (isoutgoing) transformKerrSchild_YSpin(Sample_X, 1.0, Sample_P_cov, 0.5, PhysicalSpinA, PhysicalQ, true);
            vec3 SamplePos = Sample_X.xyz; float EmissionTime = iBlackHoleTime + Sample_X.w;

            float PosR = KerrSchildRadius(SamplePos, PhysicalSpinA, 1.0); float PosY = SamplePos.y;
            float GeometricThin = Thin + max(0.0, (length(SamplePos.xz) - 3.0) * Hopper);
            float InnerCloudBound = GeometricThin * max(0.0, 1.0 - 5.0 * pow((PosR - InterRadius) / max(1e-9, min(OuterRadius - InterRadius, 12.0)), 2.0));

            if (abs(PosY) < max(GeometricThin * 1.5, max(0.0, InnerCloudBound)) && PosR < OuterRadius && PosR > InterRadius) {
                 float NoiseLevel = max(0.0, 2.0 - 0.6 * GeometricThin);
                 float x = (PosR - InterRadius) / max(1e-6, OuterRadius - InterRadius);
                 float EffectiveRadius = useX ? x : (-1.0 + sqrt(max(0.0, 1.0 + 4.0 * a_param * a_param * x - 4.0 * x * a_param))) / safeDenom;

                 float DenAndThiFactor = Shape(EffectiveRadius, 0.9, 1.5);
                 float ThicknessCap = max(1e-6, GeometricThin * DenAndThiFactor);
                 if (abs(PosY) < max(ThicknessCap, InnerCloudBound)) {
                 KerrGeometry geo_emit; ComputeGeometryScalars(SamplePos, PhysicalSpinA, PhysicalQ, 1.0, 1.0, false, geo_emit);
                 vec3 local_Dir = normalize(RaiseIndex(Sample_P_cov, geo_emit).xyz);

                 float PosLogTheta_ForThick = Vec2ToTheta(SamplePos.zx, vec2(cos(-2.0 * log(max(1e-6, PosR))), sin(-2.0 * log(max(1e-6, PosR)))));
                 float PerturbedThickness = max(1e-6, GeometricThin * DenAndThiFactor * (0.4 + 0.6 * clamp(GeometricThin - 0.5, 0.0, 2.5) / 2.5 + (1.0 - (0.4 + 0.6 * clamp(GeometricThin - 0.5, 0.0, 2.5) / 2.5)) * SoftSaturate(GenerateAccretionDiskNoise(vec3(1.5 * PosLogTheta_ForThick, PosR + 0.0833333 * EmissionTime, 0.0), -0.7 + NoiseLevel, 1.3 + NoiseLevel, 80.0))));

                 if ((abs(PosY) < PerturbedThickness) || (abs(PosY) < InnerCloudBound)) {
                     float AngularVelocity = GetKeplerianAngularVelocity(max(InterRadius, PosR), 1.0, PhysicalSpinA, PhysicalQ);
                     float u = sqrt(max(1e-6, PosR)); float k_cubed = PhysicalSpinA * 0.70710678; float SpiralTheta;
                     if (abs(k_cubed) < 0.001 * u * u * u) {
                         SpiralTheta = -16.9705627 / u * (1.0 - 0.25 * k_cubed * pow(1.0/u, 3.0) + 0.142857 * pow(k_cubed * pow(1.0/u, 3.0), 2.0));
                     } else {
                         float k_cbrt = sign(k_cubed) * pow(abs(k_cubed), 0.33333333);
                         SpiralTheta = (5.6568542 / k_cbrt) * (0.5 * log(max(1e-9, (PosR - k_cbrt*u + k_cbrt*k_cbrt) / max(1e-9, pow(u+k_cbrt, 2.0)))) + 1.7320508 * (atan(2.0*u - k_cbrt, 1.7320508 * k_cbrt) - 1.5707963));
                     }

                     float PosTheta = Vec2ToTheta(SamplePos.zx, vec2(cos(-SpiralTheta), sin(-SpiralTheta)));
                     float PosLogarithmicTheta = PosLogTheta_ForThick;

                     float inv_r = 1.0 / max(1e-6, PosR); float inv_r2 = inv_r * inv_r;
                     float V_pot = inv_r - (PhysicalQ * PhysicalQ) * inv_r2;

                     float g_tt = -(1.0 - V_pot);
                     float g_tphi = -PhysicalSpinA * V_pot;
                     float g_phiphi = PosR * PosR + PhysicalSpinA * PhysicalSpinA + PhysicalSpinA * PhysicalSpinA * V_pot;
                     float norm_metric = g_tt + 2.0 * AngularVelocity * g_tphi + AngularVelocity * AngularVelocity * g_phiphi;

                     float u_t = inversesqrt(max(0.01, -norm_metric));
                     float P_phi = -SamplePos.x * Sample_P_cov.z + SamplePos.z * Sample_P_cov.x;
                     float E_emit = u_t * (iE_obs - AngularVelocity * P_phi);
                     float FreqRatio = 1.0 / max(1e-6, E_emit);
                     float RestTemperature = pow(DiskTemperatureArgument * pow(1.0 / max(1e-6, PosR), 3.0) * max(1.0 - sqrt(InterRadius / max(1e-6, PosR)), 0.000001), 0.25);
                     float VisionTemperature = RestTemperature * pow(FreqRatio, RedShiftColorExponent);
                     float BrightWithoutRedshift = (0.05 * min(OuterRadius / 1000.0, 1000.0 / max(1e-9,OuterRadius)) + 0.55 / exp(5.0 * EffectiveRadius) * mix(0.2 + 0.8 * abs(local_Dir.y), 1.0, clamp(GeometricThin - 0.8, 0.2, 1.0))) * pow(RestTemperature / PeakTemperature, BlackbodyIntensityExponent);

                     float Density = DenAndThiFactor; vec4 SampleColor = vec4(0.0);

                     if (abs(PosY) < PerturbedThickness) {
                         float Levelmut = 0.91 * log(1.0 + 0.065934 * max(0.0, min(1000.0, PosR) - 10.0));
                         float Conmut = 80.0 * log(1.0 + 0.006 * max(0.0, PosR - 10.0));

                         vec3 nBase = vec3(0.1 * (PosR + 0.0833333 * EmissionTime), 0.1 * PosY, outRad07 * PosTheta);
                         float nStart = NoiseLevel + 2.0 - Levelmut;
                         float nEnd = NoiseLevel + 4.0 - Levelmut;
                         float nCont = 80.0 - Conmut;

                         SampleColor = vec4(GenerateAccretionDiskNoise(nBase, nStart, nEnd, nCont));
                         if(PosTheta + kPi < 0.1 * kPi) {
                             float blend = (PosTheta + kPi) / (0.1 * kPi);
                             SampleColor *= blend;
                             nBase.z = outRad07 * (PosTheta + k2Pi);
                             SampleColor += (1.0 - blend) * vec4(GenerateAccretionDiskNoise(nBase, nStart, nEnd, nCont));
                         }

                         if(PosR > max(0.15379 * OuterRadius, 9.84256)) {
                             float TimeShiftedRadiusTerm = PosR * 4.65114e-6 - 0.0333333 * EmissionTime;
                             vec3 sBase = vec3(0.1 * (TimeShiftedRadiusTerm - 0.08 * OuterRadius * PosLogarithmicTheta), 0.1 * PosY, outRad07 * PosLogarithmicTheta);
                             float sEnd = NoiseLevel + 3.0 - Levelmut;
                             float Spir = GenerateAccretionDiskNoise(sBase, nStart, sEnd, nCont);

                             if(PosLogarithmicTheta + kPi < 0.1 * kPi) {
                                 float blend = (PosLogarithmicTheta + kPi) / (0.1 * kPi);
                                 Spir *= blend;
                                 sBase.x = 0.1 * (TimeShiftedRadiusTerm - 0.08 * OuterRadius * (PosLogarithmicTheta + k2Pi));
                                 sBase.z = outRad07 * (PosLogarithmicTheta + k2Pi);
                                 Spir += (1.0 - blend) * GenerateAccretionDiskNoise(sBase, nStart, sEnd, nCont);
                             }
                             SampleColor *= mix(1.0, clamp(1.05 * Spir - 0.5, 0.0, 3.0), 0.5 + 0.5 * max(-1.0, 1.0 - exp(-0.15 * (100.0 * PosR / max(OuterRadius, 64.0) - 20.0))));
                         }
                         Density *= 0.7 * max(0.0, 1.0 - abs(PosY) / PerturbedThickness);
                         SampleColor.xyz *= Density * 1.4 * max(0.0, (0.2 + 2.0 * sqrt(max(0.0, clamp(abs(PosY) / PerturbedThickness, 0.0, 1.0) * clamp(abs(PosY) / PerturbedThickness, 0.0, 1.0) + 0.001))));
                         SampleColor.a *= (Density * Density) / 0.3;
                     }

                     SampleColor.xyz *= 1.0 + clamp(iPhotonRingBoost, 0.0, 10.0) * clamp(0.3 * ThetaInShell - 0.1, 0.0, 1.0);
                     VisionTemperature *= 1.0 + clamp(iPhotonRingColorTempBoost, 0.0, 10.0) * clamp(0.3 * ThetaInShell - 0.1, 0.0, 1.0);

                     if (abs(PosY) < InnerCloudBound) {
                         float DustIntensity = max(1.0 - pow(PosY / max(1e-6, InnerCloudBound), 2.0), 0.0);
                         if (DustIntensity > 0.0) {
                             float InnerCloudTimePhase = max(1e-6, GetKeplerianAngularVelocity(max(3.0, InterRadius), 1.0, PhysicalSpinA, PhysicalQ)) * EmissionTime;
                             float DustNoise = GenerateAccretionDiskNoise(vec3(1.5 * fract((1.5 * Vec2ToTheta(SamplePos.zx, vec2(cos(0.666666 * InnerCloudTimePhase), sin(0.666666 * InnerCloudTimePhase))) + InnerCloudTimePhase) / 2.0 / kPi) * k2Pi, PosR, PosY), 0.0, 6.0, 80.0);
                             SampleColor += 0.02 * vec4(vec3(DustIntensity * DustNoise), 0.2 * DustIntensity * DustNoise) * sqrt(max(0.0, 1.0001 - local_Dir.y * local_Dir.y));
                         }
                     }

                     SampleColor.xyz *= BrightWithoutRedshift * KelvinToRgb(VisionTemperature) * min(pow(FreqRatio, RedShiftIntensityExponent), ShiftMax) * min(1.0, 1.3 * (OuterRadius - PosR) / max(1e-9, (OuterRadius - InterRadius))); SampleColor.a *= 0.125;

                     float DilutionOuterRadius = mix(min(OuterRadius, 25.0), OuterRadius, smoothstep(6.0, max(0.05*OuterRadius,12.0), PosR));
                     float term1 = 5.0 / (max(Thin, 0.2) + (Hopper * 0.5) * DilutionOuterRadius);
                     float term2_base = 100.0 / max(1e-9, DilutionOuterRadius);
                     vec4 v2 = mix(vec4(term2_base), vec4(0.3 + 0.7 * term2_base, 0.3 + 0.7 * term2_base, 0.3 + 0.7 * term2_base, 1.0), exp(-pow(20.0 * PosR / max(1e-9, DilutionOuterRadius), 2.0)));
                     SampleColor *= max(vec4(term1), v2);

                     float InnerBrightenFac = mix(3.0,2.0,clamp((OuterRadius - 50.0)/50.0,0.0,1.0));
                     float InnerBrightenRatio = 1.0-clamp(6.0*(PosR - InterRadius) / max(1e-9, (OuterRadius - InterRadius)),0.0,1.0);
                     InnerBrightenRatio *= InnerBrightenRatio;
                     SampleColor.xyz *= mix(1.0, max(1.0, abs(local_Dir.y) * 5.0), clamp(0.3 - 0.6 * (PerturbedThickness / max(1e-6, Density) - 1.0), 0.0, 0.3)) * (1.0 + 1.2 * max(0.0, max(0.0, min(1.0, 3.0 - 2.0 * Thin)) * min(0.5, 1.0 - 5.0 * Hopper))) * Brightmut * (1.0 + InnerBrightenFac*InnerBrightenRatio);
                     SampleColor.a *= Darkmut * (1.0 + (1.0+InnerBrightenFac)*InnerBrightenRatio);

                     vec4 StepColor = SampleColor * StepSize;
                     float OneMinusA = 1.0 - CurrentResult.a;
                     float invAaG = pow(OneMinusA, aG);
                     vec3 AttStep = StepColor.rgb * vec3(OneMinusA, invAaG, pow(OneMinusA, aB));
                     float Denominator = AttStep.r + AttStep.g + AttStep.b;
                     if (Denominator > 1e-6) {
                         float Sum_rgb = (StepColor.r + StepColor.g + StepColor.b) * invAaG;
                         vec3 normAtt = AttStep / Denominator;
                         CurrentResult.rgb += (Sum_rgb * normAtt) * pow(3.0 * normAtt, vec3(Saturation));
                     }
                     CurrentResult.a += StepColor.a * (1.0 - CurrentResult.a);
                 }
                 }
            }
        }
    }
    return CurrentResult;
}

vec4 JetColor(vec4 BaseColor, vec4 RayPos, vec4 LastRayPos, vec4 iP_cov, vec4 lastiP_cov, float iE_obs, float InterRadius, float OuterRadius, float JetRedShiftIntensityExponent, float JetBrightmut, float JetReddening, float JetSaturation, float AccretionRate, float JetShiftMax, float PhysicalSpinA, float PhysicalQ, bool isoutgoing, inout float RayMarchPhase)
{
    vec4 CurrentResult = BaseColor;
    vec3 StartPos = LastRayPos.xyz; vec3 EndPos = RayPos.xyz;

    vec3 ChordDelta = EndPos - StartPos; vec3 MidPos = 0.5 * (StartPos + EndPos);
    KerrGeometry geo_mid; ComputeGeometryScalars(MidPos, PhysicalSpinA, PhysicalQ, 1.0, 1.0, isoutgoing, geo_mid);
    float proper_dist = sqrt(max(1e-9, dot(ChordDelta, ChordDelta) + geo_mid.f * pow(dot(geo_mid.l_down.xyz, ChordDelta), 2.0)));
    float TotalDist = proper_dist; float TraveledDist = 0.0;

    if (max(length(StartPos.xz), length(RayPos.xz)) > OuterRadius * 1.5 && max(abs(StartPos.y), abs(RayPos.y)) < OuterRadius) return BaseColor;

    float aR = 1.0; float aG = 1.0 + JetReddening * 2.0; float aB = 1.0 + JetReddening * 5.0;
    float accretionFactor = JetBrightmut * (0.5 + 0.5 * tanh(log(max(1e-6, AccretionRate)) + 1.0));

    for (int SafetyLoopCount = 0; SafetyLoopCount < 1000; SafetyLoopCount++) {
        if (CurrentResult.a > 0.99 || TraveledDist >= TotalDist) break;

        vec3 CurrentPos = mix(StartPos, EndPos, clamp(TraveledDist / max(1e-9, TotalDist), 0.0, 1.0));
        float DistanceToBlackHole = length(CurrentPos);
        float StepSize = ComputeStepSize(DistanceToBlackHole, OuterRadius);

        float DistToNextSample = RayMarchPhase * StepSize;
        float NextTarget = min(TotalDist, TraveledDist + DistToNextSample);

        bool shouldSample = false;
        if (NextTarget < TotalDist) { shouldSample = true; RayMarchPhase = 1.0; TraveledDist = NextTarget; }
        else { RayMarchPhase = max(0.0, RayMarchPhase - (TotalDist - TraveledDist) / max(1e-9, StepSize)); TraveledDist = TotalDist; }

        if (shouldSample) {
            float TimeInterpolant = min(1.0, TraveledDist / max(1e-9, TotalDist));
            vec4 Sample_X = vec4(mix(StartPos, EndPos, TimeInterpolant), mix(LastRayPos.w, RayPos.w, TimeInterpolant));
            vec4 Sample_P_cov = mix(lastiP_cov, iP_cov, TimeInterpolant);
            if (isoutgoing) transformKerrSchild_YSpin(Sample_X, 1.0, Sample_P_cov, 0.5, PhysicalSpinA, PhysicalQ, true);
            vec3 SamplePos = Sample_X.xyz; float EmissionTime = iBlackHoleTime + Sample_X.w;

            float PosR = KerrSchildRadius(SamplePos, PhysicalSpinA, 1.0); float PosY = SamplePos.y; float RhoSq = dot(SamplePos.xz, SamplePos.xz); float Rho = sqrt(RhoSq);
            vec4 AccumColor = vec4(0.0); bool InJet = false;

            if (RhoSq < 2.0 * InterRadius * InterRadius + 0.0009 * PosY * PosY && PosR < 1.41421356 * OuterRadius) {
                InJet = true; float ShapeVal = 1.0 / sqrt(max(1e-9, InterRadius * InterRadius + 0.0004 * PosY * PosY));
                AccumColor += vec4(1.0, 1.0, 1.0, 0.5) * max(0.0, 1.0 - 5.0 * ShapeVal * abs(1.0 - pow(Rho * ShapeVal, 2.0))) * ShapeVal * mix(0.7 + 0.3 * PerlinNoise1D(0.24 * (EmissionTime - 1.25 * (abs(PosY) + 100.0 * RhoSq / max(0.1, PosR))) / max(1e-6, OuterRadius * 0.01)), 1.0, exp(-0.0001 * PosY * PosY)) * max(0.0, 1.0 - exp(-0.0001 * PosY * PosY / max(1e-6, InterRadius * InterRadius))) * exp(-2.0 * pow(PosR / max(1e-6, OuterRadius), 2.0)) * 0.5 * StepSize;
            }

            if (InJet) {
                KerrGeometry geo_sample; ComputeGeometryScalars(SamplePos, PhysicalSpinA, PhysicalQ, 1.0, 1.0, false, geo_sample);
                vec3 U_spatial = vec3(0.0, sign(PosY) * 1.3333333, 0.0);
                float l_dot_u_sp = dot(geo_sample.l_down.xyz, U_spatial); float U_sp_sq = dot(U_spatial, U_spatial);
                float A = -1.0 + geo_sample.f; float B = 2.0 * geo_sample.f * l_dot_u_sp; float C = U_sp_sq + geo_sample.f * l_dot_u_sp * l_dot_u_sp + 1.0;
                float Det = B * B - 4.0 * A * C;
                if (Det < 0.0) { U_spatial = (A < 0.0) ? U_spatial * 0.5 : -1.5 * geo_sample.grad_r; l_dot_u_sp = dot(geo_sample.l_down.xyz, U_spatial); U_sp_sq = dot(U_spatial, U_spatial); C = U_sp_sq + geo_sample.f * l_dot_u_sp * l_dot_u_sp + 1.0; B = 2.0 * geo_sample.f * l_dot_u_sp; Det = max(0.0, B * B - 4.0 * A * C); }
                float Ut = (abs(A) < 1e-7) ? (-C / max(1e-19, B)) : ((B < 0.0) ? (2.0 * C / (-B + sqrt(Det))) : ((-B - sqrt(Det)) / (2.0 * A)));

                float E_emit = -dot(Sample_P_cov, vec4(U_spatial, Ut)); float FreqRatio = 1.0 / max(1e-6, E_emit);
                AccumColor.xyz *= KelvinToRgb(min(100000.0 * FreqRatio,100000.0)) * min(pow(FreqRatio, JetRedShiftIntensityExponent), JetShiftMax) * accretionFactor;
                AccumColor.a = 0.0;

                if (E_emit <= 0.0) AccumColor.rgb = vec3(max(max(AccumColor.r, AccumColor.g), AccumColor.b) + min(min(AccumColor.r, AccumColor.g), AccumColor.b)) - AccumColor.rgb;

                float invAaG = pow(1.0 - CurrentResult.a, aG);
                vec3 attJet = AccumColor.rgb * vec3(1.0 - CurrentResult.a, invAaG, pow(1.0 - CurrentResult.a, aB));
                float DenomJet = attJet.r + attJet.g + attJet.b;
                if (DenomJet > 1e-6) {
                    float sumRGB = (AccumColor.r + AccumColor.g + AccumColor.b) * invAaG;
                    vec3 normAtt = attJet / DenomJet;
                    CurrentResult.rgb += (sumRGB * normAtt) * pow(3.0 * normAtt, vec3(JetSaturation));
                }
                CurrentResult.a += AccumColor.a * (1.0 - CurrentResult.a);
            }
        }
    }
    return CurrentResult;
}

struct TraceResult {
    vec3  EscapeDir;
    float FreqShift;
    float Status;
    vec4  AccumColor;
    float CurrentSign;
};

TraceResult TraceRay(vec3 RayPos, vec3 RayDir, float iUniverseSign, float time, vec2 fragCoordUV)
{
    TraceResult res; res.EscapeDir = vec3(0.0); res.FreqShift = 0.0; res.Status = 0.0; res.AccumColor = vec4(0.0);
    float iSpinclamp = clamp(iSpin, -0.99, 0.99); float a2 = iSpinclamp * iSpinclamp; float abs_a = abs(iSpinclamp);
    float common_term = pow(1.0 - a2, 1.0/3.0); float Z1 = 1.0 + common_term * (pow(1.0 + abs_a, 1.0/3.0) + pow(1.0 - abs_a, 1.0/3.0));
    float Rms_M = 3.0 + sqrt(3.0 * a2 + Z1 * Z1) - (sign(iSpinclamp) * sqrt(max(0.0, (3.0 - Z1) * (3.0 + Z1 + 2.0 * sqrt(3.0 * a2 + Z1 * Z1)))));
    float AccretionEffective = sqrt(max(0.001, 1.0 - (2.0 / 3.0) / Rms_M));

    float DiskArgument = 1.52491e30 / iBlackHoleMassSol * (iMu / AccretionEffective) * (iAccretionRate);
    float PeakTemperature = pow(DiskArgument * 0.05665278, 0.25);

    float PhysicalSpinA = iSpin * CONST_M; float PhysicalQ = iQ * CONST_M;
    float HorizonDiscrim = 0.25 - PhysicalSpinA * PhysicalSpinA - PhysicalQ * PhysicalQ;
    float EventHorizonR = 0.5 + sqrt(max(0.0, HorizonDiscrim));
    float InnerHorizonR = 0.5 - sqrt(max(0.0, HorizonDiscrim));
    bool bIsNakedSingularity = HorizonDiscrim < 0.0;

    float RaymarchingBoundary = max(max(iOuterRadiusRs + 1.0, 501.0), iSpin * 2.0);
    float invBoundaryRange = 1.0 / (RaymarchingBoundary - 100.0);
    float ShiftMax = 1.0;
    float CurrentUniverseSign = iUniverseSign;
    if (iBlackHoleMassSol < 0.0) CurrentUniverseSign = -CurrentUniverseSign;

    vec3 RayPosLocal = RayPos;
    vec3 RayDirWorld_Geo = RayDir;

    vec4 Result = vec4(0.0); bool bShouldContinueMarchRay = true; bool bWaitCalBack = false;
    float DistanceToBlackHole = length(RayPosLocal);

    if (DistanceToBlackHole > RaymarchingBoundary) {
        vec3 O = RayPosLocal; vec3 D = RayDirWorld_Geo; float r = RaymarchingBoundary - 1.0;
        float b = dot(O, D); float c = dot(O, O) - r * r; float delta = b * b - c;
        if (delta < 0.0) { bShouldContinueMarchRay = false; bWaitCalBack = true; }
        else {
            float tEnter = -b - sqrt(delta);
            if (tEnter > 0.0) RayPosLocal = O + D * tEnter;
            else if (-b + sqrt(delta) <= 0.0) { bShouldContinueMarchRay = false; bWaitCalBack = true; }
        }
    }

    vec4 X = vec4(RayPosLocal, 0.0); vec4 P_cov = vec4(0.0,0.0,0.0,-1.0);
    float E_conserved = 1.0; vec3 LastDir = RayDir; vec3 LastPos = RayPosLocal;
    float GravityFade = CubicInterpolate(clamp(1.0 - (length(RayPosLocal) - 100.0) * invBoundaryRange, 0.0, 1.0));
    bool isoutgoing = false;

    if (bShouldContinueMarchRay) {
       P_cov = GetInitialMomentum(RayDir, X, CurrentUniverseSign, PhysicalSpinA, PhysicalQ, GravityFade, isoutgoing);
    }

    E_conserved = -P_cov.w;
    float TerminationR = -1.0; float CameraStartR = KerrSchildRadius(RayPosLocal, PhysicalSpinA, CurrentUniverseSign);

    if (CurrentUniverseSign > 0.0 && !bIsNakedSingularity) {
        if (CameraStartR > EventHorizonR) TerminationR = EventHorizonR;
        else if (CameraStartR > InnerHorizonR) TerminationR = InnerHorizonR;
    }

    float lastR = 0.0; int universeoffset = 0;
    float LastDr = 0.0; int RadialTurningCounts = 0; float RayMarchPhase = RandomStep(fragCoordUV, iTime); float ThetaInShell=0.0; bool shiftinout=false;
    vec4 LastX_ingoing; vec4 X_ingoing = X; vec4 P_cov_ingoing = P_cov; vec4 LastP_cov_ingoing = P_cov_ingoing;
    if(P_cov == vec4(0.0,0.0,0.0,-1.0)) { P_cov_ingoing.xyz = -RayDir; } else {
        if (isoutgoing) transformKerrSchild_YSpin(X_ingoing, CurrentUniverseSign, P_cov_ingoing, CONST_M, PhysicalSpinA, PhysicalQ, isoutgoing);
        LastX_ingoing = X_ingoing; LastP_cov_ingoing = P_cov_ingoing;
    }

    KerrGeometry geo; KerrGeometry geoNext; bool geoCached = false;
    float MaxStep = ((bIsNakedSingularity) ? 450.0 : (150.0+300.0/(1.0+1000.0*pow(1.0-iSpinclamp*iSpinclamp-PhysicalQ*PhysicalQ, 2.0))));
    float maxStepsLimit = MaxStep * iQuality * (1.0 + 0.3 * iQuality);

    for (int Count = 0; Count < 2000; Count++) {
        if (!bShouldContinueMarchRay) break;
        if (float(Count) > maxStepsLimit) { bShouldContinueMarchRay = false; bWaitCalBack = false; break; }

        DistanceToBlackHole = length(X.xyz);
        if (DistanceToBlackHole > RaymarchingBoundary) { bShouldContinueMarchRay = false; bWaitCalBack = true; break; }

        if (geoCached) geo = geoNext; else ComputeGeometryScalars(X.xyz, PhysicalSpinA, PhysicalQ, GravityFade, CurrentUniverseSign, isoutgoing, geo);
        geoCached = false;

        if (CurrentUniverseSign > 0.0 && geo.r < TerminationR && !bIsNakedSingularity && TerminationR != -1.0) { bShouldContinueMarchRay = false; bWaitCalBack = false; break; }

        State s0; s0.X = X; s0.P = P_cov; State k1 = GetDerivativesAnalytic(s0, PhysicalSpinA, PhysicalQ, GravityFade, isoutgoing, geo);
        float CurrentDr = dot(geo.grad_r, k1.X.xyz); shiftinout = false;

        if (Count > 0 && CurrentDr * LastDr < 0.0) RadialTurningCounts++;
        if (Count==0) lastR = geo.r;

        {
            vec4 P_contra = RaiseIndex(P_cov, geo); float current_Sum = dot(abs(P_contra), vec4(1.0));
            vec4 test_X = X; vec4 test_P = P_cov; transformKerrSchild_YSpin(test_X, CurrentUniverseSign, test_P, CONST_M, PhysicalSpinA, PhysicalQ, isoutgoing);
            KerrGeometry test_geo; ComputeGeometryScalars(test_X.xyz, PhysicalSpinA, PhysicalQ, GravityFade, CurrentUniverseSign, !isoutgoing, test_geo);
            if (current_Sum > 2.0 * dot(abs(RaiseIndex(test_P, test_geo)), vec4(1.0))) {
                X = test_X; P_cov = test_P; isoutgoing = !isoutgoing; geo = test_geo;
                s0.X = X; s0.P = P_cov; k1 = GetDerivativesAnalytic(s0, PhysicalSpinA, PhysicalQ, GravityFade, isoutgoing, geo); CurrentDr = dot(geo.grad_r, k1.X.xyz); shiftinout = true;
            }
        }
        LastDr = CurrentDr;

        if (RadialTurningCounts > 2) { bShouldContinueMarchRay = false; bWaitCalBack = false; break; }

        float rho = length(X.xz); float RingDr = rho - abs(PhysicalSpinA); float DistRing = sqrt(X.y * X.y + RingDr * RingDr);
        float dLambda = max(0.5 * (bIsNakedSingularity ? 1.0 : mix(max(abs(iSpin),0.1), 1.0, clamp((geo.r - InnerHorizonR) / max(1e-9, 0.5 - InnerHorizonR), 0.0, 1.0))) * (1.0 / (1.0 + 1.0 * ((PhysicalQ * PhysicalQ) / max(1e-9, geo.r2 + 0.01)))) * min(DistRing / max(1e-9, length(k1.X) + 1e-9), length(P_cov) / max(1e-9, length(k1.P) + 1e-15)), 1e-7);

        vec4 LastX = X; vec4 LastP_cov=P_cov; LastX_ingoing = X_ingoing; LastP_cov_ingoing = P_cov_ingoing;
        GravityFade = CubicInterpolate(clamp(1.0 - (DistanceToBlackHole - 100.0) * invBoundaryRange, 0.0, 1.0));

        if (RaiseIndex(P_cov, geo).w > 10000.0 * iQuality && !bIsNakedSingularity && CurrentUniverseSign > 0.0) { bShouldContinueMarchRay = false; bWaitCalBack = false; break; }

        StepGeodesicRK4_Optimized(X, P_cov, E_conserved, -dLambda/iQuality, PhysicalSpinA, PhysicalQ, GravityFade, CurrentUniverseSign, isoutgoing, geo, k1, geoNext);
        geoCached = true;
        float deltar = geo.r - lastR;

        X_ingoing = X; P_cov_ingoing = P_cov;
        if (isoutgoing) transformKerrSchild_YSpin(X_ingoing, CurrentUniverseSign, P_cov_ingoing, CONST_M, PhysicalSpinA, PhysicalQ, isoutgoing);

        vec3 StepVec_ingoing = X_ingoing.xyz - LastX_ingoing.xyz; float ActualStepLength_ingoing = length(StepVec_ingoing);
        float StepDrRatio = deltar / max(ActualStepLength_ingoing, 1e-9);
        lastR = geo.r;

        if (LastX.y * X.y < 0.0) { if (length(mix(LastX.xz, X.xz, LastX.y / max(1e-9, LastX.y - X.y))) < abs(PhysicalSpinA)) CurrentUniverseSign *= -1.0; }

        if (CurrentUniverseSign > 0.0 && iBlackHoleMassSol > 0.0) {
           Result = DiskColor(Result, X, LastX, P_cov, LastP_cov, E_conserved, iInterRadiusRs, iOuterRadiusRs, iThinRs, iHopper, iBrightmut, iDarkmut, iReddening, iSaturation, DiskArgument, iBlackbodyIntensityExponent, iRedShiftColorExponent, iRedShiftIntensityExponent, PeakTemperature, ShiftMax, PhysicalSpinA, PhysicalQ, isoutgoing, ThetaInShell, RayMarchPhase);
           Result = JetColor(Result, X, LastX, P_cov, LastP_cov, E_conserved, iInterRadiusRs, iOuterRadiusRs, iJetRedShiftIntensityExponent, iJetBrightmut, iReddening, iJetSaturation, iAccretionRate, iJetShiftMax, clamp(PhysicalSpinA, -0.049, 0.049), PhysicalQ, isoutgoing, RayMarchPhase);
        }

        if (Result.a > 0.99) { bShouldContinueMarchRay = false; bWaitCalBack = false; break; }
    }

    res.CurrentSign = CurrentUniverseSign; res.AccumColor = Result;

    if (Result.a > 0.99) { res.Status = 3.0; res.EscapeDir = vec3(0.0); res.FreqShift = 0.0; }
    else if (bWaitCalBack) {
        KerrGeometry geo_sky; ComputeGeometryScalars(X_ingoing.xyz, PhysicalSpinA, PhysicalQ, GravityFade, CurrentUniverseSign, false, geo_sky);
        res.EscapeDir = normalize(-RaiseIndex(P_cov_ingoing, geo_sky).xyz);
        if (DistanceToBlackHole > RaymarchingBoundary ) res.EscapeDir = normalize(-P_cov_ingoing.xyz);
        if (any(isnan(res.EscapeDir)) || any(isinf(res.EscapeDir))) res.EscapeDir = normalize(RayDir);
        res.FreqShift = clamp(1.0 / max(1e-14, abs(E_conserved)), 1.0/iBackShiftMax, iBackShiftMax);

        if (CurrentUniverseSign > 0.0) res.Status = 1.0; else res.Status = 2.0;
    } else { res.Status = 0.0; res.EscapeDir = vec3(0.0); res.FreqShift = 0.0; }
    res.Status += (E_conserved >= 0.0) ? 0.0 : 0.2;

    return res;
}

void main() {
    vec2 p_screen = uv * 2.0 - 1.0;
    p_screen.x *= u_resolution.x / u_resolution.y;
    vec3 rayDir = normalize(u_camForward + p_screen.x * u_tanHalfFov * u_camRight + p_screen.y * u_tanHalfFov * u_camUp);

    TraceResult res = TraceRay(u_camPos_Rs, rayDir, u_universeSign, iTime, uv);
    vec4 FinalColor = res.AccumColor;
    float CurrentStatus = res.Status;
    vec3 CurrentDir = res.EscapeDir;
    float CurrentShift = res.FreqShift;

    if (CurrentStatus > 0.5 && CurrentStatus < 20.0 && CurrentStatus != 3.0)
    {
        vec4 Bg = SampleBackground(CurrentDir, CurrentShift, CurrentStatus);
        float invA = clamp(1.0 - FinalColor.a, 0.0, 1.0);
        FinalColor += 0.9999 * Bg * vec4(invA, pow(invA, 1.6), pow(invA, 2.5), 1.0);
    }
    FinalColor = ApplyToneMapping(FinalColor, CurrentShift);
    fragColor = vec4(FinalColor.rgb * brightness, 1.0);
}
]]

local function computeRelPos(cx, cy, cz)
   local px = (cx - (Game.mapSizeX or 16000) * 0.5) / ELMOS_PER_RS
   local py = (cy - 200.0) / ELMOS_PER_RS
   local pz = (cz - (Game.mapSizeZ or 16000) * 0.5) / ELMOS_PER_RS
   return { x = BH_BASE_X + px, y = BH_BASE_Y + py, z = BH_BASE_Z + pz }
end

local function updateUniverseSign(relPos)
   if prevRelPos then
      local oy = prevRelPos.y
      if oy * relPos.y < 0.0 then
         local t = oy / (oy - relPos.y)
         local cx = prevRelPos.x + (relPos.x - prevRelPos.x) * t
         local cz = prevRelPos.z + (relPos.z - prevRelPos.z) * t
         if (cx * cx + cz * cz) < (SPIN_RADIUS * SPIN_RADIUS) then universeSign = -universeSign end
      end
   end
   prevRelPos = relPos
end

function widget:Initialize()
   local vsx, vsy = Spring.GetViewGeometry()
   if not vsx or vsx <= 0 then return end
   startClock = os.clock()
   shader = gl.LuaShader({
       vertex = skyVs,
       fragment = skyFs,
       uniformFloat = {
           u_time = 0, brightness = C_THEME.brightness,
           u_camPos_Rs = {BH_BASE_X, BH_BASE_Y, BH_BASE_Z},
           u_camForward = {0, 0, -1}, u_camRight = {1, 0, 0}, u_camUp = {0, 1, 0},
           u_tanHalfFov = 0.4142, u_universeSign = 1.0
       }
   }, "BlackHoleSkybox")

   if shader:Initialize() then
       if gl.GetVAO then fullTexQuad = gl.GetVAO() end
       isInitialized = true
   else
       widgetHandler:RemoveWidget(self)
   end
end

function widget:DrawWorldPreUnit()
   local cx, cy, cpx, cpy = Spring.GetViewGeometry()
   if cpx ~= 0 or cpy ~= 0 then return end
   if not isInitialized or not shader then return end
   currVsx, currVsy = cx, cy

   local ok, err = pcall(function()
       gl.DepthTest(GL.LEQUAL)
       gl.DepthMask(false)
       gl.Blending(false)

       shader:Activate()
       shader:SetUniform("u_resolution", currVsx, currVsy)
       shader:SetUniform("brightness", C_THEME.brightness)
       shader:SetUniform("u_time", os.clock() - startClock)

       local camPos_x, camPos_y, camPos_z = Spring.GetCameraPosition()
       if camPos_x then
           local relPos = computeRelPos(camPos_x, camPos_y, camPos_z)
           updateUniverseSign(relPos)
           shader:SetUniform("u_camPos_Rs", relPos.x, relPos.y, relPos.z)
       end
       shader:SetUniform("u_universeSign", universeSign)

       local camVectors = Spring.GetCameraVectors()
       if camVectors and camVectors.forward and camVectors.right and camVectors.up then
           local fwd = camVectors.forward
           local right = camVectors.right
           local up = camVectors.up
           shader:SetUniform("u_camForward", fwd[1], fwd[2], fwd[3])
           shader:SetUniform("u_camRight", right[1], right[2], right[3])
           shader:SetUniform("u_camUp", up[1], up[2], up[3])
       elseif not skyDebugWarned then
           skyDebugWarned = true
           Spring.Echo("[BlackHoleSkybox] Spring.GetCameraVectors() returned unexpected data.")
       end

       local fovY = Spring.GetCameraFOV()
       if fovY then shader:SetUniform("u_tanHalfFov", math.tan(math.rad(fovY * 0.5))) end

       if fullTexQuad and fullTexQuad.DrawArrays then
           fullTexQuad:DrawArrays(GL.TRIANGLES, 3)
       else
           gl.BeginEnd(GL.TRIANGLES, function() gl.Vertex(-1, -1); gl.Vertex( 3, -1); gl.Vertex(-1,  3) end)
       end
       shader:Deactivate()
   end)

   if not ok and not skyDebugWarned then
       skyDebugWarned = true
       Spring.Echo("[BlackHoleSkybox] DrawWorldPreUnit error: " .. tostring(err))
   end

   gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
   gl.DepthTest(true)
   gl.DepthMask(true)
end

function widget:Shutdown()
   if isInitialized and shader then shader:Finalize() end
   if fullTexQuad and fullTexQuad.Delete then fullTexQuad:Delete() end
   isInitialized = false
end
