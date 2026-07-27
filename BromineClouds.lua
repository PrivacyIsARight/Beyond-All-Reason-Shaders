function widget:GetInfo()
   return {
      name      = "Bromine Clouds Skybox",
      desc      = "Shader by Kaso",
      author    = "vexalous",
      date      = "2026",
      license   = "CC BY-SA 4.0",
      layer     = -10001,
      enabled   = true
   }
end

local C_THEME = { brightness = 1.0 }

local skyVs = [[
#version 330
const vec2 vertices[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));
out vec2 uv;
void main() {
    gl_Position = vec4(vertices[gl_VertexID], 0.99999, 1.0);
    uv = vertices[gl_VertexID] * 0.5 + 0.5;
}
]]

local skyFs = [[
#version 330
uniform vec2 u_resolution;
uniform float u_time;
uniform float brightness;
in vec2 uv;
out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
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
    vec2 uv2 = gl_FragCoord.xy / u_resolution.xy;
    vec2 p = uv2 - 0.5;
    p.x *= u_resolution.x / u_resolution.y;

    float t = u_time * 0.05;

    vec2 flow = vec2(fbm(p * 2.0 + vec2(0.0, t)), fbm(p * 2.0 + vec2(0.0, -t)));
    vec2 q = p + 0.35 * (flow - 0.5);

    float n1 = fbm(q * 3.0 + t);
    float n2 = fbm(q * 6.0 - t * 1.3);
    float blobs = smoothstep(0.3, 0.9, n1 + 0.6 * n2);

    float r = length(q);
    float glow = exp(-3.0 * r) * (0.6 + 0.4 * sin(t * 2.0 + n1 * 6.0));

    float intensity = blobs * 0.7 + glow;

    float colorField = fbm(q * 2.0 + intensity + t);
    vec3 col = palette(colorField + intensity * 0.5);

    col += vec3(0.3, 0.5, 0.8) * glow;
    col *= intensity * 2.0;
    col = 1.0 - exp(-col);

    fragColor = vec4(col * brightness, 1.0);
}
]]

local isInitialized = false
local shader, fullTexQuad, vsx, vsy

function widget:Initialize()
   vsx, vsy = Spring.GetViewGeometry()
   if not vsx or vsx <= 0 then return end

   shader = gl.LuaShader({
       vertex = skyVs,
       fragment = skyFs,
       uniformFloat = { u_time = 0, brightness = C_THEME.brightness }
   }, "BromineCloudsSkybox")
   if shader:Initialize() then
       if gl.GetVAO then fullTexQuad = gl.GetVAO() end
       isInitialized = true
   else
       widgetHandler:RemoveWidget(self)
   end
end

function widget:DrawWorld()
   local currVsx, currVsy, currVpx, currVpy = Spring.GetViewGeometry()
   if currVpx ~= 0 or currVpy ~= 0 then return end
   if not isInitialized or not shader then return end

   gl.DepthTest(GL.LEQUAL)
   gl.DepthMask(false)
   gl.Blending(false)

   shader:Activate()
   shader:SetUniform("u_resolution", currVsx, currVsy)
   shader:SetUniform("brightness", C_THEME.brightness)
   shader:SetUniform("u_time", os.clock())

   if fullTexQuad and fullTexQuad.DrawArrays then
      fullTexQuad:DrawArrays(GL.TRIANGLES, 3)
   else
       gl.BeginEnd(GL.TRIANGLES, function()
           gl.Vertex(-1, -1); gl.Vertex( 3, -1); gl.Vertex(-1,  3)
       end)
   end

   shader:Deactivate()
   gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
   gl.DepthTest(true)
   gl.DepthMask(true)
end

function widget:Shutdown()
   isInitialized = false
   if shader then shader:Finalize() end
   if fullTexQuad and fullTexQuad.Delete then fullTexQuad:Delete() end
end

function widget:ViewResize()
   vsx, vsy = Spring.GetViewGeometry()
end
