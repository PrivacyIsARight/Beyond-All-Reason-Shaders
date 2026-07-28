function widget:GetInfo()
   return {
      name      = "Blue Iridescent Tunnel Skybox",
      desc      = "Shader by Yusef28",
      author    = "vexalous",
      date      = "2026",
      license   = "CC BY-NC-SA 3.0",
      layer     = -10001,
      enabled   = true
   }
end

local C_THEME = { brightness = 1.0 }

local spGetCameraVectors = Spring.GetCameraVectors
local spGetCameraFOV     = Spring.GetCameraFOV
local spGetViewGeometry  = Spring.GetViewGeometry
local spEcho             = Spring.Echo
local osClock            = os.clock
local mTan               = math.tan
local mRad               = math.rad

local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending  = gl.Blending
local glBeginEnd  = gl.BeginEnd
local glVertex    = gl.Vertex
local glGetVAO    = gl.GetVAO

local GL_LEQUAL              = GL.LEQUAL
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_TRIANGLES           = GL.TRIANGLES

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
]]

local isInitialized = false
local shader, fullTexQuad
local startClock = 0
local skyDebugWarned = false

local currVsx, currVsy

local function DrawFallbackTri()
   glVertex(-1, -1); glVertex( 3, -1); glVertex(-1,  3)
end

local function DoDrawWorld()
   glDepthTest(GL_LEQUAL)
   glDepthMask(false)
   glBlending(false)

   shader:Activate()
   shader:SetUniform("u_resolution", currVsx, currVsy)
   shader:SetUniform("brightness", C_THEME.brightness)
   shader:SetUniform("u_time", osClock() - startClock)

   local camVectors = spGetCameraVectors()
   if camVectors and camVectors.forward and camVectors.right and camVectors.up then
      local fwd = camVectors.forward
      local right = camVectors.right
      local up = camVectors.up

      local fovY = spGetCameraFOV()
      local thf = fovY and mTan(mRad(fovY * 0.5)) or 0.4142

      shader:SetUniform("u_camForward", fwd[1], fwd[2], fwd[3])
      shader:SetUniform("u_camRightScaled", right[1] * thf, right[2] * thf, right[3] * thf)
      shader:SetUniform("u_camUpScaled", up[1] * thf, up[2] * thf, up[3] * thf)
   elseif not skyDebugWarned then
      skyDebugWarned = true
      spEcho("[BlueIridescentTunnelSkybox] Spring.GetCameraVectors() returned unexpected data.")
   end

   if fullTexQuad and fullTexQuad.DrawArrays then
      fullTexQuad:DrawArrays(GL_TRIANGLES, 3)
   else
      glBeginEnd(GL_TRIANGLES, DrawFallbackTri)
   end

   shader:Deactivate()
end

function widget:Initialize()
   local cx, cy = spGetViewGeometry()
   if not cx or cx <= 0 then return end

   startClock = osClock()

   shader = gl.LuaShader({
       vertex = skyVs,
       fragment = skyFs,
       uniformFloat = {
           u_time = 0,
           brightness = C_THEME.brightness,
           u_camForward = {0, 0, -1},
           u_camRightScaled = {0.4142, 0, 0},
           u_camUpScaled = {0, 0.4142, 0}
       }
   }, "BlueIridescentTunnelSkybox")

   if shader:Initialize() then
       if glGetVAO then fullTexQuad = glGetVAO() end
       isInitialized = true
   else
       widgetHandler:RemoveWidget(self)
   end
end

function widget:DrawWorld()
   local cx, cy, cpx, cpy = spGetViewGeometry()
   if cpx ~= 0 or cpy ~= 0 then return end
   if not isInitialized or not shader then return end

   currVsx, currVsy = cx, cy

   local ok, err = pcall(DoDrawWorld)

   if not ok and not skyDebugWarned then
      skyDebugWarned = true
      spEcho("[BlueIridescentTunnelSkybox] DrawWorld error: " .. tostring(err))
   end

   glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
   glDepthTest(true)
   glDepthMask(true)
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
