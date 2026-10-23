local M = {}
local Settings = require('modules/telemetry/src/settings')
local Theme = require('modules/telemetry/src/theme')
local Telemetry = require('modules/telemetry/src/telemetry')
local History = require('modules/telemetry/src/history')
local Panel = require('modules/telemetry/ui/telemetry_panel')
local GlobalSettings = require('src/general_settings')

local state = Telemetry.new()
local history = History.new()
local visual = {
  palette = Theme.get(GlobalSettings.themeName('telemetry')),
  backdropOpacity = 0.72,
  instrumentOpacity = 1
}
local telemetryError

local function visualStyle()
  visual.palette = GlobalSettings.palette(Theme.get(GlobalSettings.themeName('telemetry')))
  visual.backdropOpacity = 0.72
  visual.instrumentOpacity = GlobalSettings.values.opacity
  return visual
end

function M.update(dt, selectedCar, selectedCarIndex, sim)
  if telemetryError then return end
  local ok, errorMessage = pcall(function()
    Telemetry.update(state, dt, selectedCar, selectedCarIndex, sim)
    if state.sessionChanged or state.carChanged then History.clear(history) end
    History.update(history, dt, state)
  end)
  if not ok then
    telemetryError = tostring(errorMessage)
    ac.error('[RetroEngineeringTelemetry] update error: ' .. telemetryError)
  end
end

function M.windowMain(_)
  local ok, errorMessage = pcall(function()
    Panel.draw(state, history, Settings.values, visualStyle())
  end)
  if not ok then
    ac.error('[RetroEngineeringTelemetry] draw error: ' .. tostring(errorMessage))
    ui.text('RETRO ENGINEERING TELEMETRY')
    ui.text('DRAW ERROR')
    ui.text(tostring(errorMessage))
  end
end

function M.settingsMain(_)
  Settings.draw()
end

return M
