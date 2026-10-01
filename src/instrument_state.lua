local Config = require('src/instrument_config')
local Layout = require('src/gt7_retro_layout')
local U = require('src/utils')
local M = {}

local function transition(value, target, dt, duration)
  if value == nil then return target end
  local step = math.max(dt or 0, 0) / math.max(duration, 0.001)
  return value + U.clamp(target - value, -step, step)
end

function M.boost(state, settings)
  local minimum = settings.gt7SimulateVacuum and (settings.gt7VacuumMinimum or Config.vacuumMinimum) or 0
  minimum = U.clamp(minimum, -1, 0)
  local pressure = state.turboBoost or 0
  local simulated = state.available ~= false and state.turboAvailable and minimum < 0
    and pressure == 0 and (state.rpm or 0) > 0
  if simulated then pressure = minimum * (1 - U.clamp(state.throttle or 0, 0, 1)) end
  return pressure, minimum, math.max(state.turboDisplayMax or 1, 0.1), simulated
end

-- A presentation state belongs to a telemetry instance, never to a renderer.
-- Both modes use this same state. Existing telemetry and spring targets remain
-- intact, including the unipolar boost needle used by Free/the standalone dial.
function M.update(state, settings, dt)
  local visual = state.gt7Instruments
  if not visual then visual = {}; state.gt7Instruments = visual end
  local target = state.available and state.lightsAvailable and state.headlights == true and 1 or 0
  if visual.light == nil then
    visual.light, visual.lightTarget, visual.lightFrom, visual.lightElapsed = target, target, target, 0
  else
    if visual.lightTarget ~= target then
      visual.lightTarget, visual.lightFrom, visual.lightElapsed = target, visual.light, 0
    end
    visual.lightElapsed = math.min((visual.lightElapsed or 0) + math.max(dt or 0, 0), Config.lightTransition)
    local progress = U.clamp(visual.lightElapsed / math.max(Config.lightTransition, 0.001), 0, 1)
    local eased = 1 - (1 - progress) * (1 - progress)
    visual.light = visual.lightFrom + (target - visual.lightFrom) * eased
  end
  visual.speedDigital = transition(visual.speedDigital,
    settings.gt7SpeedNeedleMode == 'digital' and 1 or 0, dt, Config.modeTransition)
  visual.rpmDigital = transition(visual.rpmDigital,
    settings.gt7RpmNeedleMode == 'digital' and 1 or 0, dt, Config.modeTransition)
  local pressure, minimum, maximum, simulated = M.boost(state, settings)
  visual.boostValue, visual.boostMinimum, visual.boostMaximum = pressure, minimum, maximum
  visual.boostSimulated = simulated
  -- Only the additional vacuum branch needs its own inertia. The measured
  -- positive branch still uses the original boost spring, without retuning.
  local target = simulated and -pressure or 0
  local limit = math.max(-minimum, 0.001)
  local step = U.clamp(dt or 0, 0, 0.05)
  if not state.available or not state.turboAvailable then
    visual.vacuum, visual.vacuumVelocity = 0, 0
  elseif step > 0 then
    local position, velocity = visual.vacuum or 0, visual.vacuumVelocity or 0
    velocity = U.clamp(velocity + ((target - position) * Layout.boostNeedleSpring
      - velocity * Layout.boostNeedleDamping) * step,
      -Layout.boostNeedleMaxVelocity, Layout.boostNeedleMaxVelocity)
    position = U.clamp(position + velocity * step, 0, limit)
    if (position == 0 and velocity < 0) or (position == limit and velocity > 0) then velocity = 0 end
    visual.vacuum, visual.vacuumVelocity = position, velocity
  end
  visual.boostNeedleValue = (state.boostNeedleNormalized or 0) * maximum - (visual.vacuum or 0)
end

return M
