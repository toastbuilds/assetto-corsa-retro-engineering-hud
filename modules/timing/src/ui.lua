local LapData = require('modules/delta/src/lap_data')
local Theme = require('modules/timing/src/theme')

local TimingUI = {}

local function point(tl, x, y)
  return tl + vec2(x, y)
end

-- CSP gradient shading replaces RGB, even when useAlpha is enabled.
-- Shade each primitive with its own RGB and multiply only its existing alpha.
function TimingUI.beginFade(fade)
  if fade then ui.beginGradientShade() end
end

function TimingUI.endFade(fade, color)
  if fade then
    ui.endGradientShade(fade.top, fade.bottom,
      rgbm(color.r, color.g, color.b, 1), rgbm(color.r, color.g, color.b, 0.2), true)
  end
end

function TimingUI.chamferRect(tl, br, chamfer, fill, stroke, strokeWidth, fade)
  local width, height = br.x - tl.x, br.y - tl.y
  local c = math.min(chamfer, math.min(width / 3, height / 3))
  local function path()
    ui.pathClear()
    ui.pathLineTo(point(tl, c, 0))
    ui.pathLineTo(point(tl, width - c, 0))
    ui.pathLineTo(point(tl, width, c))
    ui.pathLineTo(point(tl, width, height - c))
    ui.pathLineTo(point(tl, width - c, height))
    ui.pathLineTo(point(tl, c, height))
    ui.pathLineTo(point(tl, 0, height - c))
    ui.pathLineTo(point(tl, 0, c))
  end
  path()
  TimingUI.beginFade(fade)
  ui.pathFillConvex(fill)
  TimingUI.endFade(fade, fill)
  path()
  TimingUI.beginFade(fade)
  ui.pathStroke(stroke, true, strokeWidth or 1)
  TimingUI.endFade(fade, stroke)
end

function TimingUI.centeredText(text, size, center, color, fade)
  local measured = ui.measureDWriteText(tostring(text), size)
  TimingUI.beginFade(fade)
  ui.dwriteDrawText(tostring(text), size, center - measured / 2, color)
  TimingUI.endFade(fade, color)
end

function TimingUI.leftText(text, size, pos, color, fade)
  TimingUI.beginFade(fade)
  ui.dwriteDrawText(tostring(text), size, pos, color)
  TimingUI.endFade(fade, color)
end

function TimingUI.formatTime(timeMs)
  return LapData.timeToString(timeMs)
end

function TimingUI.formatDelta(timeMs)
  if timeMs == nil then return '--.--' end
  return LapData.timeDeltaToString(timeMs)
end

function TimingUI.statusColor(colors, status)
  if status == 'session_best' then return colors.purple end
  if status == 'personal_best' then return colors.green end
  if status == 'invalid' then return colors.red end
  return colors.amber
end

function TimingUI.statusDimColor(colors, status)
  if status == 'session_best' then return colors.purpleDim end
  if status == 'personal_best' then return Theme.withAlpha(colors.green, 0.28) end
  if status == 'invalid' then return colors.redDim end
  return colors.amberDim
end

function TimingUI.statusLabel(status)
  if status == 'session_best' then return 'SESSION BEST' end
  if status == 'personal_best' then return 'PERSONAL BEST' end
  if status == 'invalid' then return 'INVALID' end
  return 'VALID'
end

return TimingUI
