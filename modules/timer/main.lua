local GeneralSettings = require('src/general_settings')
local Audio = require('modules/timer/src/audio')
local Display = require('modules/timer/src/display')
local Settings = require('modules/timer/src/settings')
local State = require('modules/timer/src/state')
local Theme = require('modules/timing/src/theme')
local Window = require('modules/timing/src/window')

local M = {}
local APP_TITLE = 'Retro UI Timer'
local state = State.new(Settings.values)
local controller = Window.new(APP_TITLE, function() return vec2(320, 94) end, 'top-center')
local lastError
local lastSectorRecordEvent = 0
local lastLapCompletedEvent = 0

local function report(stage, err)
  local message = '[' .. APP_TITLE .. '] ' .. stage .. ': ' .. tostring(err)
  if message == lastError then return end
  lastError = message
  if type(ac.error) == 'function' then pcall(ac.error, message) end
end

function M.update(dt)
  Settings.normalize()
  local ok, err = pcall(function() state:update(dt) end)
  if not ok then report('update', err) end
  local snapshot = state:snapshot()
  if snapshot.sectorRecordEventId ~= lastSectorRecordEvent then
    lastSectorRecordEvent = snapshot.sectorRecordEventId
    if Settings.values.audioEnabled then Audio.playSectorRecord() end
  end
  if snapshot.lapCompletedEventId ~= lastLapCompletedEvent then
    lastLapCompletedEvent = snapshot.lapCompletedEventId
    if Settings.values.audioEnabled then Audio.playLapCompleted() end
  end
  controller:update(Settings.values)
end

function M.windowMain(_)
  Settings.normalize()
  local snapshot = state:snapshot()
  local visual = {
    palette = GeneralSettings.palette(Theme.get(GeneralSettings.values.theme)),
    instrumentOpacity = GeneralSettings.values.opacity
  }
  local ok, events = pcall(Display.draw, snapshot, Settings.values, visual)
  if not ok then
    report('draw', events)
    ui.text('Timer: ' .. tostring(events))
    return
  end
  if events and events.toggleLock then controller:toggleLock(Settings.values) end
end

function M.windowSettings(_)
  Settings.draw()
  controller:invalidate()
end

return M
