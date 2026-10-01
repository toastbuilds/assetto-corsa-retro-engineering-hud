local Telemetry = require('src/telemetry')
local Presentation = require('src/instrument_state')
local Config = require('src/instrument_config')
local SettingsUI = require('src/settings_ui')
local M = {}

-- Deliberately not ac.storage: preview must never resume after an app restart.
M.controls = { enabled = false, speedMode = 'analog', rpmMode = 'analog',
  style = 'b01', lights = false, speed = 0.5, rpm = 0.5, fuel = 0.6,
  boost = 0.6, turbo = true, missingFuel = false }
local state
local car = { gear = 3, gas = 0.7, brake = 0, clutch = 1, handbrake = 0,
  fuel = 30, maxFuel = 50, turboCount = 1, turboBoost = 0.6,
  headlightsActive = false, lowBeams = true, engineLifeLeft = 1000,
  wheels = {}, tractionControlModes = 1, tractionControlMode = 1,
  absModes = 1, absMode = 1, steer = 0, steerLock = 450 }

function M.settings(settings)
  if not M.controls.enabled then return settings end
  local result = {}
  for key, value in pairs(settings) do result[key] = value end
  result.gt7SpeedNeedleMode, result.gt7RpmNeedleMode = M.controls.speedMode, M.controls.rpmMode
  result.gt7SpeedNeedleStyle, result.gt7RpmNeedleStyle = M.controls.style, M.controls.style
  result.gt7PreviewActive = true
  return result
end

function M.update(dt, settings, live)
  if not M.controls.enabled then state = nil; return end
  state = state or Telemetry.new()
  local c = M.controls
  local maximum = live.speedGaugeMaximum or 320
  car.speedKmh = c.speed * maximum / (settings.speedUnit == 'mph' and 0.621371 or 1)
  car.rpmLimiter = live.rpmDisplayLimiter or settings.fallbackRpm or 8000
  car.rpm = c.rpm * car.rpmLimiter
  if c.missingFuel then car.fuel, car.maxFuel = nil, nil
  else car.fuel, car.maxFuel = c.fuel * 50, 50 end
  car.turboCount, car.turboBoost = c.turbo and 1 or 0, math.max(0, c.boost)
  local minimum = settings.gt7VacuumMinimum or Config.vacuumMinimum
  car.gas = c.boost < 0 and math.max(0, 1 - c.boost / minimum) or 1
  car.headlightsActive = c.lights
  Telemetry.update(state, dt, settings, car)
  state.raceFlagType = nil
  Presentation.update(state, M.settings(settings), dt)
end

function M.getState() return state end
function M.reset() M.controls.enabled = false; state = nil end

function M.draw(settings)
  local c = M.controls
  if ui.checkbox('Instrument preview (temporary)', c.enabled) then c.enabled = not c.enabled end
  if not c.enabled then return end
  ui.textWrapped('PREVIEW: isolated sample data. Your car and other windows keep their live telemetry.')
  local modes = { { label = 'Analog', value = 'analog' }, { label = 'Digital', value = 'digital' } }
  local function choice(key, label, values)
    SettingsUI.choice('gt7-preview', key, label, c[key], values, function(value) c[key] = value end)
  end
  local function slider(key, label, low, high, format)
    local value, changed = ui.slider(label .. '##preview', c[key], low, high, format, 1)
    if changed then c[key] = value end
  end
  choice('speedMode', 'Preview speed mode', modes)
  choice('rpmMode', 'Preview RPM mode', modes)
  choice('style', 'Preview needle', Config.needleChoices)
  for _, item in ipairs({ {'lights', 'Preview lights ON'}, {'turbo', 'Preview turbo car'},
    {'missingFuel', 'Preview missing fuel'} }) do
    if ui.checkbox(item[2], c[item[1]]) then c[item[1]] = not c[item[1]] end
  end
  slider('speed', 'Speed / full scale', 0, 1, '%.2f')
  slider('rpm', 'RPM / limiter', 0, 1.05, '%.2f')
  slider('fuel', 'Fuel fraction (reserve < 0.15)', 0, 1, '%.2f')
  local minimum = settings and settings.gt7VacuumMinimum or Config.vacuumMinimum
  slider('boost', 'Boost (negative = simulated)', minimum, 2, '%.2f bar')
end

return M
