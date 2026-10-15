local Settings = require('modules/notices/src/settings')
local State = require('modules/notices/src/state')
local Repair = require('modules/notices/src/repair')
local Display = require('modules/notices/src/display')
local Relative = require('modules/relative/main')
local Leaderboard = require('modules/leaderboard/main')
local Pace = require('modules/notices/src/pace')
local BattleAlert = require('modules/notices/src/battle')
local Window = require('modules/timing/src/window')
local WindowAnchor = require('src/window_anchor')
local M = {}
local state = State.new()
local pace = Pace.new()
local cachedCar, cachedRates, previewNotice, previewUntil, lastSize
local function currentNotice()
  if previewNotice and ui.time() < previewUntil then return previewNotice end
  return state.notice
end
local controller = Window.new('Retro UI Race Notices',
  function(settings) return vec2(Display.width, Display.heightFor(currentNotice(), settings)) end,
  'notice-center')
local previews = {
  blue = { kind = 'blue', title = 'BLUE FLAG', detail = 'LMP2 APPROACHING', value = '1.8 s', label = 'BEHIND' },
  repair = { kind = 'repair', title = 'REPAIR REQUIRED', detail = 'FRONT SUSPENSION DAMAGE', value = 'BOX', label = 'REPAIR' },
  pit = { kind = 'pit', title = 'BOX THIS LAP', detail = '~1 FULL LAP OF FUEL / FRONT SUSPENSION DAMAGE', value = '~32 s', label = 'EST. REPAIR' },
  battle = BattleAlert.notice({behind={driver='COSTA',position=6,rate=-0.6,gapSeconds=0.8}}),
  attack = BattleAlert.notice({ahead={driver='MARTIN',position=4,rate=0.6,gapSeconds=2.1}}, {attackEnabled=true}),
  overtake = {kind='overtake',title='OVERTAKE P5 > P4',detail='A. SATO | GT3 | FERRARI 296',value='~+0.8',label='S/LAP'}
}
previews.overtake.gapHistory = {endProgress = 4, points = {}}
for i = 0, 64 do
  previews.overtake.gapHistory.points[#previews.overtake.gapHistory.points + 1] = {
    progress = i / 16, gap = math.max(-0.1, 3.2 - i * 0.052 + math.sin(i / 3) * 0.12),
    estimated = true
  }
end

local function updateWindow()
  local size = controller:desiredSize(Settings.values)
  if not lastSize or math.abs(lastSize.x - size.x) > 0.1 or math.abs(lastSize.y - size.y) > 0.1 then
    controller:invalidate()
    WindowAnchor.acceptSize('notices', size)
    lastSize = size
  end
  controller:update(Settings.values)
end

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
    pace:reset()
  end
  local traffic = Relative.getTrafficSnapshot and Relative.getTrafficSnapshot() or nil
  local snapshot = Leaderboard.getRaceSnapshot()
  pace:update(snapshot)
  state:update(dt, car, sim, telemetry and telemetry.condition, traffic, Settings.values, cachedRates,
    snapshot and snapshot.fuel, pace.snapshot, snapshot)
  updateWindow()
end

function M.windowMain()
  updateWindow()
  Display.draw(currentNotice(), Settings.values)
end

function M.windowSettings()
  Settings.draw(state, function(kind)
    previewNotice, previewUntil = previews[kind], ui.time() + 8
  end)
  controller:invalidate()
end

return M
