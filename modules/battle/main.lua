local Settings = require('modules/battle/src/settings')
local State = require('modules/battle/src/state')
local Display = require('modules/battle/src/display')
local Leaderboard = require('modules/leaderboard/main')
local Window = require('modules/timing/src/window')
local M = {}
local state = State.new()
local controller = Window.new('Retro UI Battle Panel', function() return vec2(Display.width, Display.height) end, 'middle-left')
local previewUntil = -1
function M.update(_)
  Settings.normalize()
  state:update(Leaderboard.getRaceSnapshot())
  controller:update(Settings.values)
end
function M.getBattleSnapshot() return state.snapshot end
function M.windowMain()
  Display.draw(ui.time() < previewUntil and State.preview() or state.snapshot, Settings.values)
end
function M.windowSettings()
  Settings.draw(state, function() previewUntil = ui.time() + 8 end)
  controller:invalidate()
end
return M
