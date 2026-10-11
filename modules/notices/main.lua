local Settings = require('modules/notices/src/settings')
local State = require('modules/notices/src/state')
local Repair = require('modules/notices/src/repair')
local Display = require('modules/notices/src/display')
local Relative = require('modules/relative/main')
local Window = require('modules/timing/src/window')
local M = {}
local state = State.new()
local controller = Window.new('Retro UI Race Notices',
  function() return vec2(Display.width, Display.height) end, 'notice-center')
local cachedCar, cachedRates, previewNotice, previewUntil
local previews = {
  blue = { kind = 'blue', title = 'BLUE FLAG', detail = 'LMP2 APPROACHING', value = '1.8 s', label = 'BEHIND' },
  repair = { kind = 'repair', title = 'REPAIR REQUIRED', detail = 'FRONT SUSPENSION DAMAGE', value = 'BOX', label = 'REPAIR' },
  pit = { kind = 'pit', title = 'BOX NEXT LAP', detail = 'LAP 12 / FRONT SUSPENSION DAMAGE', value = '~32 s', label = 'EST. REPAIR' }
}

function M.update(dt, telemetry)
  Settings.normalize()
  local car, sim = ac.getCar(0), ac.getSim()
  local id
  if ac.getCarID then
    local ok, value = pcall(ac.getCarID, 0)
    if ok then id = value end
  end
  if cachedCar ~= id or not cachedRates then
    cachedCar, cachedRates = id, Repair.rates(0)
    state:reset()
  end
  local traffic = Relative.getTrafficSnapshot and Relative.getTrafficSnapshot() or nil
  state:update(dt, car, sim, telemetry and telemetry.condition, traffic, Settings.values, cachedRates)
  controller:update(Settings.values)
end

function M.requestPitStop(targetLap)
  return state:requestPit(ac.getCar(0), false, targetLap)
end

function M.windowMain()
  local notice = state.notice
  if previewNotice and ui.time() < previewUntil then notice = previewNotice end
  Display.draw(notice, Settings.values)
end

function M.windowSettings()
  Settings.draw(state, M.requestPitStop, function(kind)
    previewNotice, previewUntil = previews[kind], ui.time() + 8
  end)
  controller:invalidate()
end

return M
