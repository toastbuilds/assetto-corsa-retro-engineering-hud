local M = {}
local Settings = require('modules/telemetry/src/settings')
local Theme = require('modules/telemetry/src/theme')
local Telemetry = require('modules/telemetry/src/telemetry')
local History = require('modules/telemetry/src/history')
local Panel = require('modules/telemetry/ui/telemetry_panel')
local GlobalSettings = require('src/settings')

local HUD_THEME_EVENT = 'retro-engineering-hud/theme/v1'

local state = Telemetry.new()
local history = History.new()
local syncedTheme = {
  name = 'dark',
  backdropOpacity = 0.72,
  instrumentOpacity = 1,
  lastReceived = -100
}
local visual = {
  palette = Theme.get('dark'),
  backdropOpacity = 0.72,
  instrumentOpacity = 1
}
local telemetryError

local function clampUnit(value, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.max(0, math.min(1, value))
end

local function receiveHudTheme(payload)
  if type(payload) ~= 'string' then return end
  local name, backdrop, instrument = payload:match('^([^|]+)|([^|]+)|([^|]+)$')
  if name ~= 'dark' and name ~= 'light' then return end
  backdrop = tonumber(backdrop)
  instrument = tonumber(instrument)
  if backdrop == nil or instrument == nil then return end
  syncedTheme.name = name
  syncedTheme.backdropOpacity = clampUnit(backdrop, 0.72)
  syncedTheme.instrumentOpacity = clampUnit(instrument, 1)
  syncedTheme.lastReceived = ui.time()
end

-- The companion HUD is optional. Registration and payload parsing are both
-- guarded so this app remains fully functional on its own.
pcall(function()
  ac.onSharedEvent(HUD_THEME_EVENT, receiveHudTheme, true)
end)

local function visualStyle()
  local now = ui.time()
  local synced = now - syncedTheme.lastReceived <= 2.5
  local name = synced and syncedTheme.name or Settings.values.theme
  visual.palette = Theme.get(GlobalSettings.values.theme)
  visual.backdropOpacity = Settings.values.backdropOpacity
  visual.instrumentOpacity = Settings.values.instrumentOpacity
  return visual
end

function M.update(dt)
  if telemetryError then return end
  local ok, errorMessage = pcall(function()
    Telemetry.update(state, dt)
    if state.sessionChanged then History.clear(history) end
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
