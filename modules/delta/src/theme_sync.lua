local GeneralSettings = require('src/general_settings')
local ThemeSync = {}
ThemeSync.__index = ThemeSync

function ThemeSync.new() return setmetatable({}, ThemeSync) end

function ThemeSync:visual()
  return GeneralSettings.values.theme, 0.72, GeneralSettings.values.opacity, true
end

return ThemeSync
