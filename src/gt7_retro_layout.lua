local DialLayout = require('src/layout')

-- Dedicated panoramic design space. The renderer always fits this rectangle
-- uniformly into the current CSP app window, so no coordinate depends on the
-- user's resolution and the cluster can safely coexist with the square dials.
local Classic = {
  id = 'classic',
  centerStyle = 'classic',
  showRpmBar = true,
  steeringStyle = 'linear',
  lowerFrame = false,
  verticalLampCount = 0,
  speedCenterX = 620,
  speedCenterY = 172,
  speedTextSize = 76,
  speedReadoutWidth = 200,
  speedUnitY = 224,
  gearCenterY = 174,
  gearLabelY = 232,
  steeringCenterX = 720,
  steeringCenterY = 258,
  steeringHalfWidth = 110,
  steeringLabelY = 278,
  debugLeft = 445,
  width = 1440,
  height = 500,

  leftCenterX = 175,
  rightCenterX = 1265,
  dialCenterY = 258,
  dialRadius = 174,
  tickRadius = 155,
  needleLength = 124,
  gaugeStart = math.rad(140),
  gaugeEnd = math.rad(400),
  digitalDialBarRadius = 161,
  digitalDialBarWidth = 8,
  digitalDialBarSegments = 36,
  digitalDialBarGap = 0.014,

  centerLeft = 420,
  centerRight = 1020,
  centerTop = 56,
  centerBottom = 285,
  centerBackdropChamfer = 24,
  centerBackdropBottomInset = 38,
  gearPodCenterX = 875,
  gearPodTop = 112,
  gearPodBottom = 244,
  gearPodHalfWidth = 55,
  gearPodChamfer = 14,
  leftFuelStatusOffset = -132,
  leftTcStatusOffset = -74,
  leftPitStatusOffset = 84,
  leftLimiterStatusOffset = 142,
  rightAbsStatusOffset = -142,
  rightLightsStatusOffset = -84,
  rightBrakeStatusOffset = 74,
  rightEngineStatusOffset = 132,
  indicatorLeftX = 460,
  indicatorRightX = 980,
  indicatorY = 260,
  -- Side radar thresholds. The indicator is deliberately conservative so a
  -- car directly ahead or behind does not light either side by accident.
  radarRange = 18,
  radarNearRange = 10,
  radarAlongsideRange = 8,
  radarFrontAllowance = 5,
  radarMinLateral = 0.55,
  radarMaxLateral = 7.5,
  radarBlinkPeriod = 0.24,
  radarArcLeftX = 440,
  radarArcRightX = 1000,
  radarArcY = 268,
  radarArcFirstRadius = 24,
  radarArcRadiusStep = 16,

  rpmLeft = 448,
  rpmRight = 992,
  rpmTop = 82,
  rpmHeight = 24,
  rpmSegments = 34,
  rpmGap = 3,
  rpmStartFraction = DialLayout.digitalRpmAlertStartFraction,

  speedNeedleSpring = 55,
  speedNeedleDamping = 13,
  speedNeedleMaxVelocity = 2.2,
  rpmNeedleSpring = DialLayout.analogNeedleSpring,
  rpmNeedleDamping = DialLayout.analogNeedleDamping,
  rpmNeedleMaxVelocity = DialLayout.analogNeedleMaxVelocity,
  boostNeedleSpring = 72,
  boostNeedleDamping = 13.5,
  boostNeedleMaxVelocity = 2.8,

  ffbCenterX = 720,
  ffbCenterY = 408,
  ffbRadiusX = 150,
  ffbRadiusY = 72,
  ffbStart = math.rad(195),
  ffbEnd = math.rad(345),
  ffbSegments = 20,
  ffbNeedlePivotOffsetY = 32,
  ffbNeedleSpring = 70,
  ffbNeedleDamping = 12.5,
  ffbNeedleMaxVelocity = 2.6,
  limitAmberFraction = 0.70,
  limitRedFraction = 0.90,
  limitPeakHold = 0.22,
  limitAssistHold = 0.32,
  limitAttackTime = 0.045,
  limitReleaseTime = 0.18,
  -- CSP exposes tyre slip as a normalized combined utilization where
  -- available. These are only used as a compatibility fallback when that
  -- direct signal is missing.
  limitSlipRatioAtLimit = 0.15,
  limitSlipAngleAtLimit = math.rad(8),
  limitMinimumLoadFraction = 0.08,
  limitPeakContribution = 0.88,
  historyLeft = 510,
  historyRight = 930,
  historyTop = 332,
  historyBottom = 470,
  historyGridRows = 4,
  historyGridColumns = 6,

  pedalTop = 171,
  pedalHeight = 284,
  pedalWidth = 29,
  pedalSegments = 12,
  pedalGap = 3,
  brakeX = 360,
  throttleX = 1051,
  boostStart = math.rad(135),
  boostEnd = math.rad(405),
  boostRadius = 65,
  flagLampSpacing = 12,
  flagLampSideOffset = 30,
  flagLampRadius = 4.5,

  indicatorPeriod = 0.42,
  flagBlinkPeriod = 0.42,
  shiftBlinkPeriod = 0.14,
  redlineBlinkPeriod = 0.12
}

-- Build once: drawing a different composition never changes the shared
-- telemetry constants exported by this module.
local function composition(id, overrides)
  local result = {}
  for key, value in pairs(Classic) do result[key] = value end
  for key, value in pairs(overrides) do result[key] = value end
  result.id = id
  return result
end

local Modern = composition('modern', {
  centerStyle = 'modern', showRpmBar = false, lowerFrame = true,
  centerTop = 78, centerBottom = 302, centerBackdropBottomInset = 20,
  speedCenterY = 168, speedTextSize = 88, speedUnitY = 229,
  gearPodBottom = 250, gearCenterY = 176, gearLabelY = 234,
  steeringCenterY = 273, steeringHalfWidth = 140, steeringLabelY = 293,
  indicatorY = 273,
  brakeX = 370, throttleX = 1041, pedalUpperExtraWidth = 10,
  historyLeft = 480, historyRight = 960, historyTop = 320, historyBottom = 478
})

local OuterPedals = composition('outer_pedals', {
  width = 1560, centerStyle = 'outer', lowerFrame = true,
  leftCenterX = 235, rightCenterX = 1325,
  centerLeft = 480, centerRight = 1080, centerBottom = 300,
  centerBackdropBottomInset = 24,
  gearPodCenterX = 935, speedCenterX = 680,
  steeringCenterX = 780, steeringCenterY = 273, steeringLabelY = 293,
  indicatorLeftX = 520, indicatorRightX = 1040, indicatorY = 273,
  verticalLampCount = 3, verticalLampLeftX = 500, verticalLampRightX = 1060,
  verticalLampBottom = 251, verticalLampSpacing = 14,
  rpmLeft = 508, rpmRight = 1052,
  brakeX = 15, throttleX = 1516,
  ffbCenterX = 780, historyLeft = 570, historyRight = 990,
  radarArcLeftX = 500, radarArcRightX = 1060, debugLeft = 505
})

local SteeringDial = composition('steering_dial', {
  centerStyle = 'steering_dial', steeringStyle = 'dial', lowerFrame = true,
  centerLeft = 408, centerRight = 1032, centerBottom = 306,
  centerBackdropBottomInset = 0,
  speedCenterX = 550, speedCenterY = 194, speedTextSize = 98,
  speedReadoutWidth = 180, speedUnitY = 258,
  speedLabelX = 490, speedLabelY = 136,
  readoutLeft = 448, readoutRight = 862, readoutTop = 124, readoutBottom = 289,
  readoutDividerX = 666,
  gearPodCenterX = 943, gearPodTop = 124, gearPodBottom = 282,
  gearCenterY = 191, gearLabelY = 266,
  steeringCenterX = 756, steeringCenterY = 248, steeringRadius = 58,
  steeringLabelY = 171,
  indicatorLeftX = 680, indicatorRightX = 832, indicatorY = 248,
  verticalLampCount = 9, verticalLampLeftX = 428, verticalLampRightX = 1012,
  verticalLampBottom = 269, verticalLampSpacing = 18,
  historyLeft = 420, historyRight = 1020, historyTop = 322, historyBottom = 478,
  ffbRadiusX = 200
})

local compositions = {
  classic = Classic, modern = Modern,
  outer_pedals = OuterPedals, steering_dial = SteeringDial
}

function Classic.get(id)
  return compositions[id] or Classic
end

return Classic
