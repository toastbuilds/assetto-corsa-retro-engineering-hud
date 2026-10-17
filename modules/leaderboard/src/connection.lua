local M = {}
local SMOOTHING_SECONDS = 2

local function finite(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

local function quality(ping)
  if ping <= 60 then return 5, 'EXCELLENT' end
  if ping <= 100 then return 4, 'GOOD' end
  if ping <= 150 then return 3, 'FAIR' end
  if ping <= 250 then return 2, 'POOR' end
  return 1, 'BAD'
end

function M.update(state, rows, online, now)
  local present = {}
  for _, row in ipairs(rows) do
    row.connection = nil
    if online and not row.isAI then
      present[row.index] = true
      local identity = table.concat({tostring(row.driver), tostring(row.carID), tostring(row.sessionID)}, '/')
      local previous = state[row.index]
      if not previous or previous.identity ~= identity then previous = {identity = identity} end
      local ping = finite(row.pingMs)
      if not row.connected or not row.active or not ping or ping < 0 then
        previous.ping = nil
        row.connection = {bars = 0, label = 'NO PING DATA'}
      else
        local elapsed = math.max(0, math.min(5, now - (previous.at or now)))
        previous.ping = previous.ping and previous.ping + (ping - previous.ping)
          * (1 - math.exp(-elapsed / SMOOTHING_SECONDS)) or ping
        local bars, label = quality(previous.ping)
        row.connection = {bars = bars, label = label, pingMs = math.floor(previous.ping + 0.5)}
      end
      previous.at = now
      state[row.index] = previous
    end
  end
  for index in pairs(state) do if not present[index] then state[index] = nil end end
end

return M
