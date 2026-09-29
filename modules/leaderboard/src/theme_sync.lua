local Theme = require('modules/leaderboard/src/theme')
local GlobalSettings = require('src/settings')
local PanelSettings = require('modules/leaderboard/src/settings')

local M = {
  eventName = 'retro-engineering-hud/theme/v1',
  state = { name = 'dark', backdropOpacity = 0.72, instrumentOpacity = 1, lastReceived = -math.huge }
}

local function clampUnit(value, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.max(0, math.min(1, value))
end

local function receive(data)
  if type(data) ~= 'string' then return end
  local name, backdrop, instrument = data:match('^([^|]+)|([^|]+)|([^|]+)$')
  if name ~= 'dark' and name ~= 'light' then return end
  M.state.name = name
  M.state.backdropOpacity = clampUnit(backdrop, 0.72)
  M.state.instrumentOpacity = clampUnit(instrument, 1)
  M.state.lastReceived = ui.time()
end

function M.init()
  -- Retro UI owns the theme.
end

function M.visual(fallbackTheme)
  return {
    palette = Theme.get(GlobalSettings.values.theme),
    backdropOpacity = PanelSettings.values.backdropOpacity,
    instrumentOpacity = PanelSettings.values.instrumentOpacity,
    synced = true
  }
end

return M
