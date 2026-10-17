local U = require('src/utils')
local Theme = require('src/theme')
local M = {}
local LAYERS = 24
local vertices = {}
for i = 0,35 do
  local angle = 2*math.pi*i/36
  vertices[#vertices+1] = {math.cos(angle),math.sin(angle)}
end

-- Incremental alpha keeps the soft radial glow within the intended opacity,
-- rather than accumulating opaque nested discs over the readout.
function M.draw(center, scale, state, settings, palette, radiusX, radiusY)
  local wake = state.slipstream
  if settings.gt7SlipstreamBackground == false or not wake or not wake.available then return end
  local intensity = U.clamp(wake.intensity or 0,0,1)
  if intensity <= 0.001 then return end
  radiusY = radiusY or radiusX
  -- Telemetry advances the pulse phase smoothly as wake intensity changes.
  local phase = wake.pulsePhase or 0.5
  local pulse = 0.38+0.62*(1-math.cos(2*math.pi*phase))*0.5
  local opacity = 0.52*intensity*pulse
  local spread = 1.10+0.13*intensity
  local previous = 0
  for i = LAYERS,1,-1 do
    local fraction = i/LAYERS
    local target = opacity*(1-((i-0.5)/LAYERS)^2)^2
    local alpha = (target-previous)/(1-previous)
    local ink = Theme.withAlpha(palette.amber,alpha)
    if radiusX == radiusY then
      ui.drawCircleFilled(center,radiusX*spread*fraction*scale,ink,48)
    else
      ui.pathClear()
      for _,v in ipairs(vertices) do
        ui.pathLineTo(center+vec2(v[1]*radiusX*spread*fraction*scale,
          v[2]*radiusY*spread*fraction*scale))
      end
      ui.pathFillConvex(ink)
    end
    previous = target
  end
end

return M
