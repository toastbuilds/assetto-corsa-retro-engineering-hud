local M = {}

local function number(value)
  return type(value) == 'number' and value == value and math.abs(value) < math.huge and value or nil
end

function M.notice(snapshot)
  local row = snapshot and not snapshot.final and snapshot.behind
  if not row or row.physicallyBehind == false or not row.driver or row.driver == ''
      or row.status == 'PIT' or row.status == 'OFF' or row.status == 'RET' or row.status == 'FIN' then return nil end
  local rate, gap = number(row.rate), number(row.gapSeconds)
  if not rate or rate >= 0 or not gap or gap < 0 then return nil end
  local closing = -rate
  local catchLaps = gap / closing
  if not (closing > 1 or closing >= 0.5 and catchLaps < 2) then return nil end
  local urgent = catchLaps < 2
  return { kind = 'battle', urgent = urgent,
    title = urgent and 'REAR ATTACK INCOMING' or 'REAR CAR CLOSING',
    detail = string.format('P%s %s / LOSING %s%.1f s/LAP', tostring(row.position or '?'),
      row.driver, row.estimated and '~' or '', closing),
    value = string.format('~%.1f', catchLaps), label = 'LAPS TO CATCH' }
end

return M
