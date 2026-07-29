local version = "1.0 Seascape Skybox"

function widget:GetInfo()
   return {
      name      = "Seascape Skybox",
      desc      = "Shader by Alexander Alekseev aka TDM",
      author    = "vexalous",
      date      = "2026",
      license   = "CC BY-NC-SA 3.0",
      layer     = -10001,
      enabled   = true
   }
end

local C_THEME = { brightness = 1.0 }

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
uniform vec2 u_resolution;
uniform float u_time;
uniform float brightness;

uniform vec3 u_camForward;
uniform vec3 u_camRight;
uniform vec3 u_camUp;
uniform float u_tanHalfFov;
uniform vec3 u_camPos;

in vec2 uv;
out vec4 fragColor;

const int NUM_STEPS = 32;
const float PI = 3.141592;
const float EPSILON = 1e-3;
#define EPSILON_NRM (0.1 / u_resolution.x)

const int ITER_GEOMETRY = 3;
const int ITER_FRAGMENT = 5;
const float SEA_HEIGHT = 0.6;
const float SEA_CHOPPY = 4.0;
const float SEA_SPEED = 0.8;
const float SEA_FREQ = 0.16;
const vec3 SEA_BASE = vec3(0.0, 0.09, 0.18);
const vec3 SEA_WATER_COLOR = vec3(0.8, 0.9, 0.6) * 0.6;
#define SEA_TIME (1.0 + u_time * SEA_SPEED)
const mat2 octave_m = mat2(1.6, 1.2, -1.2, 1.6);

float hash(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float noise(in vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return -1.0 + 2.0 * mix(
        mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
        mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}

float diffuse(vec3 n, vec3 l, float p) {
    return pow(dot(n,l) * 0.4 + 0.6, p);
}

float specular(vec3 n, vec3 l, vec3 e, float s) {
    float nrm = (s + 8.0) / (PI * 8.0);
    return pow(max(dot(reflect(e,n),l), 0.0), s) * nrm;
}

vec3 getSkyColor(vec3 e) {
    e.y = (max(e.y,0.0)*0.8+0.2)*0.8;
    return vec3(pow(1.0-e.y,2.0), 1.0-e.y, 0.6+(1.0-e.y)*0.4) * 1.1;
}

float sea_octave(vec2 uv2, float choppy) {
    uv2 += noise(uv2);
    vec2 wv = 1.0 - abs(sin(uv2));
    vec2 swv = abs(cos(uv2));
    wv = mix(wv, swv, wv);
    return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}

float map(vec3 p) {
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    vec2 uv2 = p.xz; uv2.x *= 0.75;

    float d, h = 0.0;
    for (int i = 0; i < ITER_GEOMETRY; i++) {
        d = sea_octave((uv2+SEA_TIME)*freq, choppy);
        d += sea_octave((uv2-SEA_TIME)*freq, choppy);
        h += d * amp;
        uv2 *= octave_m; freq *= 1.9; amp *= 0.22;
        choppy = mix(choppy, 1.0, 0.2);
    }
    return p.y - h;
}

float map_detailed(vec3 p) {
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    vec2 uv2 = p.xz; uv2.x *= 0.75;

    float d, h = 0.0;
    for (int i = 0; i < ITER_FRAGMENT; i++) {
        d = sea_octave((uv2+SEA_TIME)*freq, choppy);
        d += sea_octave((uv2-SEA_TIME)*freq, choppy);
        h += d * amp;
        uv2 *= octave_m; freq *= 1.9; amp *= 0.22;
        choppy = mix(choppy, 1.0, 0.2);
    }
    return p.y - h;
}

vec3 getSeaColor(vec3 p, vec3 n, vec3 l, vec3 eye, vec3 dist) {
    float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
    fresnel = min(fresnel * fresnel * fresnel, 0.5);

    vec3 reflected = getSkyColor(reflect(eye, n));
    vec3 refracted = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12;

    vec3 color = mix(refracted, reflected, fresnel);

    float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
    color += SEA_WATER_COLOR * (p.y - SEA_HEIGHT) * 0.18 * atten;

    color += specular(n, l, eye, 600.0 * inversesqrt(dot(dist,dist)));

    return color;
}

vec3 getNormal(vec3 p, float eps) {
    vec3 n;
    n.y = map_detailed(p);
    n.x = map_detailed(vec3(p.x+eps,p.y,p.z)) - n.y;
    n.z = map_detailed(vec3(p.x,p.y,p.z+eps)) - n.y;
    n.y = eps;
    return normalize(n);
}

float heightMapTracing(vec3 ori, vec3 dir, out vec3 p) {
    p = ori;
    float tm = 0.0;
    float tx = 1000.0;
    float hx = map(ori + dir * tx);
    if (hx > 0.0) {
        p = ori + dir * tx;
        return tx;
    }
    float hm = map(ori);
    for (int i = 0; i < NUM_STEPS; i++) {
        float tmid = mix(tm, tx, hm / (hm - hx));
        p = ori + dir * tmid;
        float hmid = map(p);
        if (hmid < 0.0) {
            tx = tmid;
            hx = hmid;
        } else {
            tm = tmid;
            hm = hmid;
        }
        if (abs(hmid) < EPSILON) break;
    }
    return mix(tm, tx, hm / (hm - hx));
}

vec3 getPixel(in vec2 coord, float time) {
    vec2 p = coord / u_resolution.xy;
    p = p * 2.0 - 1.0;
    p.x *= u_resolution.x / u_resolution.y;

    float safeCamY = 3.5 + (u_camPos.y * 0.0005);
    vec3 ori = vec3(u_camPos.x * 0.0005, safeCamY, u_camPos.z * 0.0005 + (time * 5.0));

    vec3 dir = normalize(u_camForward + p.x * u_tanHalfFov * u_camRight + p.y * u_tanHalfFov * u_camUp);

    vec3 pos;
    heightMapTracing(ori, dir, pos);
    vec3 dist = pos - ori;
    vec3 n = getNormal(pos, dot(dist,dist) * EPSILON_NRM);
    vec3 light = normalize(vec3(0.0, 1.0, 0.8));

    return mix(
        getSkyColor(dir),
        getSeaColor(pos,n,light,dir,dist),
        pow(smoothstep(0.0,-0.02,dir.y),0.2));
}

void main() {
    float time = u_time * 0.3;
    vec3 color = getPixel(gl_FragCoord.xy, time);
    fragColor = vec4(pow(color, vec3(0.65)) * brightness, 1.0);
}
]]

local isInitialized = false
local shader, fullTexQuad, vsx, vsy
local startClock = 0
local skyDebugWarned = false

function widget:Initialize()
   vsx, vsy = Spring.GetViewGeometry()
   if not vsx or vsx <= 0 then return end

   startClock = os.clock()

   shader = gl.LuaShader({
       vertex = skyVs,
       fragment = skyFs,
       uniformFloat = {
           u_time = 0,
           brightness = C_THEME.brightness,
           u_camForward = {0, 0, -1},
           u_camRight = {1, 0, 0},
           u_camUp = {0, 1, 0},
           u_camPos = {0, 0, 0},
           u_tanHalfFov = 0.4142
       }
   }, "SeascapeSkybox")

   if shader:Initialize() then
       if gl.GetVAO then fullTexQuad = gl.GetVAO() end
       isInitialized = true
   else
       widgetHandler:RemoveWidget(self)
   end
end

function widget:DrawWorldPreUnit()
   local currVsx, currVsy, currVpx, currVpy = Spring.GetViewGeometry()
   if currVpx ~= 0 or currVpy ~= 0 then return end
   if not isInitialized or not shader then return end

   local ok, err = pcall(function()
      gl.DepthTest(GL.LEQUAL)
      gl.DepthMask(false)
      gl.Blending(false)

      shader:Activate()
      shader:SetUniform("u_resolution", currVsx, currVsy)
      shader:SetUniform("brightness", C_THEME.brightness)
      shader:SetUniform("u_time", os.clock() - startClock)

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
         Spring.Echo("[SeascapeSkybox] Spring.GetCameraVectors() returned unexpected data.")
      end

      local cx, cy, cz = Spring.GetCameraPosition()
      if cx then
         shader:SetUniform("u_camPos", cx, cy, cz)
      end

      local fovY = Spring.GetCameraFOV()
      if fovY then
         shader:SetUniform("u_tanHalfFov", math.tan(math.rad(fovY * 0.5)))
      end

      if fullTexQuad and fullTexQuad.DrawArrays then
         fullTexQuad:DrawArrays(GL.TRIANGLES, 3)
      else
          gl.BeginEnd(GL.TRIANGLES, function()
              gl.Vertex(-1, -1); gl.Vertex( 3, -1); gl.Vertex(-1,  3)
          end)
      end

      shader:Deactivate()
   end)

   if not ok and not skyDebugWarned then
      skyDebugWarned = true
      Spring.Echo("[SeascapeSkybox] DrawWorldPreUnit error: " .. tostring(err))
   end

   gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
   gl.DepthTest(true)
   gl.DepthMask(true)
end

function widget:Shutdown()
   if isInitialized and shader then
      shader:Finalize()
   end
   if fullTexQuad and fullTexQuad.Delete then
      fullTexQuad:Delete()
   end
   isInitialized = false
end

function widget:ViewResize()
   vsx, vsy = Spring.GetViewGeometry()
end
