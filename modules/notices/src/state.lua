local U = require('src/utils')
local Repair = require('modules/notices/src/repair')
local FlagCause = require('src/flag_cause')
local M = {}
M.__index = M

local function finite(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

function M.new()
  return setmetatable({ clock = 0, previousDamage = 0 }, M)
end

function M:reset()
  self.pitLap, self.repairLap, self.previousDamage = nil, nil, 0
  self.pitNoticeLap, self.pitNoticeUntil, self.previousAmounts = nil, 0, nil
  self.previousReason, self.autoDamagePit, self.declinedDamage, self.repairSeconds = nil, false, nil, nil
  self.notice, self.blue, self.blueUntil = nil, nil, 0
end

function M:requestPit(car, automatic, targetLap)
  local lap = finite(U.read(car, 'lapCount'))
  if not lap or U.read(car, 'isInPitlane', false) or U.read(car, 'isRaceFinished', false) then return false end
  local nextLap = math.floor(lap) + 2 -- lapCount is completed laps.
  if targetLap ~= nil and (not finite(targetLap) or math.floor(targetLap) < nextLap) then return false end
  self.pitLap = targetLap and math.floor(targetLap) or nextLap
  self.pitNoticeLap, self.pitNoticeUntil = nil, 0
  self.autoDamagePit = automatic == true
  return true
end

function M:cancelPit()
  self.pitLap = nil
  self.pitNoticeLap, self.pitNoticeUntil = nil, 0
  self.autoDamagePit, self.declinedDamage = false, self.previousDamage
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

function M:update(dt, car, sim, condition, traffic, settings, repairRates)
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
  local severity = math.max(amounts.body, amounts.suspension, amounts.engine,
    amounts.gearbox, amounts.blown and 1 or 0)
  if crossed and self.repairLap and lap > self.repairLap then
    self.repairLap, self.declinedDamage = nil, severity
    if self.autoDamagePit then self:cancelPit() end
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
      self.repairLap, self.declinedDamage = lap and math.floor(lap) or nil, nil
    end
    if self.repairLap and settings.autoPitForDamage and not self.pitLap
        and (not self.declinedDamage or severity > self.declinedDamage + 0.025) then
      self:requestPit(car, true)
    end
  elseif self.autoDamagePit then
    self.pitLap = nil
    self.autoDamagePit = false
  end
  if amounts.available and not reason then self.repairLap, self.declinedDamage = nil, nil end
  if not settings.autoPitForDamage and self.autoDamagePit then
    self.pitLap, self.autoDamagePit = nil, false
  end
  if amounts.available then
    self.previousDamage, self.previousReason = severity, settings.repairEnabled and reason or nil
    self.previousAmounts = amounts
  end
  self.repairSeconds = Repair.estimate(amounts, repairRates)

  local currentLap = lap and math.floor(lap) + 1
  if crossed and self.pitLap and currentLap then
    local untilPit = self.pitLap - currentLap
    if untilPit >= 1 and untilPit <= 3 then
      self.pitNoticeLap = currentLap
      self.pitNoticeUntil = untilPit == 1 and math.huge or self.clock + 5
    else self.pitNoticeLap, self.pitNoticeUntil = nil, 0 end
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
  if settings.pitEnabled and self.pitLap and currentLap and
      (currentLap >= self.pitLap or self.pitNoticeLap == currentLap and self.clock < self.pitNoticeUntil) then
    local untilPit = self.pitLap - currentLap
    local title = untilPit <= 0 and 'BOX THIS LAP' or untilPit == 1 and 'BOX NEXT LAP'
      or string.format('BOX IN %d LAPS', untilPit)
    self.notice = { kind = 'pit', title = title,
      detail = string.format('LAP %d%s', self.pitLap, reason and (' / ' .. reason) or ''),
      value = Repair.format(self.repairSeconds), label = 'EST. REPAIR' }
  end
end

return M
