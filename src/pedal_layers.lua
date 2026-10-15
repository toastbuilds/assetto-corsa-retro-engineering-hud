local U = require('src/utils')
local M = {}
local WINDOW, SMOOTHING = 0.15, 0.06
local configs = {}

local function number(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

local function controls(ctx, car, blocked)
  if not blocked and not ctx.inputDenied then
    local ok, result = pcall(function() return physics.getCarInputControls() end)
    local gas = ok and number(U.read(result, 'gas')) or nil
    local brake = ok and number(U.read(result, 'brake')) or nil
    if gas and brake then return U.clamp(gas, 0, 1), U.clamp(brake, 0, 1), 'user' end
    ctx.inputDenied = true
  end
  return U.clamp(number(U.read(car, 'gas')) or 0, 0, 1),
    U.clamp(number(U.read(car, 'brake')) or 0, 0, 1), 'car'
end

local function configuration(id, index)
  if configs[id] ~= nil then return configs[id] or nil end
  local ok, result = pcall(function()
    local ini = ac.INIConfig.carData(index, 'drivetrain.ini')
    local function get(key) return number(ini:get('AUTOBLIP', key, -1)) end
    local level, rise, hold, release = get('LEVEL'), get('POINT_0'), get('POINT_1'), get('POINT_2')
    if not level or level <= 0 or level > 1 or not rise or rise < 0 or not hold or hold < rise
        or not release or release < 0 then return nil end
    return {level = level, rise = rise / 1000, hold = hold / 1000, release = release / 1000,
      electronic = ini:get('AUTOBLIP', 'ELECTRONIC', 0) == 1}
  end)
  configs[id] = ok and result or false
  return configs[id] or nil
end

local function allowance(window, dt, active)
  if dt > 0 then
    local duration = math.min(WINDOW, dt)
    window[#window + 1] = {duration = duration, active = active == true}
    local total = duration
    for i = 1, #window - 1 do total = total + window[i].duration end
    local excess = total - WINDOW
    while excess > 0.0000001 do
      local first = window[1]
      local removed = math.min(excess, first.duration)
      first.duration, excess = first.duration - removed, excess - removed
      if first.duration <= 0.0000001 then table.remove(window, 1) end
    end
  end
  local total, cut = 0, 0
  for _, sample in ipairs(window) do
    total = total + sample.duration
    if sample.active then cut = cut + sample.duration end
  end
  return total > 0 and 1 - cut / total or 1
end

local function blipAt(config, elapsed)
  if elapsed < 0 then return 0 end
  if elapsed < config.rise then return config.level * elapsed / config.rise end
  if elapsed < config.hold then return config.level end
  if config.release > 0 and elapsed < config.hold + config.release then
    return config.level * (1 - (elapsed - config.hold) / config.release)
  end
  return 0
end

local function shift(ctx, car, id, index)
  local gear, engaged = number(U.read(car, 'gear')), number(U.read(car, 'engagedGear'))
  if not gear or not engaged or gear % 1 ~= 0 or engaged % 1 ~= 0 then
    ctx.lastEngaged, ctx.shiftFrom, ctx.blipTime = nil, nil, nil
    return false, 0, false
  end
  local downshift = false
  if engaged == 0 and gear > 0 and ctx.lastEngaged then
    if not ctx.shiftFrom then
      ctx.shiftFrom, ctx.blipStarted, ctx.blipTime = ctx.lastEngaged, false, nil
    end
    downshift = gear < ctx.shiftFrom and not ctx.blipStarted
  elseif engaged > 0 then
    downshift = ctx.lastEngaged and engaged < ctx.lastEngaged and not ctx.blipStarted
    ctx.lastEngaged, ctx.shiftFrom = engaged, nil
    -- Keep the latch until after processing this completed transition.
  else
    ctx.lastEngaged, ctx.shiftFrom, ctx.blipTime, ctx.blipStarted = nil, nil, nil, false
  end
  local config = configuration(id, index)
  local ok, assists = pcall(function() return ac.getAssists() end)
  local enabled = config and (config.electronic or ok and U.read(assists, 'autoBlip') == true)
  if downshift then
    ctx.blipStarted = true
    if enabled then ctx.blipTime = ctx.clock end
  end
  local blip = enabled and ctx.blipTime and blipAt(config, ctx.clock - ctx.blipTime) or 0
  if engaged > 0 then ctx.blipStarted = false end
  return engaged == 0 and gear > 0 and ctx.shiftFrom ~= nil, blip, true
end

function M.reset(state)
  state._pedalLayers, state.pedalLayers = nil, nil
end

function M.update(state, car, sim, dt)
  if not car then M.reset(state); return end
  dt = math.max(0, number(dt) or 0)
  local index = U.read(car, 'index', 0)
  local ok, id = pcall(function() return ac.getCarID(index) end)
  id = tostring(ok and id or index)
  local replay = U.read(sim, 'isReplayActive') == true
  local blocked = replay or U.read(car, 'isAIControlled') == true
    or U.read(car, 'physicsAvailable') == false or index ~= 0
  local session, reset = U.read(sim, 'currentSessionIndex'), U.read(car, 'resetCounter')
  local now, frame = number(U.read(sim, 'time')), number(U.read(sim, 'replayCurrentFrame'))
  local sessionTime = number(U.read(sim, 'currentSessionTime'))
  local ctx = state._pedalLayers
  if not ctx or ctx.id ~= id or ctx.index ~= index or ctx.session ~= session or ctx.reset ~= reset
      or ctx.blocked ~= blocked or ctx.replay ~= replay or U.read(car, 'justJumped') == true
      or now and ctx.time and now < ctx.time or frame and ctx.frame and frame < ctx.frame
      or sessionTime and ctx.sessionTime and sessionTime < ctx.sessionTime or dt > 0.25 then
    ctx = {id = id, index = index, session = session, reset = reset, blocked = blocked,
      replay = replay, tc = {}, abs = {}, tcAllow = 1, absAllow = 1, clock = 0}
    state._pedalLayers = ctx
    state.pedalLayers = nil
  end
  ctx.time, ctx.frame, ctx.sessionTime = now, frame, sessionTime
  if U.read(sim, 'isPaused') == true and state.pedalLayers then return end
  dt = U.read(sim, 'isPaused') == true and 0 or math.min(dt, 0.25)
  ctx.clock = ctx.clock + dt
  local gas, brake, source = controls(ctx, car, blocked)
  local layers = {throttle = {input = gas}, brake = {input = brake}, source = source}
  if not blocked then
    local tc, abs = U.read(car, 'tractionControlInAction'), U.read(car, 'absInAction')
    local tcKnown = type(tc) == 'boolean' or number(U.read(car, 'tractionControlModes')) == 0
    local absKnown = type(abs) == 'boolean' or number(U.read(car, 'absModes')) == 0
    local blend = 1 - math.exp(-dt / SMOOTHING)
    ctx.tcAllow = tcKnown and ctx.tcAllow + (allowance(ctx.tc, dt, tc) - ctx.tcAllow) * blend or 1
    ctx.absAllow = absKnown and ctx.absAllow + (allowance(ctx.abs, dt, abs) - ctx.absAllow) * blend or 1
    if not tcKnown then ctx.tc = {} end
    if not absKnown then ctx.abs = {} end
    local cutting, blip, shiftKnown = shift(ctx, car, id, index)
    if tcKnown or shiftKnown then
      layers.throttle.output = U.clamp(math.max(cutting and 0 or gas * ctx.tcAllow, blip), 0, 1)
    end
    if absKnown then layers.brake.output = U.clamp(brake * ctx.absAllow, 0, 1) end
  end
  state.pedalLayers = layers
end

return M
