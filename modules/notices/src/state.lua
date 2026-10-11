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
  return setmetatable({ clock = 0, repairUntil = 0, previousDamage = 0 }, M)
end

function M:reset()
  self.pitLap, self.repairUntil, self.previousDamage = nil, 0, 0
  self.previousReason, self.autoDamagePit, self.declinedDamage, self.repairSeconds = nil, false, nil, nil
  self.notice, self.blue, self.blueUntil = nil, nil, 0
end

function M:requestPit(car, automatic)
  local lap = finite(U.read(car, 'lapCount'))
  if not lap or U.read(car, 'isInPitlane', false) or U.read(car, 'isRaceFinished', false) then return false end
  self.pitLap = math.floor(lap) + 2 -- lapCount is completed laps; request the next displayed lap.
  self.autoDamagePit = automatic == true
  return true
end

function M:cancelPit()
  self.pitLap = nil
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
  if self.session ~= session or (self.lastLap and lap and lap < self.lastLap)
      or (self.sessionTime and sessionTime and sessionTime < self.sessionTime)
      or (self.resetCounter and resetCounter and self.resetCounter ~= resetCounter)
      or U.read(car, 'justJumped', false) then self:reset() end
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
  if settings.repairEnabled and reason then
    if severity > self.previousDamage + 0.025 or self.previousReason ~= reason then
      self.repairUntil = self.clock + settings.repairHold
    end
    if settings.autoPitForDamage and not self.pitLap
        and (not self.declinedDamage or severity > self.declinedDamage + 0.025) then
      self:requestPit(car, true)
    end
  elseif self.autoDamagePit then
    self.pitLap = nil
    self.autoDamagePit = false
  end
  if not reason then self.declinedDamage = nil end
  if not settings.autoPitForDamage and self.autoDamagePit then
    self.pitLap, self.autoDamagePit = nil, false
  end
  self.previousDamage, self.previousReason = severity, settings.repairEnabled and reason or nil
  self.repairSeconds = Repair.estimate(amounts, repairRates)

  if settings.repairEnabled and reason and self.clock < self.repairUntil then
    self.notice = { kind = 'repair', title = 'REPAIR REQUIRED', detail = reason,
      value = 'BOX', label = 'REPAIR' }
    return
  end
  if settings.blueEnabled then
    local blue = blueNotice(sim, traffic)
    if blue then self.blue, self.blueUntil = blue, self.clock + 0.4 end
    if self.blue and self.clock < self.blueUntil then self.notice = self.blue; return end
  else self.blue = nil end
  if settings.pitEnabled and self.pitLap and lap then
    local currentLap = math.floor(lap) + 1
    local nextLap = currentLap < self.pitLap
    self.notice = { kind = 'pit', title = nextLap and 'BOX NEXT LAP' or 'BOX THIS LAP',
      detail = string.format('LAP %d%s', self.pitLap, reason and (' / ' .. reason) or ''),
      value = Repair.format(self.repairSeconds), label = 'EST. REPAIR' }
  end
end

return M
