local GeneralSettings = require('src/general_settings')
local Display = require('modules/laps/src/display')
local Settings = require('modules/laps/src/settings')
local State = require('modules/laps/src/state')
local Theme = require('modules/timing/src/theme')
local Window = require('modules/timing/src/window')

local M = {}
local APP_TITLE = 'Retro UI Laps'
local state = State.new()
local controller = Window.new(APP_TITLE, Display.size, 'top-right', true)
local lastError

local function report(stage, err)
  local message = '[' .. APP_TITLE .. '] ' .. stage .. ': ' .. tostring(err)
  if message == lastError then return end
  lastError = message
  if type(ac.error) == 'function' then pcall(ac.error, message) end
end

function M.update()
  Settings.normalize()
  local ok, err = pcall(function() state:update() end)
  if not ok then report('update', err) end
  controller:update(Settings.values)
end

function M.windowMain(_)
  Settings.normalize()
  local visual = {
    palette = GeneralSettings.palette(Theme.get(GeneralSettings.values.theme)),
    instrumentOpacity = GeneralSettings.values.opacity,
    animateLapChanges = Settings.values.animateLapChanges,
    showEstimatedLapTime = Settings.values.showEstimatedLapTime
  }
  local ok, drawError = pcall(Display.draw, state:snapshot(), Settings.values, visual)
  if not ok then
    report('draw', drawError)
    ui.text('Laps: ' .. tostring(drawError))
  end
end

function M.windowSettings(_)
  Settings.draw()
  controller:invalidate()
end

return M
