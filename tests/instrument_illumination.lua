local harness = dofile('tests/instruments.lua')
local Config = require('src/instrument_config')
local Presentation = require('src/instrument_state')
local Theme = require('src/theme')
local Light = require('ui/instrument_illumination')
local state = harness.state
local function near(a, b) return math.abs(a - b) < 0.00001 end
local function equal(a, b)
  return near(a.r, b.r) and near(a.g, b.g) and near(a.b, b.b) and near(a.mult, b.mult)
end

-- Timing is independent of frame rate and survives a reversed light switch.
for _, rate in ipairs({30, 60, 144}) do
  local sample = {available=true, lightsAvailable=true, headlights=false, turboAvailable=false}
  Presentation.update(sample, {}, 0)
  sample.headlights = true
  Presentation.update(sample, {}, 0)
  assert(sample.gt7Instruments.light == 0, 'a target change alone must not jump')
  Presentation.update(sample, {}, Config.lightTransition / 2)
  assert(near(sample.gt7Instruments.light, 0.75), 'half-time must follow quadratic ease-out')
  sample.headlights = false
  Presentation.update(sample, {}, 0)
  assert(near(sample.gt7Instruments.light, 0.75), 'reversal must start at the current intensity')
  for _ = 1, math.ceil(Config.lightTransition * rate) do Presentation.update(sample, {}, 1 / rate) end
  assert(sample.gt7Instruments.light == 0)
  sample.headlights = true
  for _ = 1, math.ceil(Config.lightTransition * rate) do Presentation.update(sample, {}, 1 / rate) end
  assert(sample.gt7Instruments.light == 1)
  sample.lightsAvailable = false
  Presentation.update(sample, {}, Config.lightTransition)
  assert(sample.gt7Instruments.light == 0)
end

for _, rate in ipairs({30,60,144}) do
  local sample={available=true,lightsAvailable=true,headlights=false,steadyHeadlights=false,turboAvailable=false}
  Presentation.update(sample,{},0)
  for _=1,3 do
    sample.headlights,sample.flashingLights=true,true
    Presentation.update(sample,{},1/rate)
    assert(sample.gt7Instruments.light==1 and sample.gt7Instruments.steadyLight==0,
      'even a one-frame flash must immediately illuminate GT7 without changing the normal lamp intensity')
    sample.headlights,sample.flashingLights=false,false
    Presentation.update(sample,{},1/rate)
    assert(sample.gt7Instruments.light==0,'release must immediately restore the unlit HUD without an accumulated flash tail')
  end
  sample.headlights,sample.steadyHeadlights=true,true
  Presentation.update(sample,{},Config.lightTransition/2)
  local normal=sample.gt7Instruments.light
  sample.flashingLights=true
  Presentation.update(sample,{},0)
  assert(sample.gt7Instruments.light==1)
  sample.flashingLights=false
  Presentation.update(sample,{},0)
  assert(near(sample.gt7Instruments.light,normal),'flash release must restore an in-progress normal light transition')
  sample.flashingLights=true
  sample.available=false
  Presentation.update(sample,{},Config.lightTransition)
  assert(sample.gt7Instruments.light==0,'a lost car must not keep a stale flash illuminating the HUD')
end

for _, theme in ipairs({'dark', 'light'}) do
  local C = Theme.get(theme)
  local off = Light.resolve(C, theme, 0)
  assert(Light.color(C.primary, off.number) == C.primary and off.number.opacity == 0)
  local on = Light.resolve(C, theme, 1)
  assert(on == Light.resolve(C, theme, 1), 'settled colors must reuse their cache')
  assert(not equal(Light.color(C.primary, on.number), C.primary))
  local major, medium, minor = on.major.colors[C.primary], on.medium.colors[C.primary], on.minor.colors[C.primary]
  assert(major.r > medium.r and medium.r > minor.r, 'tick illumination must have hierarchy')
  assert(on.minor.opacity == 0 and on.major.opacity > on.medium.opacity)
  assert(Light.color(C.inactive, on.segment) == C.inactive, 'inactive faces must stay unchanged')
  local red = Light.color(C.red, on.segment)
  assert(red.r > red.g * 2 and red.g > red.b, 'emission must remain warm red, never magenta')
  local full = Light.color(C.primary, on.number)
  local half = Light.color(C.primary, Light.resolve(C, theme, 0.5).number)
  assert(near(half.r, (C.primary.r + full.r) / 2)
    and near(half.g, (C.primary.g + full.g) / 2), 'color must interpolate with illumination')
end

-- Geometry signatures exclude color: every original crisp primitive must
-- remain in ON; luminous layers can add primitives but cannot replace it.
local function geometry(call)
  local parts = {call.kind, tostring(call.radius), tostring(call.thickness),
    tostring(call.text), tostring(call.size), tostring(call.closed), tostring(call.rounding)}
  local function point(p)
    if p then parts[#parts+1] = string.format('%.6f,%.6f',p.x,p.y) end
  end
  point(call.a); point(call.b)
  for _, p in ipairs(call.points or {}) do point(p) end
  return table.concat(parts,'|')
end
state.available, state.lightsAvailable = true, true
state.speedValue, state.speedText, state.gt7SpeedNeedleNormalized = 139, '139', 139/320
state.rpm, state.rpmText, state.rpmGaugeNormalized, state.gt7RpmNeedleNormalized = 5200, '5200', 0.65, 0.65
state.fuel, state.maxFuel, state.fuelNormalized = 30, 50, 0.6
state.turboAvailable, state.turboBoost, state.boostNeedleNormalized = true, 0.7, 0.7/1.5
state.rpmWarning, state.rpmRedline = false, false
local function draw(mode, theme, light, extra)
  local settings = {theme=theme, gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
    gt7SpeedNeedleStyle='b01', gt7RpmNeedleStyle='b01', gt7SimulateVacuum=true, gt7VacuumMinimum=-0.5,
    showLights=false}
  for k,v in pairs(extra or {}) do settings[k]=v end
  state.headlights, state.gt7Instruments = light == 1, nil
  Presentation.update(state, settings, 0)
  state.gt7Instruments.light = light
  return harness.draw('classic', settings, state)
end
local function inDial(call)
  local p = call.a or (call.points and call.points[1])
  if not p then return false end
  for _, x in ipairs({175,1265}) do
    if (p.x-x)^2 + (p.y-258)^2 < 154^2 then return true end
  end
  return false
end
local function ring(call)
  return call.kind == 'arc' and near(call.radius, Config.dial.lightRadius)
    and near(call.a.y, 258) and (near(call.a.x,175) or near(call.a.x,1265))
end
for _, theme in ipairs({'dark','light'}) do
  for _, mode in ipairs({'analog','digital'}) do
    local off = draw(mode,theme,0)
    local on = draw(mode,theme,1)
    local index, changed, mainValue = {}, 0, false
    for _, c in ipairs(on) do
      if not ring(c) then
        local key = geometry(c)
        index[key] = index[key] or {}
        index[key][#index[key]+1] = c
        if c.kind == 'text' and (c.text=='139' or c.text=='5200') then mainValue=true end
      end
    end
    for _, c in ipairs(off) do
      local candidates = index[geometry(c)]
      assert(candidates, 'lights must preserve all OFF geometry')
      local same = false
      for _, candidate in ipairs(candidates) do if equal(c.color,candidate.color) then same=true end end
      if inDial(c) and not same then changed=changed+1 end
      if c.color == Theme.get(theme).inactive then
        assert(same, 'inactive segments must keep their original color')
      end
      if not inDial(c) and not ring(c) then assert(same, 'external controls must remain unchanged') end
    end
    assert(changed > 60, 'backlight must change the interior independently of its outer ring')
    assert(mode == 'analog' or mainValue, 'digital values must remain present')
    local half = draw(mode,theme,0.5)
    assert(#half == #on, 'intermediate light must reuse luminous geometry')
  end
end

-- Alerts and missing readings remain distinct, in both instrument modes.
for _, mode in ipairs({'analog','digital'}) do
  state.fuel, state.maxFuel, state.turboAvailable = 5, 50, true
  state.fuelNormalized, state.turboBoost, state.rpmGaugeNormalized = 0.1, 1.5, 0.99
  state.rpm, state.rpmText, state.gt7RpmNeedleNormalized = 7900, '7900', 0.99
  state.rpmRedline, state.rpmWarning = true, true
  assert(#draw(mode,'dark',1) > 0)
  state.fuel, state.maxFuel, state.turboAvailable = nil, nil, false
  local calls = draw(mode,'dark',1)
  local labels = {}
  for _, c in ipairs(calls) do if c.kind == 'text' then labels[c.text]=true end end
  assert(labels['N/A'] and labels['NAT ASP'])
end
print('Backlight: timing, reversal, cached styles, hierarchy, color identity, unchanged geometry/controls, inactive faces and missing readings passed')
