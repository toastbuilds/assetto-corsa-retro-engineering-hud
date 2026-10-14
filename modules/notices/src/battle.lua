local M = {}

local function number(value)
  return type(value) == 'number' and value == value and math.abs(value) < math.huge and value or nil
end

local function notice(snapshot, side)
  local attack = side == 'ahead'
  local row = snapshot and not snapshot.final and snapshot[side]
  if not row or (attack and row.physicallyBehind == true or not attack and row.physicallyBehind == false)
      or not row.driver or row.driver == ''
      or row.status == 'PIT' or row.status == 'OFF' or row.status == 'RET' or row.status == 'FIN' then return nil end
  local rate, gap = number(row.rate), number(row.gapSeconds)
  if not rate or not gap or gap < 0 then return nil end
  local closing = attack and rate or -rate
  if closing <= 0 then return nil end
  local catchLaps = gap / closing
  if attack then
    if not (closing >= 0.5 and catchLaps < 4) then return nil end
  elseif not (closing > 1 or closing >= 0.5 and catchLaps < 2) then return nil end
  local urgent = not attack and catchLaps < 2
  return { kind = 'battle', side = side, urgent = urgent,
    title = attack and 'ATTACK OPPORTUNITY' or urgent and 'REAR ATTACK INCOMING' or 'REAR CAR CLOSING',
    detail = string.format('P%s %s / %s %s%.1f s/LAP', tostring(row.position or '?'),
      row.driver, attack and 'GAINING' or 'LOSING', row.estimated and '~' or '', closing),
    value = string.format('~%.1f', catchLaps), label = 'LAPS TO CATCH' }
end

function M.notice(snapshot, settings)
  local rear = (not settings or settings.battleEnabled) and notice(snapshot, 'behind') or nil
  if rear then return rear end
  if settings and settings.attackEnabled then return notice(snapshot, 'ahead') end
end

return M
