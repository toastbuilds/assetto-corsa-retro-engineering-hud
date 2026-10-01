-- Visual dimensions are in the existing GT7 design space, before window fit.
-- Semantic colors come from src/theme; this module never owns telemetry.
local M = {
  modeTransition = 0.15,
  lightTransition = 0.22,
  -- Backlight only: crisp faces keep their existing geometry. Halo radii are
  -- in design pixels, not screen pixels; opacity is deliberately much lower.
  illumination = {
    lightThemeStrength = 0.42, lightThemeHalo = 0.35,
    number = { intensity = 0.90, radius = 0.75, opacity = 0.055 },
    value = { intensity = 1, radius = 1.0, opacity = 0.065 },
    label = { intensity = 0.62, radius = 0.5, opacity = 0.025 },
    major = { intensity = 0.85, radius = 0.7, opacity = 0.07 },
    medium = { intensity = 0.48, radius = 0.35, opacity = 0.035 },
    minor = { intensity = 0.20, radius = 0, opacity = 0 },
    inner = { intensity = 0.32, radius = 0, opacity = 0 },
    icon = { intensity = 0.80, radius = 0.65, opacity = 0.05 },
    segment = { intensity = 0.85, radius = 0.55, opacity = 0.06 },
    subSegment = { intensity = 0.65, radius = 0.45, opacity = 0.045 },
    printedWarning = { intensity = 0.18, radius = 0, opacity = 0 },
    needle = { intensity = 0.96, radius = 0.75, opacity = 0.065, core = 0.28 },
    subNeedle = { intensity = 0.78, radius = 0.5, opacity = 0.045, core = 0.20 },
    hub = { intensity = 0.25, radius = 0, opacity = 0 },
    needleCoreInset = 0.32, needleCoreWidth = 0.45,
    ring = { analog = 0.20, digital = 0.28, warmRatio = 0.70,
      haloOpacity = 0.025, haloWidth = 3 },
    ambient = { opacity = 0.012, centerRadius = 78, subRadius = 43, layers = 3 },
  },
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

local Geometry = require('src/instrument_needle_geometry')
M.needle.coreInset = M.illumination.needleCoreInset
-- A–D are the asset sheets; 01–06 are their lower cards, left to right.
local catalog = {
  {'a01', 'Classic', {body='taper', width=3.5, counterweight='block', counterweightLength=35,
    counterweightWidth=6, weightLength=12, hubRadius=8, hubShape='rivet'}},
  {'a02', 'Open Ring', {body='outline', width=3, outlineWidth=0.9, counterweight='block',
    counterweightLength=35, counterweightWidth=4, weightLength=13, hubRadius=8, hubShape='open'}},
  {'a03', 'Balanced', {body='taper', width=7, counterweight='block', counterweightLength=40,
    counterweightWidth=9, weightLength=22, hubRadius=9, hubShape='rivet'}},
  {'a04', 'Paddle', {body='taper', width=6, counterweight='paddle', counterweightLength=40,
    counterweightWidth=14, hubRadius=9, hubShape='rivet'}},
  {'a05', 'Cutout', {body='slot', width=7, slotWidth=1.6, counterweight='slot',
    counterweightLength=36, counterweightWidth=6, tailTaper=1, hubRadius=9, hubShape='rivet'}},
  {'a06', 'Tapered', {body='outline', width=3.8, outlineWidth=0.7, counterweight='bar',
    counterweightLength=32, counterweightWidth=1.6, hubRadius=7, hubShape='rivet'}},
  {'b01', 'Classic Taper', {body='taper', width=8, counterweight='bar',
    counterweightLength=21, counterweightWidth=3.5, hubShape='machined'}},
  {'b02', 'Skeleton Cutout', {body='slot', width=12, slotWidth=2.5, counterweight='slot',
    counterweightLength=25, counterweightWidth=5, hubShape='machined'}},
  {'b03', 'Lollipop', {body='line', width=2.2, tip='ring', tipRadius=6,
    counterweight='bar', counterweightLength=20, counterweightWidth=3, hubShape='riveted'}},
  {'b04', 'Arrowhead', {body='line', width=2.8, tip='arrow', tipLength=16, tipRadius=8,
    counterweight='polygon', counterweightLength=27, counterweightWidth=11, hubRadius=9, hubShape='small_rivet'}},
  {'b05', 'Twin Arm', {body='twin', width=10, counterweight='slot',
    counterweightLength=24, counterweightWidth=4.5, hubShape='small_rivet'}},
  {'b06', 'Paddle Weight', {body='line', width=1.8, counterweight='bar',
    counterweightLength=25, counterweightWidth=3, hubRadius=11, hubShape='weight'}},
  {'c01', 'Rectangular Cutout Weight', {body='outline', width=5, outlineWidth=1,
    counterweight='slot', counterweightLength=48, counterweightWidth=8, tailTaper=1,
    hubRadius=11, hubShape='rivet'}},
  {'c02', 'Slotted Taper Weight', {body='taper', width=9, counterweight='slot',
    counterweightLength=37, counterweightWidth=8, hubRadius=10, hubShape='rivet'}},
  {'c03', 'Triple Perforated Weight', {body='taper', width=8, counterweight='perforated',
    counterweightLength=44, counterweightWidth=10, hubRadius=10, hubShape='rivet'}},
  {'c04', 'Disc Weight', {body='taper', width=4, counterweight='disc',
    counterweightLength=40, counterweightWidth=14, hubRadius=8, hubShape='rivet'}},
  {'c05', 'Polygon Weight', {body='taper', width=6, counterweight='polygon',
    counterweightLength=44, counterweightWidth=14, hubRadius=11, hubShape='rivet'}},
  {'c06', 'Double Cutout', {body='slot', width=9, slotWidth=2, counterweight='slot',
    counterweightLength=44, counterweightWidth=7, tailTaper=1, hubRadius=9, hubShape='rivet'}},
  {'d01', 'Outlined Blade', {body='outline', width=5, outlineWidth=1.2,
    counterweight='outline', counterweightLength=38, counterweightWidth=2.2,
    hubRadius=12, hubShape='cap'}},
  {'d02', 'Wide Skeleton', {body='slot', width=13, slotWidth=3.1, slotEnd=94,
    counterweight='outline', counterweightLength=38, counterweightWidth=2.8,
    outlineWidth=0.9, hubRadius=12, hubShape='cap'}},
  {'d03', 'Broad Lancet', {body='lancet', width=18, counterweight='outline',
    counterweightLength=37, counterweightWidth=2, outlineWidth=0.9, hubRadius=10, hubShape='open'}},
  {'d04', 'Filiform Open Ring', {body='outline', width=2.2, outlineWidth=0.65,
    counterweight='outline', counterweightLength=38, counterweightWidth=1.8,
    hubRadius=8, hubShape='open'}},
  {'d05', 'Diamond Tip', {body='outline', width=3, outlineWidth=0.9, tip='diamond',
    tipLength=23, tipRadius=6, counterweight='outline', counterweightLength=36,
    counterweightWidth=2.4, hubRadius=10, hubShape='faceted'}},
  {'d06', 'Triangular Cutout', {body='outline', width=12, outlineWidth=1.1,
    counterweight='outline', counterweightLength=39, counterweightWidth=2,
    hubRadius=12, hubShape='cap'}},
}
M.needleAliases = {classic='b01', skeleton='b02', open_ring='a02', balanced='a03',
  lollipop='b03', arrowhead='b04', twin_arm='b05', paddle='b06', minimal='a06'}
M.needleOrder, M.needleNames, M.needles, M.needleChoices = {}, {}, {}, {}
for _, entry in ipairs(catalog) do
  local id, name, overrides = entry[1], entry[2], entry[3]
  local preset = {}
  for key, value in pairs(M.needle) do preset[key] = value end
  for key, value in pairs(overrides) do preset[key] = value end
  preset.id = id
  M.needleOrder[#M.needleOrder + 1] = id
  M.needleNames[id] = id:upper() .. ' - ' .. name
  M.needles[id] = Geometry.build(preset)
  M.needleChoices[#M.needleChoices + 1] = { label = M.needleNames[id], value = id }
end
-- Frozen mini-instrument dimensions; catalog edits must not change fuel/boost.
M.subNeedle = {}
for key, value in pairs(M.needle) do M.subNeedle[key] = value end
M.subNeedle.body, M.subNeedle.counterweight, M.subNeedle.hubShape = 'taper', 'bar', 'mini'
M.subNeedle.length, M.subNeedle.width = M.sub.needleLength, 2.5
M.subNeedle.counterweightLength, M.subNeedle.counterweightWidth = 6, 1.5
M.subNeedle.hubRadius = 4
local mini = M.subNeedle
M.subNeedle.geometry = {
  {{0, -mini.width / 2}, {mini.length, -mini.tipWidth},
    {mini.length, mini.tipWidth}, {0, mini.width / 2}},
  {{-mini.counterweightLength, -mini.counterweightWidth / 2}, {0, -mini.counterweightWidth / 2},
    {0, mini.counterweightWidth / 2}, {-mini.counterweightLength, mini.counterweightWidth / 2}},
}
M.subNeedle.cores = {}
for _, points in ipairs(M.subNeedle.geometry) do
  local core = Geometry.inset(points, M.illumination.needleCoreInset)
  if core then M.subNeedle.cores[#M.subNeedle.cores + 1] = core end
end

function M.normalizeNeedleStyle(id, fallback)
  id = M.needleAliases[id] or id
  return M.needles[id] and id or (fallback or 'b01')
end

function M.needlePreset(id)
  return M.needles[M.normalizeNeedleStyle(id)]
end

return M
