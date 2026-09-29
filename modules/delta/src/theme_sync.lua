local ThemeSync = {}
local GlobalSettings = require('src/settings')
ThemeSync.__index = ThemeSync

local EVENT_NAME = 'retro-engineering-hud/theme/v1'
local EXPIRY_SECONDS = 2.5

local function clampUnit(value, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.max(0, math.min(1, value))
end

function ThemeSync.new()
  local self = setmetatable({
    name = 'dark',
    backdropOpacity = 0.72,
    instrumentOpacity = 1,
    lastReceived = nil
  }, ThemeSync)
  return self
end

function ThemeSync:visual(now)
  return GlobalSettings.values.theme, 0.72, 1, true
end

return ThemeSync
