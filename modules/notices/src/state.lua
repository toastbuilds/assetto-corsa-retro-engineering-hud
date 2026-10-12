local U = require('src/utils')
local Repair = require('modules/notices/src/repair')
local FlagCause = require('src/flag_cause')
local BattleAlert = require('modules/notices/src/battle')
local M = {}
M.__index = M

local function finite(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

function M.new()
  return setmetatable({ clock = 0 }, M)
end

function M:reset()
  self.repairLap, self.pitFuelLaps, self.lastFuel = nil, nil, nil
  self.pitNoticeLap, self.pitNoticeUntil, self.previousAmounts = nil, 0, nil
  self.previousReason, self.repairSeconds = nil, nil
  self.notice, self.blue, self.blueUntil = nil, nil, 0
end

local function repairReason(d, settings)
  if d.blown then return 'PUNCTURED TYRE' end
  if d.gearbox >= settings.engineDamageThreshold then return 'GEARBOX DAMAGE' end
  if d.suspension >= settings.suspensionDamageThreshold then
    if d.front >= d.rear then return 'FRONT SUSPENSION DAMAGE' end
    return 'REAR SUSPENSION DAMAGE'
  end
  if d.engine >= settings.engineDamageThreshold then return 'ENGINE DAMAGE' end
  if d.body >= settings.bodyDamageThreshold then return 'BODYWORK DAMAGE' end
end

local function blueNotice(sim, traffic)
  local flags = ac.FlagType or {}
  local flag = finite(U.read(sim, 'raceFlagType'))
  if flag == nil then return nil end
  if flag ~= (finite(flags.FasterCar) or 12) and flag ~= finite(flags.Blue) then return nil end
  local _, cause = FlagCause.resolve(sim)
  local selected
  for _, row in ipairs(traffic and traffic.cars or {}) do
    if row.index == cause and not row.inPitlane then selected = row; break end
    -- With no official cause, only attribute a physically trailing car that
    -- is lapping us. A class ranking alone does not establish a blue flag.
    if cause == nil and row.behind and not row.inPitlane and row.gap and row.gap >= 0
        and traffic.player and row.progress > traffic.player.progress + 0.5
        and (not selected or row.gap < selected.gap) then selected = row end
  end
  local class = selected and selected.classID
  local detail = class and class ~= 'UNKNOWN' and (class .. ' APPROACHING') or 'FASTER CAR APPROACHING'
  local gap = selected and finite(selected.gap)
  local value = gap and gap >= 0 and string.format('%s%.1f s', selected.measured and '' or '~', gap) or '--'
  return { kind = 'blue', title = 'BLUE FLAG', detail = detail,
    value = value, label = 'BEHIND' }
end

function M:update(dt, car, sim, condition, traffic, settings, repairRates, fuel, battle)
  if not U.read(sim, 'isPaused', false) then
    self.clock = self.clock + math.max(0, finite(dt) or 0)
  end
  local session = U.read(sim, 'currentSessionIndex')
  local lap = finite(U.read(car, 'lapCount'))
  local sessionTime = finite(U.read(sim, 'currentSessionTime'))
  local resetCounter = U.read(car, 'resetCounter')
  local crossed = self.lastLap and lap and lap > self.lastLap
  if self.session ~= session or (self.lastLap and lap and lap < self.lastLap)
      or (self.sessionTime and sessionTime and sessionTime < self.sessionTime)
      or (self.resetCounter and resetCounter and self.resetCounter ~= resetCounter)
      or U.read(car, 'justJumped', false) then self:reset(); crossed = false end
  self.session, self.lastLap, self.sessionTime, self.resetCounter = session, lap, sessionTime, resetCounter
  self.notice = nil
  if not car or U.read(sim, 'isReplayActive', false) or U.read(car, 'physicsAvailable') == false
      or U.read(car, 'isRaceFinished', false) or U.read(sim, 'isSessionFinished', false) then
    self:reset(); return
  end
  if U.read(sim, 'isSessionStarted') == false then self:reset(); return end
  local inPits = U.read(car, 'isInPitlane', false) or U.read(car, 'isInPit', false)
  if inPits then self:reset(); return end

  local amounts = Repair.damage(condition)
  local reason = repairReason(amounts, settings)
  if crossed and self.repairLap and lap > self.repairLap then
    self.repairLap = nil
  end
  local newDamage = amounts.available and reason and not self.previousReason
  if amounts.available and reason and self.previousAmounts then
    for _, key in ipairs({ 'body', 'suspension', 'engine', 'gearbox' }) do
      newDamage = newDamage or amounts[key] > self.previousAmounts[key] + 0.025
    end
    newDamage = newDamage or amounts.blown and not self.previousAmounts.blown
  end
  if settings.repairEnabled and reason then
    if newDamage then
      self.repairLap = lap and math.floor(lap) or nil
    end
  end
  if amounts.available and not reason then self.repairLap = nil end
  if amounts.available then
    self.previousReason = settings.repairEnabled and reason or nil
    self.previousAmounts = amounts
  end
  self.repairSeconds = Repair.estimate(amounts, repairRates)

  local currentLap = lap and math.floor(lap) + 1
  local remaining = fuel and fuel.available and finite(fuel.estimatedLaps)
  if remaining and remaining >= 0 then remaining = math.floor(remaining) else remaining = nil end
  local litres = fuel and finite(fuel.fuel)
  local refuelled = litres and self.lastFuel and litres > self.lastFuel + 0.05
  local enoughToFinish = fuel and fuel.finishAvailable and finite(fuel.fuelNeeded)
    and litres and litres >= fuel.fuelNeeded
  self.lastFuel = litres
  if not remaining or remaining > 3 or refuelled or enoughToFinish then
    self.pitFuelLaps, self.pitNoticeLap, self.pitNoticeUntil = nil, nil, 0
  elseif crossed and currentLap then
    self.pitFuelLaps, self.pitNoticeLap = remaining, currentLap
    self.pitNoticeUntil = remaining <= 1 and math.huge or self.clock + 5
  elseif self.pitFuelLaps and remaining > self.pitFuelLaps then
    -- A revised consumption estimate can also remove the need to stop.
    self.pitFuelLaps, self.pitNoticeLap, self.pitNoticeUntil = nil, nil, 0
  end

  if settings.repairEnabled and reason and self.repairLap then
    self.notice = { kind = 'repair', title = 'REPAIR REQUIRED', detail = reason,
      value = 'BOX', label = 'REPAIR' }
    return
  end
  if settings.blueEnabled then
    local blue = blueNotice(sim, traffic)
    if blue then self.blue, self.blueUntil = blue, self.clock + 0.4 end
    if self.blue and self.clock < self.blueUntil then self.notice = self.blue; return end
  else self.blue = nil end
  if settings.pitEnabled and self.pitFuelLaps and self.pitNoticeLap == currentLap
      and self.clock < self.pitNoticeUntil then
    local title = self.pitFuelLaps <= 1 and 'BOX THIS LAP'
      or string.format('BOX IN %d LAPS', self.pitFuelLaps)
    self.notice = { kind = 'pit', title = title,
      detail = string.format('~%d FULL %s OF FUEL%s', remaining,
        remaining == 1 and 'LAP' or 'LAPS', reason and (' / ' .. reason) or ''),
      value = Repair.format(self.repairSeconds), label = 'EST. REPAIR' }
    return
  end
  if settings.battleEnabled then self.notice = BattleAlert.notice(battle) end
end

return M
