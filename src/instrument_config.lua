-- Visual dimensions are in the existing GT7 design space, before window fit.
-- Semantic colors come from src/theme; this module never owns telemetry.
local M = {
  modeTransition = 0.15,
  lightTransition = 0.22,
  fuelWarning = 0.15,
  boostWarning = 0.9,
  vacuumMinimum = -0.5,
  dial = {
    lightRadius = 154, innerRadius = 91,
    innerTickLength = 4, innerTickWidth = 0.8, innerDotRadius = 2,
    tickRadius = 150, numberRadius = 123, numberBandWidth = 27, tickMajor = 16, tickMinor = 5,
    tickWidth = 4, minorWidth = 0.8, subdivisions = 10,
    numberSize = 19, denseNumberSize = 16, unitSize = 13,
    valueSize = 56, rpmValueSize = 48, valueWidth = 180, valueY = -10,
    segmentCount = 40, segmentRadius = 151, segmentDepth = 11, segmentGap = 0.24,
    glowAlpha = 0.08, glowWidth = 5,
    coldStart = math.rad(140), coldEnd = math.rad(270),
  },
  sub = {
    offsetY = 106, radius = 59, housingRadius = 70,
    startAngle = math.rad(205), endAngle = math.rad(335),
    analogRadius = 65, analogStart = math.rad(190), analogEnd = math.rad(350),
    segmentCount = 12, segmentDepth = 8, segmentGap = 0.19,
    needleLength = 55, tickMajor = 9, tickMinor = 3, divisions = 40,
    tickWidth = 2.4, minorWidth = 0.65, majorEvery = 10,
    iconY = 8, iconScale = 0.85, labelY = 35, labelSize = 10, endSize = 12,
  },
  needle = {
    length = 113, width = 6.5, tipWidth = 0.6, borderWidth = 0.75,
    counterweightLength = 22, counterweightWidth = 4,
    scale = 1, offset = 0, opacity = 1, glow = 0.08,
    color = 'primary', edge = 'outline', illumination = 'backlight',
    hubRadius = 10, hubShape = 'round', hubCenter = 'metal',
  },
}

M.needleOrder = { 'classic', 'skeleton', 'open_ring', 'balanced', 'lollipop',
  'arrowhead', 'twin_arm', 'paddle', 'minimal' }
M.needleNames = { classic = 'Classic Taper', skeleton = 'Skeleton / Cutout',
  open_ring = 'Open Ring / Loop', balanced = 'Balanced', lollipop = 'Lollipop / Instrument',
  arrowhead = 'Arrowhead', twin_arm = 'Twin Arm', paddle = 'Paddle', minimal = 'Minimal Taper' }

local overrides = {
  classic = { body = 'taper', counterweight = 'bar' },
  skeleton = { body = 'cutout', width = 10, counterweight = 'slot', hubCenter = 'primary' },
  open_ring = { body = 'loop', width = 4, counterweight = 'ring', hubShape = 'open' },
  balanced = { body = 'taper', width = 5, counterweight = 'block',
    counterweightLength = 34, counterweightWidth = 8 },
  lollipop = { body = 'line', width = 2, tip = 'ring', counterweight = 'bar', hubRadius = 8 },
  arrowhead = { body = 'line', width = 2.5, tip = 'arrow', counterweight = 'diamond' },
  twin_arm = { body = 'twin', width = 8, counterweight = 'slot', hubCenter = 'primary' },
  paddle = { body = 'paddle', width = 11, counterweight = 'disc', hubCenter = 'primary' },
  minimal = { body = 'taper', width = 2, tipWidth = 0.35,
    counterweight = 'bar', counterweightLength = 12, counterweightWidth = 1.5, hubRadius = 7 },
}
M.needles = {}
M.needleChoices = {}
for _, id in ipairs(M.needleOrder) do
  local preset = {}
  for key, value in pairs(M.needle) do preset[key] = value end
  for key, value in pairs(overrides[id]) do preset[key] = value end
  M.needles[id] = preset
  M.needleChoices[#M.needleChoices + 1] = { label = M.needleNames[id], value = id }
end
M.subNeedle = {}
for key, value in pairs(M.needles.classic) do M.subNeedle[key] = value end
M.subNeedle.length, M.subNeedle.width = M.sub.needleLength, 2.5
M.subNeedle.counterweightLength, M.subNeedle.counterweightWidth = 6, 1.5
M.subNeedle.hubRadius = 4

function M.needlePreset(id)
  return M.needles[id] or M.needles.classic
end

return M
