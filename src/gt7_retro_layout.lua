local DialLayout = require('src/layout')

-- Classic remains the public source of GT7 telemetry constants. Keep these
-- values stable so existing consumers such as src/telemetry.lua do not depend
-- on whichever visual composition Premium currently resolves.
local Classic = {
  id = 'classic',
  frameStyle = 'classic',
  centerStyle = 'classic',
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
  indicatorLeftX = 460,
  indicatorRightX = 980,
  indicatorY = 260,
  radarArcLeftX = 440,
  radarArcRightX = 1000,
  radarArcY = 268,
  radarArcFirstRadius = 24,
  radarArcRadiusStep = 16,
  readoutLeft = nil,
  readoutRight = nil,
  readoutTop = nil,
  readoutBottom = nil,
  readoutDividerX = nil,
  debugLeft = 445,

  leftFuelStatusOffset = -132,
  leftTcStatusOffset = -74,
  leftPitStatusOffset = 84,
  leftLimiterStatusOffset = 142,
  rightAbsStatusOffset = -142,
  rightLightsStatusOffset = -84,
  rightBrakeStatusOffset = 74,
  rightEngineStatusOffset = 132,

  -- Side radar thresholds are telemetry constants, independent from the
  -- selected Premium radar presentation.
  radarRange = 18,
  radarNearRange = 10,
  radarAlongsideRange = 8,
  radarFrontAllowance = 5,
  radarMinLateral = 0.55,
  radarMaxLateral = 7.5,
  radarBlinkPeriod = 0.24,

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
  fuelNeedleSpring = 18,
  fuelNeedleDamping = 5.4,
  fuelNeedleMaxVelocity = 0.55,
  fuelNeedleGResponse = 0.032,
  fuelNeedleRoadSloshMultiplier = 2.0,
  fuelSloshFilterRate = 5.5,
  fuelSloshLateralWeight = 0.45,
  fuelSloshMaxG = 2.2,

  ffbCenterY = 408,
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
  limitSlipRatioAtLimit = 0.15,
  limitSlipAngleAtLimit = math.rad(8),
  limitMinimumLoadFraction = 0.08,
  limitPeakContribution = 0.88,
  historyGridRows = 4,
  historyGridColumns = 6,

  pedalTop = 171,
  pedalHeight = 284,
  pedalWidth = 29,
  pedalSegments = 12,
  pedalGap = 3,
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

local function copy(source)
  local result = {}
  for key, value in pairs(source) do result[key] = value end
  return result
end

local function frame(id, overrides)
  local result = copy(Classic)
  for key, value in pairs(overrides or {}) do result[key] = value end
  result.id = id
  result.frameStyle = id
  result.centerStyle = id == 'outer_pedals' and 'outer' or id
  return result
end

local frames = {
  classic = frame('classic'),
  modern = frame('modern', {
    centerTop = 78, centerBottom = 302, centerBackdropBottomInset = 20,
    indicatorY = 273,
  }),
  outer_pedals = frame('outer_pedals', {
    width = 1560,
    leftCenterX = 235, rightCenterX = 1325,
    centerLeft = 480, centerRight = 1080, centerBottom = 300,
    centerBackdropBottomInset = 24,
    indicatorLeftX = 520, indicatorRightX = 1040, indicatorY = 273,
    radarArcLeftX = 500, radarArcRightX = 1060,
    debugLeft = 505,
  }),
  steering_dial = frame('steering_dial', {
    centerLeft = 408, centerRight = 1032, centerBottom = 306,
    centerBackdropBottomInset = 0,
    indicatorLeftX = 680, indicatorRightX = 832, indicatorY = 248,
    readoutLeft = 448, readoutRight = 862, readoutTop = 124, readoutBottom = 289,
    readoutDividerX = 666,
  })
}

local speedTemplates = {
  classic = { centerX = 620, centerY = 172, textSize = 76, readoutWidth = 200, unitY = 224 },
  modern = { centerX = 620, centerY = 168, textSize = 88, readoutWidth = 200, unitY = 229 },
  large = {
    centerX = 550, centerY = 194, textSize = 98, readoutWidth = 180, unitY = 258,
    labelX = 490, labelY = 136,
  }
}

local gearTemplates = {
  classic = { centerX = 875, top = 112, bottom = 244, centerY = 174, labelY = 232, halfWidth = 55, chamfer = 14 },
  modern = { centerX = 875, top = 112, bottom = 250, centerY = 176, labelY = 234, halfWidth = 55, chamfer = 14 },
  high = { centerX = 943, top = 124, bottom = 282, centerY = 191, labelY = 266, halfWidth = 55, chamfer = 14 }
}

local steeringTemplates = {
  classic = { centerX = 720, centerY = 258, halfWidth = 110, labelY = 278 },
  modern = { centerX = 720, centerY = 273, halfWidth = 140, labelY = 293 },
  dial = { centerX = 756, centerY = 248, radius = 58, labelY = 171 }
}

local lowerTemplates = {
  classic = { left = 510, right = 930, top = 332, bottom = 470, centerX = 720, radiusX = 150 },
  modern = { left = 480, right = 960, top = 320, bottom = 478, centerX = 720, radiusX = 150 },
  wide = { left = 420, right = 1020, top = 322, bottom = 478, centerX = 720, radiusX = 200 }
}

local valid = {
  gt7SpeedStyle = { classic = true, modern = true, large = true },
  gt7GearStyle = { classic = true, modern = true, high = true },
  gt7SteeringStyle = { classic = true, modern = true, dial = true },
  gt7PedalPosition = { inner = true, outer = true },
  gt7PedalStyle = { classic = true, modern = true },
  gt7RadarPresentation = { arcs = true, classic_lights = true, modern_bars = true, column_3 = true, column_9 = true },
  gt7FlagPresentation = { classic_lights = true, modern_strips = true, column_3 = true, column_9 = true },
  gt7LowerFrameStyle = { classic = true, modern = true, wide = true }
}

local defaults = {
  gt7SpeedStyle = 'classic',
  gt7GearStyle = 'classic',
  gt7SteeringStyle = 'classic',
  gt7RpmBarVisible = true,
  gt7PedalPosition = 'inner',
  gt7PedalStyle = 'classic',
  gt7RadarPresentation = 'arcs',
  gt7FlagPresentation = 'classic_lights',
  gt7LowerFrameStyle = 'classic'
}

function Classic.normalize(settings)
  local normalized = {}
  settings = settings or {}
  for key, fallback in pairs(defaults) do
    if key == 'gt7RpmBarVisible' then
      if type(settings[key]) == 'boolean' then
        normalized[key] = settings[key]
      else
        normalized[key] = fallback
      end
    else
      local value = settings[key]
      normalized[key] = valid[key][value] and value or fallback
    end
  end
  return normalized
end

function Classic.preset(id, current)
  local classicRadar = 'arcs'
  if current then
    if current.gt7RadarPresentation == 'classic_lights' or current.gt7RadarPresentation == 'arcs' then
      classicRadar = current.gt7RadarPresentation
    elseif current.gt7RadarStyle == 'lights' then
      classicRadar = 'classic_lights'
    end
  end
  local presets = {
    classic = {
      gt7SpeedStyle = 'classic', gt7GearStyle = 'classic', gt7SteeringStyle = 'classic',
      gt7RpmBarVisible = true, gt7PedalPosition = 'inner', gt7PedalStyle = 'classic',
      gt7RadarPresentation = classicRadar, gt7FlagPresentation = 'classic_lights',
      gt7LowerFrameStyle = 'classic'
    },
    modern = {
      gt7SpeedStyle = 'modern', gt7GearStyle = 'modern', gt7SteeringStyle = 'modern',
      gt7RpmBarVisible = false, gt7PedalPosition = 'inner', gt7PedalStyle = 'modern',
      gt7RadarPresentation = 'modern_bars', gt7FlagPresentation = 'modern_strips',
      gt7LowerFrameStyle = 'modern'
    },
    outer_pedals = {
      gt7SpeedStyle = 'classic', gt7GearStyle = 'classic', gt7SteeringStyle = 'classic',
      gt7RpmBarVisible = true, gt7PedalPosition = 'outer', gt7PedalStyle = 'classic',
      gt7RadarPresentation = 'column_3', gt7FlagPresentation = 'column_3',
      gt7LowerFrameStyle = 'classic'
    },
    steering_dial = {
      gt7SpeedStyle = 'large', gt7GearStyle = 'high', gt7SteeringStyle = 'dial',
      gt7RpmBarVisible = true, gt7PedalPosition = 'inner', gt7PedalStyle = 'classic',
      gt7RadarPresentation = 'column_9', gt7FlagPresentation = 'column_9',
      gt7LowerFrameStyle = 'wide'
    }
  }
  return copy(presets[id] or presets.classic)
end

local function chooseFrame(selections)
  if selections.gt7SteeringStyle == 'dial' or selections.gt7SpeedStyle == 'large' then
    return 'steering_dial'
  end
  if selections.gt7SpeedStyle == 'modern' or selections.gt7GearStyle == 'modern'
      or selections.gt7SteeringStyle == 'modern' then
    return 'modern'
  end
  if selections.gt7PedalPosition == 'outer' then return 'outer_pedals' end
  return 'classic'
end

local shiftableFrameX = {
  'leftCenterX', 'rightCenterX', 'centerLeft', 'centerRight', 'readoutLeft',
  'readoutRight', 'readoutDividerX', 'debugLeft'
}

local function shiftFrame(layout, amount)
  for _, key in ipairs(shiftableFrameX) do
    if layout[key] then layout[key] = layout[key] + amount end
  end
end

local lastKey, lastResolved

function Classic.resolve(settings)
  local selections = Classic.normalize(settings)
  local frameId = chooseFrame(selections)
  local key = table.concat({
    selections.gt7SpeedStyle, selections.gt7GearStyle, selections.gt7SteeringStyle,
    selections.gt7RpmBarVisible and '1' or '0', selections.gt7PedalPosition,
    selections.gt7PedalStyle, selections.gt7RadarPresentation,
    selections.gt7FlagPresentation, selections.gt7LowerFrameStyle, frameId
  }, '|')
  if key == lastKey then return lastResolved end

  local layout = copy(frames[frameId])
  if selections.gt7PedalPosition == 'outer' and layout.width < 1560 then
    layout.width = 1560
    shiftFrame(layout, 60)
  end
  local xShift = (layout.width - 1440) / 2

  local speed = copy(speedTemplates[selections.gt7SpeedStyle])
  speed.style = selections.gt7SpeedStyle
  if frameId == 'steering_dial' then speed.centerX = speedTemplates.large.centerX end
  speed.centerX = speed.centerX + xShift
  if speed.labelX then speed.labelX = speed.labelX + xShift end

  local gear = copy(gearTemplates[selections.gt7GearStyle])
  gear.style = selections.gt7GearStyle
  if frameId == 'steering_dial' then gear.centerX = gearTemplates.high.centerX end
  gear.centerX = gear.centerX + xShift

  local steering = copy(steeringTemplates[selections.gt7SteeringStyle])
  steering.style = selections.gt7SteeringStyle
  steering.centerX = steering.centerX + xShift

  local rpm = {
    visible = selections.gt7RpmBarVisible,
    left = 448 + xShift, right = 992 + xShift, top = 82, height = 24,
    segments = Classic.rpmSegments, gap = Classic.rpmGap, startFraction = Classic.rpmStartFraction
  }

  local pedals = {
    position = selections.gt7PedalPosition,
    style = selections.gt7PedalStyle,
    top = Classic.pedalTop, height = Classic.pedalHeight, width = Classic.pedalWidth,
    segments = Classic.pedalSegments, gap = Classic.pedalGap,
    upperExtraWidth = selections.gt7PedalStyle == 'modern' and 10 or nil
  }
  if pedals.position == 'outer' then
    pedals.brakeX, pedals.throttleX = 15, layout.width - 44
  elseif pedals.style == 'modern' then
    pedals.brakeX, pedals.throttleX = 370 + xShift, 1041 + xShift
  else
    pedals.brakeX, pedals.throttleX = 360 + xShift, 1051 + xShift
  end

  local alerts = {
    radarStyle = selections.gt7RadarPresentation,
    flagStyle = selections.gt7FlagPresentation,
    indicatorLeftX = layout.indicatorLeftX,
    indicatorRightX = layout.indicatorRightX,
    indicatorY = layout.indicatorY,
    columnLeftX = layout.centerLeft + 20,
    columnRightX = layout.centerRight - 20,
    radarArcLeftX = layout.radarArcLeftX,
    radarArcRightX = layout.radarArcRightX,
    radarArcY = layout.radarArcY,
    radarArcFirstRadius = layout.radarArcFirstRadius,
    radarArcRadiusStep = layout.radarArcRadiusStep,
    flagLampSpacing = Classic.flagLampSpacing,
    flagLampSideOffset = Classic.flagLampSideOffset,
    flagLampRadius = Classic.flagLampRadius
  }

  local lower = copy(lowerTemplates[selections.gt7LowerFrameStyle])
  lower.style = selections.gt7LowerFrameStyle
  lower.left, lower.right = lower.left + xShift, lower.right + xShift
  lower.centerX = lower.centerX + xShift

  layout.sections = {
    frame = {
      style = frameId, left = layout.centerLeft, right = layout.centerRight,
      top = layout.centerTop, bottom = layout.centerBottom
    },
    speed = speed,
    gear = gear,
    steering = steering,
    rpm = rpm,
    pedals = pedals,
    alerts = alerts,
    lower = lower
  }

  -- Flat aliases keep the established renderer helpers and any local tooling
  -- compatible while each section is now resolved independently.
  layout.speedStyle = speed.style
  layout.speedCenterX, layout.speedCenterY = speed.centerX, speed.centerY
  layout.speedTextSize, layout.speedReadoutWidth = speed.textSize, speed.readoutWidth
  layout.speedUnitY, layout.speedLabelX, layout.speedLabelY = speed.unitY, speed.labelX, speed.labelY
  layout.gearStyle = gear.style
  layout.gearPodCenterX, layout.gearPodTop, layout.gearPodBottom = gear.centerX, gear.top, gear.bottom
  layout.gearCenterY, layout.gearLabelY = gear.centerY, gear.labelY
  layout.gearPodHalfWidth, layout.gearPodChamfer = gear.halfWidth, gear.chamfer
  layout.steeringStyle = steering.style
  layout.steeringCenterX, layout.steeringCenterY = steering.centerX, steering.centerY
  layout.steeringHalfWidth, layout.steeringRadius = steering.halfWidth, steering.radius
  layout.steeringLabelY = steering.labelY
  layout.showRpmBar = rpm.visible
  layout.rpmLeft, layout.rpmRight, layout.rpmTop, layout.rpmHeight = rpm.left, rpm.right, rpm.top, rpm.height
  layout.brakeX, layout.throttleX = pedals.brakeX, pedals.throttleX
  layout.pedalUpperExtraWidth = pedals.upperExtraWidth
  layout.pedalPosition, layout.pedalStyle = pedals.position, pedals.style
  layout.indicatorLeftX, layout.indicatorRightX, layout.indicatorY = alerts.indicatorLeftX, alerts.indicatorRightX, alerts.indicatorY
  layout.radarArcLeftX, layout.radarArcRightX, layout.radarArcY = alerts.radarArcLeftX, alerts.radarArcRightX, alerts.radarArcY
  layout.radarArcFirstRadius, layout.radarArcRadiusStep = alerts.radarArcFirstRadius, alerts.radarArcRadiusStep
  layout.radarPresentation, layout.flagPresentation = alerts.radarStyle, alerts.flagStyle
  layout.verticalLampCount = alerts.radarStyle == 'column_9' and 9 or (alerts.radarStyle == 'column_3' and 3 or 0)
  layout.verticalLampLeftX, layout.verticalLampRightX = alerts.columnLeftX, alerts.columnRightX
  layout.verticalLampBottom = layout.verticalLampCount == 9 and 269 or 251
  layout.verticalLampSpacing = layout.verticalLampCount == 9 and 18 or 14
  layout.lowerFrameStyle = lower.style
  layout.historyLeft, layout.historyRight = lower.left, lower.right
  layout.historyTop, layout.historyBottom = lower.top, lower.bottom
  layout.ffbCenterX, layout.ffbRadiusX = lower.centerX, lower.radiusX
  layout.lowerFrame = true

  lastKey, lastResolved = key, layout
  return layout
end

function Classic.get(id)
  return Classic.resolve(Classic.preset(id))
end

function Classic.frameFor(settings)
  return chooseFrame(Classic.normalize(settings))
end

return Classic
