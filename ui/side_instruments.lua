local Config = require('src/instrument_config')
local Presentation = require('src/instrument_state')
local Theme = require('src/theme')
local Needle = require('ui/instrument_needle')
local Light = require('ui/instrument_illumination')
local U = require('src/utils')
local Icons = require('ui/instrument_icons')
local Hybrid = require('src/hybrid')
local HybridGauge = require('ui/hybrid_gauge')
local Layout = require('src/gt7_retro_layout')
local DialStyles = require('src/gt7_dial_styles')
local StyledInstruments = require('ui/gt7_styled_instruments')
local AuxiliaryStyles = require('ui/auxiliary_dial_styles')
local MiniProfiles = require('src/mini_dial_profiles')
local MiniDial = require('ui/mini_dial')
local SlipstreamBackground = require('ui/slipstream_background')
local M = {}
local D, S = Config.dial, Config.sub
local function fuelAlertEnabled(settings)
  if settings.animateRedlineAlert~=nil then return settings.animateRedlineAlert~=false end
  return settings.animateIndicators~=false
end

local function fuelAlertAlpha(state,settings)
  if not fuelAlertEnabled(settings) then return 1 end
  return Layout.fuelWarningAlpha(state.clock)
end

local function arc(center, radius, first, last, color, width, steps)
  ui.pathClear()
  ui.pathArcTo(center, radius, first, last, steps or 32)
  ui.pathStroke(color, false, width)
end

local function text(value, size, center, color, maxWidth, style, scale)
  Light.text(value, size, center, color, maxWidth, style, scale)
end

local function blockGeometry(count, radius, depth, first, last, gap)
  local blocks = {}
  local span = (last - first) / count
  for i = 1, count do
    local a = first + (i - 1) * span + span * gap / 2
    local b = first + i * span - span * gap / 2
    local inside = radius - depth
    blocks[i] = { {radius * math.cos(a), radius * math.sin(a)},
      {radius * math.cos(b), radius * math.sin(b)},
      {inside * math.cos(b), inside * math.sin(b)},
      {inside * math.cos(a), inside * math.sin(a)} }
    if last < first then
      local block = blocks[i]
      blocks[i] = {block[4], block[3], block[2], block[1]}
    end
  end
  return blocks
end

local mainGeometries, redlineGeometries = {}, {}
local segmentGeometries = {}
local subGeometry = blockGeometry(S.segmentCount, S.radius, S.segmentDepth,
  S.startAngle, S.endAngle, S.segmentGap)
local analogSubGeometry = blockGeometry(S.segmentCount, S.analogRadius,
  S.segmentDepth, S.analogStart, S.analogEnd, S.segmentGap)
local lowerSubGeometry = blockGeometry(32, 148, 10, math.rad(150), math.rad(30), 0.20)

local scales = {}
local function scaleGeometry(maximum, step, first, last, rpm)
  local key = table.concat({maximum, step, first, last, rpm and 'rpm' or 'speed'}, '|')
  if scales[key] then return scales[key] end
  local result = { ticks = {}, labels = {} }
  local divisions = math.max(1, math.ceil(maximum / step * D.subdivisions))
  for i = 0, divisions do
    local f = math.min(i * step / D.subdivisions / maximum, 1)
    local angle = first + (last - first) * f
    local major = i % D.subdivisions == 0 or f == 1
    local inside = D.tickRadius - (major and D.tickMajor or D.tickMinor)
    result.ticks[#result.ticks + 1] = { f = f, major = major, medium = i % (D.subdivisions / 2) == 0,
      x1 = inside * math.cos(angle), y1 = inside * math.sin(angle),
      x2 = D.tickRadius * math.cos(angle), y2 = D.tickRadius * math.sin(angle),
      ix1 = (D.innerRadius - D.innerTickLength) * math.cos(angle),
      iy1 = (D.innerRadius - D.innerTickLength) * math.sin(angle),
      ix2 = D.innerRadius * math.cos(angle), iy2 = D.innerRadius * math.sin(angle) }
  end
  local function label(value)
    local a = first + (last - first) * value / maximum
    result.labels[#result.labels + 1] = { x = D.numberRadius * math.cos(a),
      y = D.numberRadius * math.sin(a), dotX = (D.innerRadius - D.innerTickLength / 2) * math.cos(a),
      dotY = (D.innerRadius - D.innerTickLength / 2) * math.sin(a), value = tostring(U.round(value)) }
  end
  local value = 0
  while value <= maximum + step * 0.01 and #result.labels < 12 do label(value); value = value + step end
  if value - step < maximum - step * 0.01 then label(maximum) end
  -- A car/unit change builds a new scale once. Bound storage for long sessions.
  local count = 0
  for _ in pairs(scales) do count = count + 1 end
  if count >= 8 then scales = {} end
  scales[key] = result
  return result
end

M.statusIcon = Icons.statusIcon
M.fuelIcon = Icons.fuelIcon
M.boostIcon = Icons.boostIcon
M.aeroIcon = Icons.aeroIcon

local function segmentGeometry(count, first, last)
  local key = table.concat({count, first, last}, '|')
  if not segmentGeometries[key] then
    segmentGeometries[key] = blockGeometry(count, D.segmentRadius, D.segmentDepth,
      first, last, D.segmentGap)
  end
  return segmentGeometries[key]
end

local function icon(draw, center, scale, base, style)
  local halo = Light.halo(base, style)
  if halo then draw(center, scale, halo, style.radius) end
  draw(center, scale, Light.color(base, style))
end

local function subGauge(center, scale, state, settings, C, digital, light, rpm, L)
  local subCenter = center + vec2(0, S.offsetY * scale)
  local style = DialStyles.auxiliaryStyle(settings, rpm)
  local hybrid = rpm and Hybrid.forGauge(state)
  if hybrid then
    HybridGauge.draw(subCenter, scale, hybrid, C, settings.theme, light, 'gt7', style, digital<0.5, digital)
    return
  end
  Light.ambient(subCenter, scale, L, true)
  if not MiniProfiles.get(style) and (digital>=0.5 or (style~='halo' and style~='jewel')) then
    arc(subCenter, S.housingRadius * scale,
      math.pi, math.pi * 2, C.metalDim, 2 * scale)
    arc(subCenter, (S.housingRadius - 3) * scale,
      math.pi, math.pi * 2, Light.color(C.outline, L.inner), 0.8 * scale)
  end
  local visual = state.gt7Instruments
  local pressure, minimum, maximum
  if visual then pressure, minimum, maximum = visual.boostValue, visual.boostMinimum, visual.boostMaximum
  else pressure, minimum, maximum = Presentation.boost(state, settings) end
  local aero = rpm and not state.turboAvailable
  local available = aero or (rpm and state.turboAvailable)
    or (not rpm and state.fuel ~= nil and state.maxFuel ~= nil)
  local displayedPressure = visual and visual.boostNeedleValue or pressure
  local fraction = aero and U.clamp(state.aeroLoadNormalized or 0, 0, 1)
    or (rpm and U.clamp((displayedPressure - minimum) / (maximum - minimum), 0, 1)
    or U.clamp(state.fuelNormalized or 0, 0, 1))
  local zero = rpm and not aero and -minimum / (maximum - minimum) or 0
  local low = not rpm and available and fraction < Config.fuelWarning
  local pulseAlpha=fuelAlertAlpha(state,settings)
  local critical=low and fraction<0.10 and fuelAlertEnabled(settings)
  local lowInk=critical and Theme.withAlpha(C.red,pulseAlpha) or C.red
  if MiniProfiles.get(style) then
    local needleValue = fraction
    if not rpm then needleValue=U.clamp(state.fuelNeedleNormalized or fraction,0,1)
    elseif not aero then
      local smoothed=visual and visual.boostNeedleValue or (state.boostNeedleNormalized or 0)*maximum
      needleValue=U.clamp((smoothed-minimum)/(maximum-minimum),0,1)
    end
    local warning=aero and 0.82 or rpm and (Config.boostWarning*maximum-minimum)/(maximum-minimum)
      or Config.fuelWarning
    local miniCenter=not rpm and subCenter-vec2(0,18*scale) or subCenter
    MiniDial.draw(style,miniCenter,scale,digital,AuxiliaryStyles.channel({
      kind=not rpm and 'fuel' or aero and 'aero' or 'boost', available=available,
      value=fraction,needleValue=needleValue,zero=zero,warning=warning,lowInk=low and lowInk or nil,
      alertInk=low and Theme.withAlpha(C.red,pulseAlpha) or nil
    },C,L),C,L,{
      left=aero and '0' or rpm and string.format('%.1f',minimum) or 'E',
      right=aero and '100' or rpm and string.format('%.1f',maximum) or 'F',
      label=not available and 'N/A' or aero and 'AERO' or rpm and 'BOOST' or 'FUEL',
      icon=aero and M.aeroIcon or rpm and M.boostIcon or M.fuelIcon
    })
    return
  end
  local function zone(f, active)
    if not available then return C.outlineDim end
    if aero then
      if not active then return C.inactive end
      return f >= 0.82 and C.amber or C.cyan
    end
    if not rpm and f <= Config.fuelWarning then return active and lowInk or C.redDim end
    if rpm and f >= (Config.boostWarning * maximum - minimum) / (maximum - minimum) then
      return active and C.red or C.redDim
    end
    if not active then return C.inactive end
    return low and lowInk or (rpm and f > zero and C.primary or C.cyan)
  end
  if style ~= 'original' then
    local warning = aero and 0.82 or rpm and (Config.boostWarning * maximum - minimum) / (maximum - minimum)
      or Config.fuelWarning
    AuxiliaryStyles.draw(style, subCenter, scale, {
      radius=S.analogRadius+(S.radius-S.analogRadius)*digital, width=8, count=10,consume=digital<0.5,
      first=S.analogStart+(S.startAngle-S.analogStart)*digital,
      last=S.analogEnd+(S.endAngle-S.analogEnd)*digital
    }, AuxiliaryStyles.channel({
      kind=not rpm and 'fuel' or aero and 'aero' or 'boost',
      available=available,value=fraction,zero=zero,marker=digital>=0.5,
      warning=warning,lowInk=low and lowInk or nil
    },C,L), C, L)
  end
  if digital > 0 and style == 'original' then
    ui.pushStyleVarAlpha(digital)
    for i, block in ipairs(subGeometry) do
      local f = (i - 0.5) / S.segmentCount
      local active
      if rpm then
        active = available and f >= math.min(zero, fraction) and f <= math.max(zero, fraction)
      else active = available and i <= math.ceil(fraction * S.segmentCount) end
      Light.segment(subCenter, scale, block, zone(f, active), active and L.subSegment or nil)
    end
    ui.popStyleVar(1)
  end
  if digital < 1 then
    ui.pushStyleVarAlpha(1 - digital)
    -- Printed calibration and LED fill occupy the same arc, rather than two rings.
    local span = S.analogEnd - S.analogStart
    if style == 'original' then
      if available then
        local warning = rpm and not aero and (Config.boostWarning * maximum - minimum) / (maximum - minimum)
          or Config.fuelWarning
        if not aero then
          arc(subCenter, S.analogRadius * scale,
            S.analogStart + (rpm and warning or 0) * span,
            S.analogStart + (rpm and 1 or warning) * span,
            Light.color(low and C.red or C.redDim, low and L.subSegment or L.printedWarning), 2 * scale)
        end
      end
      for i = 0, S.divisions do
        local f = i / S.divisions
        local a = S.analogStart + span * f
        local major = i % S.majorEvery == 0
        local tint = not available and C.outlineDim or (major and C.primary or C.secondary)
        if available and not aero and ((not rpm and f <= Config.fuelWarning)
            or (rpm and f >= (Config.boostWarning * maximum - minimum) / (maximum - minimum))) then tint = C.red end
        Light.line(U.polar(subCenter, (S.analogRadius - (major and S.tickMajor or S.tickMinor)) * scale, a),
          U.polar(subCenter, S.analogRadius * scale, a), tint, (major and S.tickWidth or S.minorWidth) * scale,
          available and (major and L.major or (i % (S.majorEvery / 2) == 0 and L.medium or L.inner)) or nil, scale)
      end
      -- Segment faces cover the printed marks at this radius; calibration is
      -- still visible through the gaps and at the ends. The hand sits above both.
      for i, block in ipairs(analogSubGeometry) do
        local f = (i - 0.5) / S.segmentCount
        local active
        if rpm then
          active = available and f >= math.min(zero, fraction) and f <= math.max(zero, fraction)
        else active = available and i <= math.ceil(fraction * S.segmentCount) end
        Light.segment(subCenter, scale, block, zone(f, active), active and L.subSegment or nil)
      end
    end
    local needleFraction = rpm and fraction
      or U.clamp(state.fuelNeedleNormalized or state.fuelNormalized or 0, 0, 1)
    if rpm and not aero then
      local value = visual and visual.boostNeedleValue or (state.boostNeedleNormalized or 0) * maximum
      needleFraction = U.clamp((value - minimum) / (maximum - minimum), 0, 1)
    end
    if available then
      Needle.draw(subCenter, scale, S.analogStart + span * needleFraction,
        Config.subNeedle, C, light, low and lowInk or nil, L)
    end
    ui.popStyleVar(1)
  end
  if rpm and not aero then
    local first = S.analogStart + (S.startAngle - S.analogStart) * digital
    local last = S.analogEnd + (S.endAngle - S.analogEnd) * digital
    local radius = S.analogRadius + (S.radius - S.analogRadius) * digital
    local a = first + (last - first) * zero
    Light.line(U.polar(subCenter, (radius - 9) * scale, a), U.polar(subCenter, (radius + 2) * scale, a),
      C.amber, 1.2 * scale, L.inner, scale)
    text('0', 9 * scale, U.polar(subCenter, (radius - 19) * scale, a), C.secondary, nil, L.label, scale)
  end
  local iconCenter = subCenter + vec2(0, S.iconY * scale)
  -- Move icons below the pivot in Analog, keeping them centered in Digital.
  iconCenter = iconCenter + vec2(0, (1 - digital) * 11 * scale)
  local tint = not available and C.outlineSoft or (low and lowInk or C.primary)
  icon(aero and M.aeroIcon or (rpm and M.boostIcon or M.fuelIcon),
    iconCenter, S.iconScale * scale, tint, available and L.icon or L.inner)
  text(aero and '0' or (rpm and string.format('%.1f', minimum) or 'E'), S.endSize * scale,
    subCenter + vec2(-74 * scale, 5 * scale), C.secondary, nil, L.label, scale)
  text(aero and '100' or (rpm and string.format('%.1f', maximum) or 'F'), S.endSize * scale,
    subCenter + vec2(74 * scale, 5 * scale), C.secondary, nil, L.label, scale)
  if not available then
    text('N/A', S.labelSize * scale,
      subCenter + vec2(0, 29 * scale), low and lowInk or C.secondary, nil, L.label, scale)
  end
end

-- Radial and Orbit use the lower circumference for their auxiliary reading.
local function lowerArcGauge(center, scale, state, settings, C, light, rpm, L)
  local visual = state.gt7Instruments
  local digital = visual and (rpm and visual.rpmDigital or visual.speedDigital)
  if digital==nil then digital=settings[rpm and 'gt7RpmNeedleMode' or 'gt7SpeedNeedleMode']=='analog' and 0 or 1 end
  local hybrid = rpm and Hybrid.forGauge(state)
  if hybrid then
    HybridGauge.draw(center, scale, hybrid, C, settings.theme, light, 'gt7_lower_arc', 'original', digital<0.5)
    return
  end
  local pressure, minimum, maximum = Presentation.boost(state, settings)
  if visual then pressure, minimum, maximum = visual.boostNeedleValue, visual.boostMinimum, visual.boostMaximum end
  local aero = rpm and not state.turboAvailable
  local available = rpm or (state.fuel ~= nil and state.maxFuel ~= nil)
  local fraction = aero and U.clamp(state.aeroLoadNormalized or 0, 0, 1)
    or (rpm and U.clamp((pressure - minimum) / (maximum - minimum), 0, 1)
      or U.clamp(state.fuelNormalized or 0, 0, 1))
  local zero = rpm and not aero and -minimum / (maximum - minimum) or 0
  local low = not rpm and available and fraction < Config.fuelWarning
  local pulseAlpha=fuelAlertAlpha(state,settings)
  local critical=low and fraction<0.10 and fuelAlertEnabled(settings)
  local lowInk=critical and Theme.withAlpha(C.red,pulseAlpha) or C.red
  for i, block in ipairs(lowerSubGeometry) do
    local f = (i - 0.5) / 32
    local active = available and (rpm and f >= math.min(zero, fraction) and f <= math.max(zero, fraction)
      or not rpm and i <= math.ceil(fraction * 32))
    local warning = not rpm and (low or f <= Config.fuelWarning)
      or rpm and not aero and f >= (Config.boostWarning * maximum - minimum) / (maximum - minimum)
    local color = not available and C.outlineDim or (active and (warning and (low and lowInk or C.red)
      or aero and (f >= 0.82 and C.amber or C.cyan) or rpm and C.primary or C.cyan)
      or warning and C.redDim or C.inactive)
    Light.segment(center, scale, block, color, active and L.subSegment or nil)
  end
  local tint = not available and C.outlineSoft or low and lowInk or C.primary
  icon(aero and M.aeroIcon or rpm and M.boostIcon or M.fuelIcon,
    center + vec2(0, 119 * scale), 0.8 * scale, tint, available and L.icon or L.inner)
  text(not available and 'N/A' or aero and '0' or rpm and string.format('%.1f', minimum) or 'E',
    11 * scale, center + vec2(-128 * scale, 59 * scale), C.secondary, nil, L.label, scale)
  text(aero and '100' or rpm and string.format('%.1f', maximum) or 'F',
    11 * scale, center + vec2(128 * scale, 59 * scale), C.secondary, nil, L.label, scale)
  if rpm and not aero then
    local angle = math.rad(150 - 120 * zero)
    Light.line(U.polar(center, 136 * scale, angle), U.polar(center, 151 * scale, angle),
      C.amber, 1.2 * scale, L.inner, scale)
  end
end

function M.draw(center, scale, state, settings, layout, C, backdropOpacity, rpm, rpmColor)
  local radius = layout.dialRadius
  local visual = state.gt7Instruments
  local mode = rpm and settings.gt7RpmNeedleMode or settings.gt7SpeedNeedleMode
  local role = rpm and 'rpm' or 'speed'
  local selectedStyle = rpm and settings.gt7RpmDialStyle or settings.gt7SpeedDialStyle
  selectedStyle = DialStyles.normalize(selectedStyle, mode, role)
  local face = DialStyles.get(selectedStyle, mode, role)
  local useLowerArc = face.lowerArc == true or face.lowerArc == role
  local first, last = math.rad(face.first), math.rad(face.last)
  local digital = visual and (rpm and visual.rpmDigital or visual.speedDigital)
  if digital == nil then digital = mode == 'digital' and 1 or 0 end
  local light = visual and visual.light
  if light == nil then light = state.lightsAvailable and state.headlights == true and 1 or 0 end
  local L = Light.resolve(C, settings.theme, light)
  ui.drawCircleFilled(center, radius * scale, Theme.withAlpha(C.panel, math.min(0.96, backdropOpacity + 0.18)), 72)
  Light.ambient(center, scale, L)
  if StyledInstruments.supports(selectedStyle, mode, role) then
    StyledInstruments.draw(selectedStyle, center, scale, state, settings, C, L,
      digital, light, rpm, rpmColor, subGauge, lowerArcGauge, mode, role, useLowerArc)
    return
  end
  if not rpm then
    SlipstreamBackground.draw(center+vec2(0,-20*scale),scale,state,settings,C,84,50)
  end
  -- The established three-ring bezel is drawn by ui/gt7_retro, unchanged.
  arc(center, D.numberRadius * scale, first, last,
    C.panelRaised, D.numberBandWidth * scale, 64)
  if light > 0 then
    local ring = Config.illumination.ring
    local intensity = ring.analog + (ring.digital - ring.analog) * digital
    local warmBoundary = first + (last - first) * 0.5
    arc(center, D.lightRadius * scale, first, warmBoundary,
      L.ringHalo, ring.haloWidth * scale)
    arc(center, D.lightRadius * scale, first, warmBoundary,
      Theme.withAlpha(L.ringCold, L.ringCold.mult * intensity), 1 * scale)
    arc(center, D.lightRadius * scale, warmBoundary, last,
      Theme.withAlpha(L.ringWarm, L.ringWarm.mult * intensity), 1 * scale)
  end
  local maximum = rpm and math.max((state.rpmGaugeLimiter or 8000) / 1000, 1)
    or (state.speedGaugeMaximum or 320)
  local step = rpm and (maximum <= 9 and 1 or (maximum <= 18 and 2 or math.ceil(maximum / 8)))
    or (state.speedGaugeStep or maximum / 8)
  local geometry = scaleGeometry(maximum, step, first, last, rpm)
  local fraction = rpm and U.clamp(state.rpmGaugeNormalized or 0, 0, 1)
    or U.clamp((state.speedValue or 0) / maximum, 0, 1)
  local redline = U.clamp((state.rpmDisplayLimiter or 8000) * (state.rpmRedlineFraction or 0.96)
    / math.max(state.rpmGaugeLimiter or 8000, 1), 0, 1)
  local redlineColor = C.red
  if rpm and state.rpmRedline and settings.animateRedlineAlert ~= false
      and math.floor((state.clock or 0) / Layout.redlineBlinkPeriod) % 2 ~= 0 then
    redlineColor = C.amber
  end
  if digital < 1 then
    ui.pushStyleVarAlpha(1 - digital)
    if rpm then
      local key = table.concat({first, last, redline}, '|')
      local redlineGeometry = redlineGeometries[key]
      if not redlineGeometry then
        redlineGeometry = blockGeometry(math.max(2, math.ceil((1 - redline) * D.segmentCount)),
          D.segmentRadius, D.segmentDepth,
          first + (last - first) * redline,
          last, D.segmentGap)
        redlineGeometries[key] = redlineGeometry
      end
      for _, block in ipairs(redlineGeometry) do
        local active = state.rpmRedline or fraction >= redline
        Light.segment(center, scale, block, active and redlineColor or C.redDim,
          active and L.segment or L.printedWarning)
      end
    end
    for _, tick in ipairs(geometry.ticks) do
      -- Keep the analog redline as a clean, broad colored band without normal
      -- graduations behind it, matching the premium GT7 RPM face.
      if not (rpm and tick.f >= redline) then
        Light.line(center + vec2(tick.x1 * scale, tick.y1 * scale), center + vec2(tick.x2 * scale, tick.y2 * scale),
          C.primary, (tick.major and D.tickWidth or (face.fan and tick.medium and D.tickWidth * 0.75 or D.minorWidth)) * scale,
          tick.major and L.major or (tick.medium and L.medium or L.minor), scale)
      end
      if face.fan and tick.major then
        Light.line(center + vec2(40 * math.cos(first + (last - first) * tick.f) * scale,
            40 * math.sin(first + (last - first) * tick.f) * scale),
          center + vec2(tick.x2 * scale, tick.y2 * scale), C.metalDim,
          (face.fan and 0.9 or 0.65) * scale, L.inner, scale)
      end
      if not tick.major then
        ui.drawLine(center + vec2(tick.ix1 * scale, tick.iy1 * scale),
          center + vec2(tick.ix2 * scale, tick.iy2 * scale),
          Light.color(C.secondary, L.inner), D.innerTickWidth * scale)
      end
    end
    for _, label in ipairs(geometry.labels) do
      ui.drawCircleFilled(center + vec2(label.dotX * scale, label.dotY * scale),
        D.innerDotRadius * scale, Light.color(C.primary, L.medium), 10)
    end
    ui.popStyleVar(1)
  end
  if not rpm and face.fan and digital<1 then
    -- Fan keeps the live speed as a compact readout in its open center.
    text(state.speedText or '000',D.valueSize*0.68*scale,
      center+vec2(0,34*scale),C.primary,D.valueWidth*scale,L.value,scale)
    text(settings.speedUnit,D.unitSize*scale,
      center+vec2(0,61*scale),C.secondary,nil,L.label,scale)
  end
  if digital > 0 then
    ui.pushStyleVarAlpha(digital)
    local key = table.concat({first, last, face.columns and 'columns' or ''}, '|')
    local mainGeometry = mainGeometries[key]
    if not mainGeometry then
      if face.columns then
        local left = blockGeometry(D.segmentCount / 2, D.segmentRadius, D.segmentDepth,
          math.rad(140), math.rad(220), D.segmentGap)
        local right = blockGeometry(D.segmentCount / 2, D.segmentRadius, D.segmentDepth,
          math.rad(320), math.rad(400), D.segmentGap)
        mainGeometry = {}
        for _, block in ipairs(left) do mainGeometry[#mainGeometry + 1] = block end
        for _, block in ipairs(right) do mainGeometry[#mainGeometry + 1] = block end
      else
        mainGeometry = segmentGeometry(D.segmentCount, first, last)
      end
      mainGeometries[key] = mainGeometry
    end
    local filled = math.floor(fraction * (face.columns and D.segmentCount / 2 or D.segmentCount) + 0.5)
    for i, block in ipairs(mainGeometry) do
      local localIndex = face.columns and ((i - 1) % (D.segmentCount / 2) + 1) or i
      local f = localIndex / (face.columns and D.segmentCount / 2 or D.segmentCount)
      local active = localIndex <= filled
      local color = active and C.primary or C.inactive
      if rpm then
        color = active and rpmColor(f, true, state, settings) or (f >= redline and C.redDim or C.inactive)
      elseif active and f >= 0.6 then color = C.cyan end
      Light.segment(center, scale, block, color, active and L.segment or nil)
    end
    local value = rpm and (state.rpmText or string.format('%04d', U.round(state.rpm or 0))) or state.speedText or '000'
    text(value, (rpm and D.rpmValueSize or D.valueSize) * scale,
      center + vec2(0, D.valueY * scale), state.rpmRedline and rpm and C.red or C.primary, D.valueWidth * scale, L.value, scale)
    text(rpm and 'RPM' or settings.speedUnit, D.unitSize * scale,
      center + vec2(0, 27 * scale), C.secondary, nil, L.label, scale)
    ui.popStyleVar(1)
  end
  if useLowerArc then
    lowerArcGauge(center, scale, state, settings, C, light, rpm, L)
  else
    subGauge(center, scale, state, settings, C, digital, light, rpm, L)
  end
  -- The principal hand sits above the subinstrument, like a physical assembly.
  if digital < 1 then
    ui.pushStyleVarAlpha(1 - digital)
    text(rpm and 'x1000 RPM' or settings.speedUnit, D.unitSize * scale,
      center + vec2(0, -33 * scale), C.secondary, nil, L.label, scale)
    local needleFraction = rpm and state.gt7RpmNeedleNormalized or state.gt7SpeedNeedleNormalized
    local style = rpm and settings.gt7RpmNeedleStyle or settings.gt7SpeedNeedleStyle
    local tint = rpm and (state.rpmRedline and redlineColor
      or state.rpmWarning and rpmColor(fraction, true, state, settings) or nil) or nil
    Needle.draw(center, scale, first + (last - first)
      * U.clamp(needleFraction or fraction, 0, 1), Config.needlePreset(style), C, light, tint, L)
    ui.popStyleVar(1)
  end
  -- Keep numbered scale labels in the foreground above redline blocks and the needle.
  for _, label in ipairs(geometry.labels) do
    text(label.value, (#geometry.labels > 9 and D.denseNumberSize or D.numberSize) * scale,
      center + vec2(label.x * scale, label.y * scale), C.primary, nil, L.number, scale)
  end
end

return M
