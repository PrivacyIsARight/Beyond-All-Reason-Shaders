--[[
    Beyond All Reason Shaders
    Copyright (C) 2026 vexalous

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

function widget:GetInfo()
  return {
    name = "Beyond All Reason Shaders",
    desc = "Shader Selector",
    author = "vexalous",
    date = "2026",
    license = "GPL v3",
    layer = -10001,
    enabled = true,
  }
end

local Min, Max, Abs, Cos, Sin, Pi =
  math.min,
  math.max,
  math.abs,
  math.cos,
  math.sin,
  math.pi
local glColor, glTexCoord, glVertex, glBeginEnd =
  gl.Color,
  gl.TexCoord,
  gl.Vertex,
  gl.BeginEnd
local glText, glLineWidth, glBlending, glDeleteTexture =
  gl.Text,
  gl.LineWidth,
  gl.Blending,
  gl.DeleteTexture
local GL_TRIANGLES, GL_LINEAR, GL_CLAMP =
  GL.TRIANGLES,
  GL.LINEAR,
  GL.CLAMP_TO_EDGE
local GL_SRC_ALPHA, GL_ONE_MINUS = GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA

local None = "none"

local settings = {
  SpatialScale = 3000,
  CenterX = 50,
  CenterY = -10,
  CenterZ = 50,
  FlipRadius = Abs(0.997114514 * 0.5),
  UiW = 456,
  UiH = 416,
  CardW = 208,
  CardImgH = 117,
  CardTitleH = 34,
  CardH = 151,
  CardPadX = 20,
  CardPadY = 20,
  UiPaddingTop = 36,
  UiPaddingBottom = 58,
  PreviewW = 560,
  PreviewH = 460,
  PreviewImgW = 512,
  PreviewImgH = 288,
  PreviewPadTop = 28,
  PreviewPadBottom = 24,
  PreviewTitleGap = 24,
  PreviewImgGap = 26,
  PreviewFontSpacing = 22,
  PreviewSidePad = 24,
  InfoIconR = 8,
  CloseR = 14,
  CloseClickR = 6,
  CardFont = 14,
  InfoIconFont = 11,
  PreviewTitleFont = 20,
  PreviewLabelFont = 14,
  PreviewEmptyFont = 16,
  ResizeGrip = 25,
  UiScaleMin = 0.55,
  UiScaleMax = 2.25,
  PreviewScaleMin = 0.6,
  PreviewScaleMax = 2.0,
  FontFloor = 1.3,
  uScaleX = 1,
  uScaleY = 1,
  uScale = 1,
  cardGapX = 20,
  cardGapY = 20,
  topPad = 36,
  bottomPad = 58,
  cardW = 208,
  cardImgH = 117,
  cardTitleH = 34,
  cardH = 151,
  uiW = 456,
  uiH = 416,
  infoIconR = 8,
  closeR = 14,
  prevScaleX = 1,
  prevScaleY = 1,
  prevScale = 1,
  prevTopPad = 28,
  prevBottomPad = 24,
  prevTitleGap = 24,
  prevImgGap = 26,
  prevFontSpacing = 22,
  prevSidePad = 24,
  prevImgW = 512,
  prevImgH = 288,
  prevW = 560,
  prevH = 460,
}

local state = {
  activeSky = None,
  rightClickPreview = nil,
  initialized = False,
  uiVisible = False,
  clickInProgress = False,
  page = 1,
  universeSign = 1,
  uiX = 0,
  uiY = 0,
  prevX = 0,
  prevY = 0,
  resizingPreview = False,
  resizingUi = False,
  dragPreview = False,
  dragUi = False,
  dragStartX = 0,
  dragStartY = 0,
  dragW = 0,
  dragH = 0,
  dragOffX = 0,
  dragOffY = 0,
  resizeStartX = 0,
  resizeStartY = 0,
  hoverCard = nil,
  hoverInfo = nil,
  hoverClose = False,
  hoverMin = False,
  hoverResize = False,
  hoverResizePrev = False,
  hoverPage = False,
  hoverPageNext = False,
  skyVert = nil,
  fragSrc = {},
  shaders = {},
  uniformList = {},
  usedUniforms = {},
  list = { {
    id = None,
    name = "No Skybox",
    shaderAuthor = "N/A",
    fileAuthor = "N/A",
    license = "N/A",
    source = "N/A",
  } },
  thumbQueue = {},
  thumbs = {},
  shaderClock = 0,
  screenTex = nil,
  lastViewX = 0,
  lastViewY = 0,
  glassShader = nil,
  infoTex = nil,
  infoPanel = False,
  infoTarget = nil,
  fullscreenTri = nil,
  fadeLast = None,
  fadeOn = False,
  fadeStart = 0,
  fadeDuration = 0.7,
  fadeSnap = nil,
  fadeSnapW = 0,
  fadeSnapH = 0,
  fadeShader = nil,
}

local Circle = {}
for i = 0, 16 do
  Circle[i] = { Abs(Cos(i * Pi / 32)) ^ 0.5, Abs(Sin(i * Pi / 32)) ^ 0.5 }
end

local function PrependVersion(src)
  if not src then return end
  if not src:find("^%s*#version") then
    local ver = src:match("(#version%s+%d+)")
    if ver then
      src = ver .. "\n" .. src:gsub("#version%s+%d+%s*\n?", "")
    end
  end
  return src
end

local function ScanShaders()
  local files = VFS.DirList("LuaUI/Shaders/")
  if type(files) ~= "table" then return end
  for _, path in ipairs(files) do
    if type(path) == "string" and path:match("%.frag$") then
      local src = VFS.LoadFile(path)
      if src then
        src = src .. "\n"
        local title = src:match("//%s*Shader:%s*(.-)\r?\n")
        if title then
          local id = path:match("([^/%\\]+)%.frag$")
          table.insert(state.list, {
            id = id,
            name = title,
            shaderAuthor = src:match(
              "//%s*Shader Author:%s*(.-)\r?\n"
            ) or "Unknown",
            fileAuthor = src:match(
              "//%s*File Author:%s*(.-)\r?\n"
            ) or "Unknown",
            source = src:match("//%s*Source:%s*(.-)\r?\n") or "N/A",
            license = src:match("//%s*License:%s*(.-)\r?\n") or "N/A",
          })
          state.fragSrc[id] = PrependVersion(src)
          state.uniformList[id] =
            "," .. (src:match("//%s*Uniforms:%s*(.-)\r?\n") or ""):gsub(
              "[%s,;]+",
              ","
            ) .. ","
        end
      end
    end
  end
  table.sort(state.list, function(a, b)
    if a.id == None and b.id == None then
      return false
    elseif a.id == None then
      return true
    elseif b.id == None then
      return false
    end
    return a.name < b.name
  end)
end

local function CompileSkybox(id)
  if id == None then return end
  local frag = state.fragSrc[id]
  if not state.skyVert or not frag then return end
  local shader = gl.LuaShader(
    {
      vertex = state.skyVert,
      fragment = frag,
    },
    "Skybox_" .. id
  )
  if shader then
    if shader:Initialize() then
      state.usedUniforms[id] = {}
      return shader
    else
      shader:Finalize()
    end
  end
end

local function GetSkybox(id)
  return id ~= None and state.shaders[id] or nil
end

local function ScaleUi(sx, sy)
  settings.uScaleX = Max(settings.UiScaleMin, Min(settings.UiScaleMax, sx))
  settings.uScaleY = Max(settings.UiScaleMin, Min(settings.UiScaleMax, sy))
  settings.uScale = Min(settings.uScaleX, settings.uScaleY)
  local fontFloor = Min(settings.uScaleY, settings.FontFloor)
  settings.cardGapX, settings.cardGapY =
    settings.CardPadX * settings.uScaleX,
    settings.CardPadY * settings.uScaleY
  settings.topPad, settings.bottomPad =
    settings.UiPaddingTop * fontFloor,
    settings.UiPaddingBottom * fontFloor
  settings.cardW = settings.CardW * settings.uScaleX
  settings.cardImgH = settings.CardImgH * settings.uScaleY
  settings.cardTitleH = settings.CardTitleH * settings.uScaleY
  settings.uiW = settings.UiW * settings.uScaleX
  settings.cardH = settings.cardImgH + settings.cardTitleH
  settings.uiH =
    settings.topPad + settings.bottomPad + settings.cardH * 2 + settings.cardGapY
  settings.infoIconR = settings.InfoIconR * settings.uScale
  settings.closeR = settings.CloseR * settings.uScale
end

local function FitUi()
  local vx, vy = Spring.GetViewGeometry()
  if vx and vx > 0 and vy and vy > 0 then
    ScaleUi(vx * 0.5 / settings.UiW, vy * 0.5 / settings.UiH)
  else
    ScaleUi(1, 1)
  end
  state.uiX, state.uiY = 0, 0
end

local function ScalePreview(sx, sy)
  settings.prevScaleX =
    Max(settings.PreviewScaleMin, Min(settings.PreviewScaleMax, sx))
  settings.prevScaleY =
    Max(settings.PreviewScaleMin, Min(settings.PreviewScaleMax, sy))
  settings.prevScale = Min(settings.prevScaleX, settings.prevScaleY)
  local fontFloor = Min(settings.prevScaleY, settings.FontFloor)
  settings.prevTopPad, settings.prevBottomPad =
    settings.PreviewPadTop * fontFloor,
    settings.PreviewPadBottom * fontFloor
  settings.prevTitleGap = settings.PreviewTitleGap * settings.prevScaleY
  settings.prevImgGap = settings.PreviewImgGap * settings.prevScaleY
  settings.prevFontSpacing = settings.PreviewFontSpacing * settings.prevScaleY
  settings.prevSidePad = settings.PreviewSidePad * settings.prevScaleX
  settings.prevImgW = settings.PreviewImgW * settings.prevScaleX
  settings.prevImgH = settings.PreviewImgH * settings.prevScaleY
  settings.prevW = settings.prevSidePad * 2 + settings.prevImgW
  settings.prevH =
    settings.prevTopPad + settings.prevTitleGap + settings.prevImgH + settings.prevImgGap + settings.prevFontSpacing * 3 + settings.PreviewLabelFont * settings.prevScale + settings.prevBottomPad
end

local function WorldToLocal(x, y, z)
  return {
    x = settings.CenterX + (x - (Game.mapSizeX or 16000) * 0.5) / settings.SpatialScale,
    y = settings.CenterY + (y - 200) / settings.SpatialScale,
    z = settings.CenterZ + (z - (Game.mapSizeZ or 16000) * 0.5) / settings.SpatialScale,
  }
end

local function TrackSunWarp(pos)
  if state.prevRayPos and state.prevRayPos.y * pos.y < 0 then
    local t = state.prevRayPos.y / (state.prevRayPos.y - pos.y)
    local x = state.prevRayPos.x + (pos.x - state.prevRayPos.x) * t
    local z = state.prevRayPos.z + (pos.z - state.prevRayPos.z) * t
    if x * x + z * z < settings.FlipRadius * settings.FlipRadius then
      state.universeSign = -state.universeSign
    end
  end
  state.prevRayPos = pos
end

local function RoundedRect(
x1,
  y1,
  x2,
  y2,
  rx,
  ry,
  useTexCoords,
  colorTop,
  colorBottom
)
  rx = Min(rx, (x2 - x1) * 0.5, (y2 - y1) * 0.5)
  ry = Min(ry, (x2 - x1) * 0.5, (y2 - y1) * 0.5)
  local w, h = x2 - x1, y2 - y1
  glBeginEnd(GL.POLYGON, function()
    local function corner(x, y)
      if colorTop and colorBottom then
        local u = h > 0 and (y - y1) / h or 0
        glColor(
          colorTop[1] + (colorBottom[1] - colorTop[1]) * u,
          colorTop[2] + (colorBottom[2] - colorTop[2]) * u,
          colorTop[3] + (colorBottom[3] - colorTop[3]) * u,
          colorTop[4] + (colorBottom[4] - colorTop[4]) * u
        )
      end
      if useTexCoords then
        glTexCoord(w > 0 and (x - x1) / w or 0, h > 0 and (y - y1) / h or 0)
      end
      glVertex(x, y)
    end
    for i = 0, 16 do
      corner(x2 - rx + Circle[i][1] * rx, y2 - ry + Circle[i][2] * ry)
    end
    for i = 0, 16 do
      corner(x1 + rx - Circle[i][2] * rx, y2 - ry + Circle[i][1] * ry)
    end
    for i = 0, 16 do
      corner(x1 + ry - Circle[i][1] * ry, y1 + ry - Circle[i][2] * ry)
    end
    for i = 0, 16 do
      corner(x2 - ry + Circle[i][2] * ry, y1 + ry - Circle[i][1] * ry)
    end
  end)
end

local function RoundRectOutline(x1, y1, x2, y2, radius, colorTop, colorBottom)
  radius = Min(radius, (x2 - x1) * 0.5, (y2 - y1) * 0.5)
  local h = y2 - y1
  glBeginEnd(GL.LINE_LOOP, function()
    local function corner(x, y)
      if colorTop and colorBottom then
        local u = h > 0 and (y - y1) / h or 0
        glColor(
          colorTop[1] + (colorBottom[1] - colorTop[1]) * u,
          colorTop[2] + (colorBottom[2] - colorTop[2]) * u,
          colorTop[3] + (colorBottom[3] - colorTop[3]) * u,
          colorTop[4] + (colorBottom[4] - colorTop[4]) * u
        )
      end
      glVertex(x, y)
    end
    for i = 0, 16 do
      corner(
        x2 - radius + Circle[i][1] * radius,
        y2 - radius + Circle[i][2] * radius
      )
    end
    for i = 0, 16 do
      corner(
        x1 + radius - Circle[i][2] * radius,
        y2 - radius + Circle[i][1] * radius
      )
    end
    for i = 0, 16 do
      corner(
        x1 + radius - Circle[i][1] * radius,
        y1 + radius - Circle[i][2] * radius
      )
    end
    for i = 0, 16 do
      corner(
        x2 - radius + Circle[i][2] * radius,
        y1 + radius - Circle[i][1] * radius
      )
    end
  end)
end

local function CircleOutline(cx, cy, r)
  glBeginEnd(GL.LINE_LOOP, function()
    for i = 0, 32 do
      local a = i * Pi / 16
      glVertex(cx + Cos(a) * r, cy + Sin(a) * r)
    end
  end)
end

local function Label(text, x, y, size, font, color)
  glColor(0, 0, 0, (color[4] or 1) * 0.6)
  glText(text, x, y - 1, size, font)
  glColor(unpack(color))
  glText(text, x, y, size, font)
end

local function EnsureScreenTexture(vx, vy)
  if not state.screenTex or state.lastViewX ~= vx or state.lastViewY ~= vy then
    if state.screenTex then
      glDeleteTexture(state.screenTex)
    end
    state.screenTex = gl.CreateTexture(vx, vy, {
      min_filter = GL_LINEAR,
      mag_filter = GL_LINEAR,
      wrap_s = GL_CLAMP,
      wrap_t = GL_CLAMP,
    })
    state.lastViewX, state.lastViewY = vx, vy
  end
end

local function DrawPanel(x1, y1, x2, y2, radius, alpha, tint)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS)
  local r, g, b = unpack(tint or { 0.05, 0.05, 0.06 })
  if state.glassShader and state.screenTex then
    local vx, vy = Spring.GetViewGeometry()
    state.glassShader:Activate()
    state.glassShader:SetUniform("u_bounds", x1, y1, x2 - x1, y2 - y1)
    state.glassShader:SetUniform("u_resolution", vx, vy)
    state.glassShader:SetUniform("u_blurRadius", 3)
    state.glassShader:SetUniform("u_colorTint", r, g, b, alpha)
    gl.Texture(state.screenTex)
    state.glassShader:SetUniform("u_screenTex", 0)
    RoundedRect(x1, y1, x2, y2, radius, radius, true)
    gl.Texture(false)
    state.glassShader:Deactivate()
  else
    RoundedRect(
      x1,
      y1,
      x2,
      y2,
      radius,
      radius,
      false,
      { r, g, b, alpha },
      { r + 0.05, g + 0.05, b + 0.05, alpha }
    )
  end
  glLineWidth(1)
  RoundRectOutline(x1, y1, x2, y2, radius, { 1, 1, 1, 0.02 }, { 1, 1, 1, 0.15 })
end

local function DrawCloseIcon(x, y, r, a)
  glColor(1, 1, 1, a)
  glLineWidth(1.5)
  glBeginEnd(GL.LINES, function()
    glVertex(x - r, y - r)
    glVertex(x + r, y + r)
    glVertex(x - r, y + r)
    glVertex(x + r, y - r)
  end)
  glLineWidth(1)
end

local function DrawGripIcon(x, y, active, scale)
  scale = scale or 1
  glColor(1, 1, 1, active and 0.8 or 0.3)
  glBeginEnd(GL.LINES, function()
    glVertex(x - 4 * scale, y + 14 * scale)
    glVertex(x - 14 * scale, y + 4 * scale)
    glVertex(x - 4 * scale, y + 10 * scale)
    glVertex(x - 10 * scale, y + 4 * scale)
    glVertex(x - 4 * scale, y + 6 * scale)
    glVertex(x - 6 * scale, y + 4 * scale)
  end)
end

local function UiBounds()
  local vx, vy = Spring.GetViewGeometry()
  return (vx - settings.uiW) * 0.5 + state.uiX, (vy - settings.uiH) * 0.5 + state.uiY, vx, vy
end

local function PreviewPos(uiX, uiY)
  return uiX + (settings.uiW - settings.prevW) * 0.5 + state.prevX, uiY + (settings.uiH - settings.prevH) * 0.5 + state.prevY
end

local function CardRect(uiX, uiY, slot)
  local row, col = math.floor((slot - 1) / 2), (slot - 1) % 2
  local startX =
    uiX + (settings.uiW - (2 * settings.cardW + settings.cardGapX)) * 0.5
  local x1 = startX + col * (settings.cardW + settings.cardGapX)
  local y2 =
    uiY + settings.uiH - settings.topPad - row * (settings.cardH + settings.cardGapY)
  return x1, y2 - settings.cardH, x1 + settings.cardW, y2
end

local function InRect(x, y, x1, y1, w, h)
  return x >= x1 and x <= x1 + w and y >= y1 and y <= y1 + h
end

local function SetShaderUniforms(shader, id, resW, resH, live, brightness)
  local fov = Spring.GetCameraFOV()
  local tanHalfFov = fov and math.tan(math.rad(fov * 0.5)) or 0.4142
  local cam = live and Spring.GetCameraVectors() or {
    forward = { 0, 0, -1 },
    right = { 1, 0, 0 },
    up = { 0, 1, 0 },
  }
  local pos = live and { Spring.GetCameraPosition() } or { 0, 0, 0 }
  local rel = live and WorldToLocal(pos[1], pos[2], pos[3]) or {
    x = settings.CenterX,
    y = settings.CenterY,
    z = settings.CenterZ,
  }
  if live then
    TrackSunWarp(rel)
  end
  local uniforms = {
    u_resolution = { resW, resH },
    u_time = { live and os.clock() - state.shaderClock or 30 },
    brightness = { brightness or 1 },
    u_camForward = cam.forward,
    u_camRight = cam.right,
    u_camUp = cam.up,
    u_camRightScaled = {
      cam.right[1] * tanHalfFov,
      cam.right[2] * tanHalfFov,
      cam.right[3] * tanHalfFov,
    },
    u_camUpScaled = {
      cam.up[1] * tanHalfFov,
      cam.up[2] * tanHalfFov,
      cam.up[3] * tanHalfFov,
    },
    u_tanHalfFov = { tanHalfFov },
    u_camPos = pos,
    u_camPos_Rs = { rel.x, rel.y, rel.z },
    u_universeSign = { live and state.universeSign or 1 },
  }
  for name, value in pairs(uniforms) do
    if state.usedUniforms[id][name] == nil then
      state.usedUniforms[id][name] =
        state.uniformList[id]:find("," .. name .. ",", 1, true) ~= nil
    end
    if state.usedUniforms[id][name] then
      shader:SetUniform(name, unpack(value))
    end
  end
end

local function RenderSkyboxToTexture(id, tex, live, w, h)
  local shader = GetSkybox(id)
  if not shader then return end
  gl.RenderToTexture(tex, function()
    gl.Clear(GL.COLOR_BUFFER_BIT, GL.DEPTH_BUFFER_BIT)
    shader:Activate()
    SetShaderUniforms(shader, id, w, h, live, 1)
    if state.fullscreenTri and state.fullscreenTri.DrawArrays then
      state.fullscreenTri:DrawArrays(GL_TRIANGLES, 3)
    else
      glBeginEnd(GL_TRIANGLES, function()
        glVertex(-1, -1)
        glVertex(3, -1)
        glVertex(-1, 3)
      end)
    end
    shader:Deactivate()
  end)
end

local function MakeThumbnail(id)
  local tex = gl.CreateTexture(256, 144, {
    fbo = true,
    min_filter = GL_LINEAR,
    mag_filter = GL_LINEAR,
    wrap_s = GL_CLAMP,
    wrap_t = GL_CLAMP,
  })
  if tex then
    RenderSkyboxToTexture(id, tex, false, 256, 144)
  end
  return tex
end

function widget:KeyPress(key, mods, isRepeat)
  if key == 112 and mods.ctrl and mods.shift then
    state.uiVisible, state.rightClickPreview, state.clickInProgress =
      not state.uiVisible,
      nil,
      false
    if state.uiVisible then
      FitUi()
    else
      state.infoPanel = false
    end
    return true
  end
  if not state.uiVisible then
    return false
  end
  if key == 27 then
    if state.infoPanel then
      state.infoPanel, state.infoTarget = false, nil
    else
      state.uiVisible, state.rightClickPreview = false, nil
    end
    return true
  end
  return false
end

function widget:IsAbove(x, y)
  state.hoverCard,
    state.hoverInfo,
    state.hoverClose,
    state.hoverMin,
    state.hoverResize,
    state.hoverResizePrev,
    state.hoverPage,
    state.hoverPageNext
  = nil, nil, false, false, false, false, false, false
  if not state.uiVisible then
    return false
  end
  local uiX, uiY = UiBounds()
  if state.infoPanel then
    local px, py = PreviewPos(uiX, uiY)
    if InRect(x, y, px, py, settings.prevW, settings.prevH) then
      if x >= px + settings.prevW - settings.ResizeGrip * settings.prevScale and y <= py + settings.ResizeGrip * settings.prevScale then
        state.hoverResizePrev = true
        return true
      end
      local r = settings.CloseR * settings.prevScale
      if x >= px + settings.prevW - 20 - r and x <= px + settings.prevW - 20 + r and y >= py + settings.prevH - 20 - r and y <= py + settings.prevH - 20 + r then
        state.hoverClose = true
      end
      return true
    end
    return true
  end
  if InRect(x, y, uiX, uiY, settings.uiW, settings.uiH) then
    if x >= uiX + settings.uiW - settings.ResizeGrip * settings.uScale and y <= uiY + settings.ResizeGrip * settings.uScale then
      state.hoverResize = true
      return true
    end
    local cx, cy = uiX + settings.uiW - 20, uiY + settings.uiH - 20
    if x >= cx - settings.closeR and x <= cx + settings.closeR and y >= cy - settings.closeR and y <= cy + settings.closeR then
      state.hoverMin = true
      return true
    end
    local pages = math.ceil(#state.list / 4)
    if pages > 1 then
      local px, py = uiX + settings.uiW * 0.5, uiY + settings.bottomPad * 0.5
      if x >= px - 75 * settings.uScale and x <= px - 45 * settings.uScale and y >= py - 15 * settings.uScale and y <= py + 15 * settings.uScale then
        state.hoverPage = true
        return true
      end
      if x >= px + 45 * settings.uScale and x <= px + 75 * settings.uScale and y >= py - 15 * settings.uScale and y <= py + 15 * settings.uScale then
        state.hoverPageNext = true
        return true
      end
    end
    local first = (state.page - 1) * 4 + 1
    for i = first, Min(#state.list, first + 3) do
      local entry = state.list[i]
      local slot = i - first + 1
      local x1, y1, x2, y2 = CardRect(uiX, uiY, slot)
      if InRect(x, y, x1, y1, settings.cardW, settings.cardH) then
        state.hoverCard = entry.id
        local ix, iy =
          x2 - 16 * settings.uScaleX,
          y1 + settings.cardTitleH * 0.5
        if x >= ix - settings.infoIconR and x <= ix + settings.infoIconR and y >= iy - settings.infoIconR and y <= iy + settings.infoIconR then
          state.hoverInfo = entry.id
        end
        break
      end
    end
    return true
  end
  return false
end

function widget:MousePress(x, y, button)
  if not state.uiVisible then
    return false
  end
  local uiX, uiY = UiBounds()
  if state.infoPanel then
    local px, py = PreviewPos(uiX, uiY)
    if button == 1 then
      if InRect(x, y, px, py, settings.prevW, settings.prevH) then
        if state.hoverResizePrev then
          state.resizingPreview, state.dragStartX, state.dragStartY = true, x, y
          state.resizeStartX, state.resizeStartY =
            settings.prevScaleX,
            settings.prevScaleY
          state.dragW, state.dragH, state.dragOffX, state.dragOffY =
            settings.prevW,
            settings.prevH,
            state.prevX,
            state.prevY
          return true
        end
        local r = settings.CloseR * settings.prevScale
        if x >= px + settings.prevW - 20 - r and x <= px + settings.prevW - 20 + r and y >= py + settings.prevH - 20 - r and y <= py + settings.prevH - 20 + r then
          state.infoPanel, state.infoTarget = false, nil
          return true
        end
        state.dragPreview,
          state.dragStartX,
          state.dragStartY,
          state.dragOffX,
          state.dragOffY
        = true, x, y, state.prevX, state.prevY
        return true
      end
      return true
    end
    state.clickInProgress = true
    return true
  end
  if InRect(x, y, uiX, uiY, settings.uiW, settings.uiH) then
    state.clickInProgress = true
    if button == 1 and state.hoverResize then
      state.resizingUi, state.dragStartX, state.dragStartY = true, x, y
      state.resizeStartX, state.resizeStartY =
        settings.uScaleX,
        settings.uScaleY
      state.dragW, state.dragH, state.dragOffX, state.dragOffY =
        settings.uiW,
        settings.uiH,
        state.uiX,
        state.uiY
      return true
    end
    if button == 1 and state.hoverMin then
      state.uiVisible, state.rightClickPreview = false, nil
      return true
    end
    if button == 1 and state.hoverPage then
      if state.page > 1 then
        state.page = state.page - 1
      end
      return true
    end
    if button == 1 and state.hoverPageNext then
      if state.page < math.ceil(#state.list / 4) then
        state.page = state.page + 1
      end
      return true
    end
    if button == 1 and state.hoverInfo then
      state.infoTarget, state.infoPanel, state.prevX, state.prevY =
        state.hoverInfo,
        true,
        0,
        0
      ScalePreview(1, 1)
      return true
    end
    if state.hoverCard then
      if button == 1 then
        state.activeSky = state.hoverCard
      elseif button == 3 then
        state.rightClickPreview = state.hoverCard
      end
    end
    if button == 1 then
      state.dragUi,
        state.dragStartX,
        state.dragStartY,
        state.dragOffX,
        state.dragOffY
      = true, x, y, state.uiX, state.uiY
    end
    return true
  end
  return false
end

function widget:MouseRelease(x, y, button)
  if state.resizingPreview then
    state.resizingPreview = false
  end
  if state.resizingUi then
    state.resizingUi = false
  end
  if state.dragPreview then
    state.dragPreview = false
  end
  if state.dragUi then
    state.dragUi = false
  end
  if state.clickInProgress then
    state.clickInProgress = false
    if button == 3 and state.rightClickPreview then
      state.rightClickPreview = nil
    end
    return true
  end
  return false
end

function widget:MouseMove(x, y, dx, dy, button)
  if state.resizingPreview then
    ScalePreview(
      state.resizeStartX + (x - state.dragStartX) / settings.PreviewW,
      state.resizeStartY + (state.dragStartY - y) / settings.PreviewH
    )
    state.prevX, state.prevY =
      state.dragOffX + (settings.prevW - state.dragW) * 0.5,
      state.dragOffY - (settings.prevH - state.dragH) * 0.5
    return true
  end
  if state.resizingUi then
    ScaleUi(
      state.resizeStartX + (x - state.dragStartX) / settings.UiW,
      state.resizeStartY + (state.dragStartY - y) / settings.UiH
    )
    state.uiX, state.uiY =
      state.dragOffX + (settings.uiW - state.dragW) * 0.5,
      state.dragOffY - (settings.uiH - state.dragH) * 0.5
    return true
  end
  if state.dragPreview then
    state.prevX, state.prevY =
      state.dragOffX + x - state.dragStartX,
      state.dragOffY + y - state.dragStartY
    return true
  end
  if state.dragUi then
    state.uiX, state.uiY =
      state.dragOffX + x - state.dragStartX,
      state.dragOffY + y - state.dragStartY
    return true
  end
  return state.clickInProgress
end

function widget:MouseWheel()
  if not state.uiVisible then
    return false
  end
  local uiX, uiY = UiBounds()
  local x, y = Spring.GetMouseState()
  return InRect(x, y, uiX, uiY, settings.uiW, settings.uiH)
end

function widget:DrawScreen()
  if not state.uiVisible or state.rightClickPreview then return end
  local uiX, uiY, vx, vy = UiBounds()
  EnsureScreenTexture(vx, vy)
  if state.screenTex then
    pcall(gl.CopyToTexture, state.screenTex, 0, 0, 0, 0, vx, vy)
  end
  if #state.thumbQueue > 0 then
    local id = table.remove(state.thumbQueue, 1)
    state.thumbs[id] = MakeThumbnail(id)
  end
  if state.hoverCard and state.hoverCard ~= None and state.thumbs[state.hoverCard] then
    RenderSkyboxToTexture(
      state.hoverCard,
      state.thumbs[state.hoverCard],
      true,
      256,
      144
    )
  end
  DrawPanel(
    uiX,
    uiY,
    uiX + settings.uiW,
    uiY + settings.uiH,
    16 * settings.uScale,
    0.75,
    { 0.02, 0.02, 0.02 }
  )
  DrawCloseIcon(
    uiX + settings.uiW - 20,
    uiY + settings.uiH - 20,
    settings.CloseClickR * settings.uScale,
    state.hoverMin and 1 or 0.3
  )
  DrawGripIcon(
    uiX + settings.uiW,
    uiY,
    state.hoverResize or state.resizingUi,
    settings.uScale
  )

  local first = (state.page - 1) * 4 + 1
  for i = first, Min(#state.list, first + 3) do
    local entry = state.list[i]
    local slot = i - first + 1
    local x1, y1, x2, y2 = CardRect(uiX, uiY, slot)
    local hovering, selected =
      state.hoverCard == entry.id,
      state.activeSky == entry.id
    local titleY = y1 + settings.cardTitleH
    RoundedRect(
      x1,
      y1,
      x2,
      titleY,
      0,
      10 * settings.uScale,
      false,
      { 0.05, 0.05, 0.05, 0.6 },
      { 0.12, 0.12, 0.12, 0.6 }
    )
    if entry.id == None then
      glColor(0.01, 0.01, 0.01, 0.8)
      RoundedRect(x1, titleY, x2, y2, 10 * settings.uScale, 0)
    elseif state.thumbs[entry.id] then
      glColor(1, 1, 1, 1)
      gl.Texture(state.thumbs[entry.id])
      RoundedRect(x1, titleY, x2, y2, 10 * settings.uScale, 0, true)
      gl.Texture(false)
    else
      glColor(0.05, 0.05, 0.05, 0.8)
      RoundedRect(x1, titleY, x2, y2, 10 * settings.uScale, 0)
    end
    if hovering and not selected then
      glColor(1, 1, 1, 0.05)
      RoundedRect(x1, y1, x2, y2, 10 * settings.uScale, 10 * settings.uScale)
    end
    if selected then
      glLineWidth(1.5)
      RoundRectOutline(
        x1,
        y1,
        x2,
        y2,
        10 * settings.uScale,
        { 0.1, 0.4, 0.8, 0.8 },
        { 0.5, 0.8, 1, 1 }
      )
      glLineWidth(1)
    else
      glLineWidth(1)
      RoundRectOutline(
        x1,
        y1,
        x2,
        y2,
        10 * settings.uScale,
        { 1, 1, 1, 0.02 },
        { 1, 1, 1, 0.15 }
      )
    end
    Label(
      entry.name,
      x1 + settings.cardW * 0.5,
      y1 + settings.cardTitleH * 0.5,
      settings.CardFont * settings.uScale,
      "cv",
      { 1, 1, 1, selected and 1 or 0.7 }
    )
    local ix, iy = x2 - 16 * settings.uScaleX, y1 + settings.cardTitleH * 0.5
    local infoHover = state.hoverInfo == entry.id
    glColor(1, 1, 1, infoHover and 0.4 or 0.1)
    CircleOutline(ix, iy, settings.infoIconR)
    Label("i", ix, iy, settings.InfoIconFont * settings.uScale, "cv", {
      1,
      1,
      1,
      infoHover and 1 or 0.4,
    })
  end

  local pages = math.ceil(#state.list / 4)
  if pages > 1 then
    local py, px = uiY + settings.bottomPad * 0.5, uiX + settings.uiW * 0.5
    Label(
      "Page " .. state.page .. " / " .. pages,
      px,
      py,
      14 * settings.uScale,
      "cv",
      { 1, 1, 1, 0.8 }
    )
    Label("<", px - 60 * settings.uScale, py, 16 * settings.uScale, "cv", {
      1,
      1,
      1,
      state.hoverPage and 1 or 0.5,
    })
    Label(">", px + 60 * settings.uScale, py, 16 * settings.uScale, "cv", {
      1,
      1,
      1,
      state.hoverPageNext and 1 or 0.5,
    })
  end

  if state.infoPanel then
    local px, py = PreviewPos(uiX, uiY)
    DrawPanel(
      px,
      py,
      px + settings.prevW,
      py + settings.prevH,
      16 * settings.prevScale,
      0.75,
      { 0.01, 0.01, 0.01 }
    )
    DrawCloseIcon(
      px + settings.prevW - 20,
      py + settings.prevH - 20,
      settings.CloseClickR * settings.prevScale,
      state.hoverClose and 1 or 0.3
    )
    DrawGripIcon(
      px + settings.prevW,
      py,
      state.hoverResizePrev or state.resizingPreview,
      settings.prevScale
    )
    if state.infoTarget then
      local entry
      for _, e in ipairs(state.list) do
        if e.id == state.infoTarget then
          entry = e
          break
        end
      end
      if entry then
        local titleY = py + settings.prevH - settings.PreviewPadTop
        Label(
          entry.name,
          px + settings.prevW * 0.5,
          titleY,
          settings.PreviewTitleFont * settings.prevScale,
          "cv",
          { 1, 1, 1, 1 }
        )
        if entry.id ~= None then
          local imgX, imgY =
            px + (settings.prevW - settings.prevImgW) * 0.5,
            titleY - settings.PreviewTitleGap - settings.prevImgH
          RenderSkyboxToTexture(state.infoTarget, state.infoTex, true, 512, 288)
          glColor(1, 1, 1, 1)
          gl.Texture(state.infoTex)
          RoundedRect(
            imgX,
            imgY,
            imgX + settings.prevImgW,
            imgY + settings.prevImgH,
            10 * settings.prevScale,
            10 * settings.prevScale,
            true
          )
          gl.Texture(false)
          glLineWidth(1)
          RoundRectOutline(
            imgX,
            imgY,
            imgX + settings.prevImgW,
            imgY + settings.prevImgH,
            10 * settings.prevScale,
            { 1, 1, 1, 0.02 },
            { 1, 1, 1, 0.2 }
          )
          local labelY, spacing =
            imgY - settings.PreviewImgGap,
            settings.PreviewFontSpacing * settings.prevScale
          local function InfoLine(text, value, y)
            Label(
              text .. " " .. value,
              px + settings.prevW * 0.5,
              y,
              settings.PreviewLabelFont * settings.prevScale,
              "cv",
              { 0.85, 0.85, 0.85, 1 }
            )
          end
          InfoLine("Shader Author:", entry.shaderAuthor, labelY)
          InfoLine("File Author:", entry.fileAuthor, labelY - spacing)
          InfoLine("License:", entry.license, labelY - spacing * 2)
          InfoLine("Source:", entry.source, labelY - spacing * 3)
        else
          Label(
            "No additional information available.",
            px + settings.prevW * 0.5,
            py + settings.prevH * 0.5,
            settings.PreviewEmptyFont * settings.prevScale,
            "cv",
            { 1, 1, 1, 0.6 }
          )
        end
      end
    end
  end
end

function widget:GetConfigData()
  return { activeSkyboxId = state.activeSky }
end

function widget:SetConfigData(data)
  state.activeSky = data and data.activeSkyboxId or None
  state.fadeLast, state.fadeOn = state.activeSky, false
  ScaleUi(1, 1)
  ScalePreview(1, 1)
end

function widget:Initialize()
  state.shaderClock, state.fullscreenTri, state.infoTex =
    os.clock(),
    gl.GetVAO and gl.GetVAO(),
    gl.CreateTexture(512, 288, {
      fbo = true,
      min_filter = GL_LINEAR,
      mag_filter = GL_LINEAR,
      wrap_s = GL_CLAMP,
      wrap_t = GL_CLAMP,
    })
  local skyVert = VFS.LoadFile("LuaUI/Shaders/Skybox430.vert")
  if skyVert then
    state.skyVert = PrependVersion(skyVert)
  end
  ScanShaders()

  state.glassShader = gl.LuaShader(
    {
      vertex = "#version 150 compatibility\nout vec2 v_uv;void main(){v_uv=gl_MultiTexCoord0.xy;gl_Position=gl_ModelViewProjectionMatrix*gl_Vertex;}",
      fragment = "#version 150 compatibility\nuniform sampler2D u_screenTex;uniform vec4 u_bounds,u_colorTint;uniform vec2 u_resolution;uniform float u_blurRadius;in vec2 v_uv;out vec4 fragColor;float rand(vec2 co){return fract(sin(dot(co.xy,vec2(12.9898,78.233)))*43758.5453);}void main(){vec2 sP=vec2(u_bounds.x+v_uv.x*u_bounds.z,u_bounds.y+v_uv.y*u_bounds.w);vec2 sU=sP/u_resolution;vec4 C=vec4(0.0);float t=0.0;vec2 tx=1.0/u_resolution;for(float x=-3.0;x<=3.0;x+=1.0){for(float y=-3.0;y<=3.0;y+=1.0){float w=1.0-(length(vec2(x,y))/4.24);if(w>0.0){C+=texture(u_screenTex,sU+vec2(x,y)*tx*u_blurRadius)*w;t+=w;}}}C/=t;float n=(rand(sU)-0.5)*0.05;float s=smoothstep(0.0,2.0,v_uv.x+v_uv.y);vec3 fT=mix(u_colorTint.rgb,vec3(1.0),s*0.05);fragColor=vec4(mix(C.rgb,fT,u_colorTint.a)+vec3(n),1.0);}",
    },
    "GlassUI"
  )
  if state.glassShader then
    state.glassShader:Initialize()
  end

  if state.skyVert then
    local fade = gl.LuaShader(
      {
        vertex = state.skyVert,
        fragment = "#version 430\nuniform sampler2D u_src;uniform float u_a;in vec2 uv;out vec4 fragColor;void main(){fragColor=vec4(texture(u_src,uv).rgb,u_a);}",
      },
      "SkyboxFade"
    )
    if fade then
      if fade:Initialize() then
        state.fadeShader = fade
      else
        fade:Finalize()
      end
    end
  end

  for _, entry in ipairs(state.list) do
    if entry.id ~= None then
      state.shaders[entry.id] = CompileSkybox(entry.id)
      table.insert(state.thumbQueue, entry.id)
    end
  end

  widgetHandler:AddAction("bars_toggle_ui", function()
    state.uiVisible, state.rightClickPreview, state.clickInProgress =
      not state.uiVisible,
      nil,
      false
    if state.uiVisible then
      FitUi()
    else
      state.infoPanel = false
    end
  end)
  state.initialized = true
end

function widget:Shutdown()
  widgetHandler:RemoveAction("bars_toggle_ui")
  for _, shader in pairs(state.shaders) do
    if shader then
      shader:Finalize()
    end
  end
  state.shaders = {}
  for _, tex in pairs(state.thumbs) do
    if tex then
      glDeleteTexture(tex)
    end
  end
  state.thumbs = {}
  if state.infoTex then
    glDeleteTexture(state.infoTex)
    state.infoTex = nil
  end
  if state.screenTex then
    glDeleteTexture(state.screenTex)
    state.screenTex = nil
  end
  if state.glassShader then
    state.glassShader:Finalize()
    state.glassShader = nil
  end
  if state.fadeShader then
    state.fadeShader:Finalize()
    state.fadeShader = nil
  end
  if state.fadeSnap then
    glDeleteTexture(state.fadeSnap)
    state.fadeSnap = nil
  end
  state.fadeSnapW, state.fadeSnapH = 0, 0
  if state.fullscreenTri and state.fullscreenTri.Delete then
    state.fullscreenTri:Delete()
    state.fullscreenTri = nil
  end
  state.initialized = false
end

local function FadeFactor(now)
  local t = (now - state.fadeStart) / state.fadeDuration
  if t < 0 then
    t = 0
  elseif t > 1 then
    t = 1
  end
  return t * t * (3 - 2 * t)
end

local function DrawSkybox(shader, id, width, height)
  local ok = pcall(function()
    shader:Activate()
    SetShaderUniforms(shader, id, width, height, true, 1)
    if state.fullscreenTri and state.fullscreenTri.DrawArrays then
      state.fullscreenTri:DrawArrays(GL_TRIANGLES, 3)
    else
      glBeginEnd(GL_TRIANGLES, function()
        glVertex(-1, -1)
        glVertex(3, -1)
        glVertex(-1, 3)
      end)
    end
    shader:Deactivate()
  end)
  if not ok then
    pcall(function()
      shader:Deactivate()
    end)
  end
  return ok
end

local function EnsureFadeTexture(w, h)
  if state.fadeSnap and state.fadeSnapW == w and state.fadeSnapH == h then
    return true
  end
  if state.fadeSnap then
    glDeleteTexture(state.fadeSnap)
    state.fadeSnap = nil
  end
  state.fadeSnap = gl.CreateTexture(w, h, {
    min_filter = GL_LINEAR,
    mag_filter = GL_LINEAR,
    wrap_s = GL_CLAMP,
    wrap_t = GL_CLAMP,
  })
  state.fadeSnapW, state.fadeSnapH = w, h
  return state.fadeSnap ~= nil
end

local function CompositeFade(texture, alpha)
  if not state.fadeShader or not texture then return end
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS)
  gl.Texture(texture)
  state.fadeShader:Activate()
  state.fadeShader:SetUniform("u_src", 0)
  state.fadeShader:SetUniform("u_a", alpha)
  if state.fullscreenTri and state.fullscreenTri.DrawArrays then
    state.fullscreenTri:DrawArrays(GL_TRIANGLES, 3)
  else
    glBeginEnd(GL_TRIANGLES, function()
      glVertex(-1, -1)
      glVertex(3, -1)
      glVertex(-1, 3)
    end)
  end
  state.fadeShader:Deactivate()
  gl.Texture(false)
end

function widget:DrawWorldPreUnit()
  if not state.initialized then return end
  local target = state.rightClickPreview or state.activeSky
  local vx, vy, viewPosX, viewPosY = Spring.GetViewGeometry()
  if viewPosX ~= 0 or viewPosY ~= 0 then return end
  if not vx or vx < 1 or not vy or vy < 1 then return end
  local now = os.clock()

  if target ~= state.fadeLast then
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(false)
    glBlending(false)
    if state.fadeOn then
      local prev = GetSkybox(state.fadeLast)
      if prev then
        DrawSkybox(prev, state.fadeLast, vx, vy)
      end
      CompositeFade(state.fadeSnap, 1 - FadeFactor(now))
    elseif state.fadeLast ~= None then
      local prev = GetSkybox(state.fadeLast)
      if prev then
        DrawSkybox(prev, state.fadeLast, vx, vy)
      end
    end
    local ok = EnsureFadeTexture(vx, vy)
    if ok then
      ok = pcall(gl.CopyToTexture, state.fadeSnap, 0, 0, 0, 0, vx, vy)
    end
    if ok then
      state.fadeStart = now
      state.fadeOn = true
    else
      state.fadeOn = false
    end
    state.fadeLast = target
    glBlending(GL_SRC_ALPHA, GL_ONE_MINUS)
    gl.DepthTest(true)
    gl.DepthMask(true)
  end

  if state.fadeOn and now - state.fadeStart >= state.fadeDuration then
    state.fadeOn = false
  end
  if state.fadeOn and (not state.fadeSnap or state.fadeSnapW ~= vx or state.fadeSnapH ~= vy) then
    state.fadeOn = false
  end
  if target == None and not state.fadeOn then return end
  local shader = GetSkybox(target)
  if not shader and not state.fadeOn then return end

  gl.DepthTest(GL.LEQUAL)
  gl.DepthMask(false)
  glBlending(false)
  if shader then
    local ok = DrawSkybox(shader, target, vx, vy)
    if not ok then
      state.activeSky, state.rightClickPreview, state.fadeOn, state.fadeLast =
        None,
        nil,
        false,
        None
      glBlending(GL_SRC_ALPHA, GL_ONE_MINUS)
      gl.DepthTest(true)
      gl.DepthMask(true)
      return
    end
  end
  if state.fadeOn and state.fadeSnap then
    CompositeFade(state.fadeSnap, 1 - FadeFactor(now))
  end
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS)
  gl.DepthTest(true)
  gl.DepthMask(true)
end
