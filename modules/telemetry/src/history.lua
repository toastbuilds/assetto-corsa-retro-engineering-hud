local M = {}

M.CAPACITY = 5 * 60
M.SAMPLE_HZ = 60
M.INTERVAL = 1 / M.SAMPLE_HZ

local function nextIndex(index)
  return index % M.CAPACITY + 1
end

function M.new()
  local samples = {}
  for index = 1, M.CAPACITY do
    samples[index] = {
      throttle = 0,
      brake = 0,
      clutch = 0,
      ffb = 0,
      handbrake = 0
    }
  end

  return {
    samples = samples,
    head = 0,
    count = 0,
    accumulator = 0
  }
end

function M.clear(history)
  history.head = 0
  history.count = 0
  history.accumulator = 0
end

local function writeSample(history, state)
  history.head = nextIndex(history.head)
  local sample = history.samples[history.head]
  sample.throttle = state.throttle
  sample.brake = state.brake
  sample.clutch = state.clutchPressed
  sample.ffb = state.ffbMagnitude
  sample.handbrake = state.handbrake
  history.count = math.min(history.count + 1, M.CAPACITY)
end

-- The accumulator is intentionally independent from the graph width. The
-- graph is a viewport over this fixed five-second, 300-sample timeline.
-- FFB is stored as display intensity; the live signed value is retained only
-- by telemetry.lua for clipping detection.
function M.update(history, dt, state)
  if state == nil or not state.available then return 0 end

  local elapsed = tonumber(dt) or 0
  if elapsed < 0 then elapsed = 0 end
  history.accumulator = math.min(history.accumulator + elapsed, 0.25)

  local written = 0
  while history.accumulator >= M.INTERVAL do
    history.accumulator = history.accumulator - M.INTERVAL
    writeSample(history, state)
    written = written + 1
  end
  return written
end

-- Ordinal zero is the oldest retained sample; this preserves chronology when
-- the circular head wraps around.
function M.sampleAt(history, ordinal)
  if ordinal < 0 or ordinal >= history.count then return nil end
  local index = (history.head - history.count + ordinal) % M.CAPACITY + 1
  return history.samples[index]
end

return M
