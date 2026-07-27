local version = "1.0 Ribbons Skybox"

function widget:GetInfo()
   return {
      name      = "Ribbons Skybox",
      desc      = "Shader by lnbg0175",
      author    = "vexalous",
      date      = "2026",
      license   = "CC BY-NC-SA 4.0",
      layer     = -10001,
      enabled   = true
   }
end

local C_THEME = {
   brightness    = 1.0,
}

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

void main() {
    float z = 0.0;
    float d = 0.0;
    float i = 0.0;
    vec4 O = vec4(0.0);
    
    vec3 dir = normalize(vec3(u_resolution.xy, u_resolution.y) - 2.0 * vec3(gl_FragCoord.xy, 0.0));
    
    for (int k = 0; k < 99; k++) {
        vec3 p = z * dir;
        d = 2.0;
        
        for (int j = 0; j < 6; j++) {
            d /= 0.9;
            p = p.zxy + sin(p * d + vec3(d + u_time * 0.5)) / d;
        }
        
        d = 0.001 + abs(2.0 - mix(z, p.z, 0.4)) / 9.0;
        z += d;
        
        O += (sin(z + 0.06 * i + vec4(0.0, 1.0, 2.0, 0.0)) + 1.0) / d;
        i += 1.0;
    }
    
    fragColor = vec4(tanh(O.rgb / 30000.0) * brightness, 1.0);
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
       uniformFloat = { 
           u_time = 0,
           brightness = C_THEME.brightness
       }
   }, "AbstractSkyboxWorld")

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
