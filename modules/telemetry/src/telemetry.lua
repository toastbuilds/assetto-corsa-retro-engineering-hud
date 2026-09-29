local U = require('modules/telemetry/src/utils')

local M = {}

local FALLBACK_STEER_LOCK = 540

local function blankState()
  return {
    available = false,
    sessionChanged = false,
    sessionKey = nil,
    steeringNormalized = 0,
    steeringAngle = 0,
    steerRange = FALLBACK_STEER_LOCK,
    throttle = 0,
    brake = 0,
    clutchPressed = 0,
    handbrake = 0,
    handbrakeAvailable = false,
    ffbSigned = 0,
    ffbMagnitude = 0,
    ffbNeedle = 0,
    ffbNeedleVelocity = 0,
    ffbClipping = false
  }
end

function M.new()
  return blankState()
end

local function sessionKey()
  local ok, sim = pcall(ac.getSim)
  if not ok or sim == nil then return nil end
  local index = U.read(sim, 'currentSessionIndex', 0)
  return tostring(index)
end

local function controllerSteerFallback()
  local ok, value = pcall(ac.getControllerSteerValue)
  if ok and type(value) == 'number' then return U.clamp(value, -1, 1) end
  return 0
end

local function updateFfbNeedle(state, dt)
  local step = U.clamp(dt or 0, 0, 0.05)
  if step <= 0 then return end

  -- A restrained spring gives the analog meter a little mechanical lag
  -- without making clipping alerts feel late.
  local acceleration = (state.ffbMagnitude - state.ffbNeedle) * 22
    - state.ffbNeedleVelocity * 8
  local velocity = U.clamp(state.ffbNeedleVelocity + acceleration * step, -4, 4)
  local position = U.clamp(state.ffbNeedle + velocity * step, 0, 1)
  if position == 0 or position == 1 then velocity = 0 end
  state.ffbNeedle = position
  state.ffbNeedleVelocity = velocity
end

function M.update(state, dt)
  state.sessionChanged = false

  local currentSession = sessionKey()
  if state.sessionKey ~= nil and currentSession ~= nil and currentSession ~= state.sessionKey then
    state.sessionChanged = true
  end
  state.sessionKey = currentSession

  local ok, car = pcall(ac.getCar, 0)
  if not ok or car == nil then
    state.available = false
    state.ffbMagnitude = 0
    state.ffbClipping = false
    updateFfbNeedle(state, dt)
    return
  end

  state.available = true

  local steer = U.number(U.read(car, 'steer', nil), nil)
  local steerLock = U.number(U.read(car, 'steerLock', nil), nil)
  if steer ~= nil and steerLock ~= nil and math.abs(steerLock) > 0.1 then
    state.steerRange = math.abs(steerLock)
    state.steeringAngle = steer
    state.steeringNormalized = U.clamp(steer / steerLock, -1, 1)
  elseif steer ~= nil then
    state.steerRange = FALLBACK_STEER_LOCK
    state.steeringAngle = steer
    state.steeringNormalized = U.clamp(steer / FALLBACK_STEER_LOCK, -1, 1)
  else
    state.steerRange = FALLBACK_STEER_LOCK
    local controllerSteer = controllerSteerFallback()
    state.steeringAngle = controllerSteer * FALLBACK_STEER_LOCK
    state.steeringNormalized = controllerSteer
  end

  state.throttle = U.clamp(U.number(U.read(car, 'gas', 0), 0), 0, 1)
  state.brake = U.clamp(U.number(U.read(car, 'brake', 0), 0), 0, 1)
  local rawClutch = U.number(U.read(car, 'clutch', 1), 1)
  state.clutchPressed = U.clamp(1 - rawClutch, 0, 1)

  local rawHandbrake = U.number(U.read(car, 'handbrake', nil), nil)
  state.handbrakeAvailable = rawHandbrake ~= nil
  state.handbrake = U.clamp(rawHandbrake or 0, 0, 1)

  state.ffbSigned = U.clamp(U.number(U.read(car, 'ffbFinal', 0), 0), -1, 1)
  state.ffbMagnitude = math.abs(state.ffbSigned)
  state.ffbClipping = state.ffbMagnitude >= 1
  updateFfbNeedle(state, dt)
end

return M
