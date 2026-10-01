local Theme = require('modules/leaderboard/src/theme')
local GeneralSettings = require('src/general_settings')
local M = {}

function M.init() end

function M.visual()
  return {
    palette = GeneralSettings.palette(Theme.get(GeneralSettings.values.theme)),
    backdropOpacity = 0.72,
    instrumentOpacity = GeneralSettings.values.opacity,
    synced = true
  }
end

return M
