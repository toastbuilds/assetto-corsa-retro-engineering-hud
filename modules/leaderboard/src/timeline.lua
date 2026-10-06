-- All times returned here are seconds. Keep live time on the SDK's sim.time
-- epoch: onTrackPointCrossed timestamps use that clock, not session time.
local M = {}

local function read(object, key)
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  if ok then return value end
  return nil
end

local function number(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

function M.sample(sim)
  local wall = ui.time()
  local replay = read(sim, 'isReplayActive') == true
  local frame, frameMs = number(read(sim, 'replayCurrentFrame')), number(read(sim, 'replayFrameMs'))
  local sdkTime = number(read(sim, 'time'))
  local sessionTime = number(read(sim, 'currentSessionTime'))
  sdkTime = sdkTime and sdkTime / 1000
  sessionTime = sessionTime and sessionTime / 1000
  local time, clock
  if replay and frame and frame >= 0 and frameMs and frameMs > 0 then
    time, clock = frame * frameMs / 1000, 'replay'
  elseif sdkTime then
    time, clock = sdkTime, 'sim'
  elseif sessionTime then
    time, clock = sessionTime, 'session'
  else
    time, clock = wall, 'wall'
  end
  return {replay = replay, frame = frame, frameMs = frameMs,
    time = time, wall = wall, clock = clock, sdkTime = sdkTime, sessionTime = sessionTime,
    -- A replay without frame timing must not acquire wall-clock crossings.
    measuredClock = replay and clock == 'replay' or not replay and clock ~= 'wall'}
end

function M.discontinuous(previous, current, sim)
  if not previous then return false end
  if previous.replay ~= current.replay or current.time < previous.time then return true end
  if previous.clock and current.clock and previous.clock ~= current.clock then return true end
  if not current.replay then
    -- sim.time keeps increasing through a restart; the session clock resets.
    return previous.sessionTime ~= nil and current.sessionTime ~= nil
      and current.sessionTime < previous.sessionTime
  end
  if previous.frameMs and current.frameMs and previous.frameMs ~= current.frameMs then return true end
  if previous.frame and current.frame and current.frame < previous.frame then return true end
  local rate = number(read(sim, 'replayPlaybackRate')) or 1
  local elapsed = math.max(0, current.wall - previous.wall) * math.abs(rate)
  local expected = math.max(0, number(read(sim, 'dt')) or 0, elapsed)
  if read(sim, 'isPaused') == true or rate == 0 then expected = 0 end
  local tolerance = math.max(0.05, (current.frameMs or 16) / 1000 * 3)
  return current.time - previous.time > expected + tolerance
end

return M
