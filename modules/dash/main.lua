local Settings = require('modules/dash/src/settings')
local Theme = require('src/theme')
local GeneralSettings = require('src/general_settings')
local Panel = require('modules/dash/ui/dash_panel')

local M = {}

function M.windowMain(state)
  Panel.draw(state, Settings.current(), {
    palette = GeneralSettings.palette(Theme.get(GeneralSettings.themeName('dash'), 'dash')),
    contentOpacity = GeneralSettings.values.opacity,
    pressureUnit = GeneralSettings.values.pressureUnit,
    speedUnit = GeneralSettings.values.speedUnit,
    theme = GeneralSettings.themeName('dash'),
    light = state.available and state.gt7Instruments and state.gt7Instruments.light
      or (state.available and state.lightsAvailable and state.headlights and 1 or 0),
    animateIndicators = GeneralSettings.values.animateIndicators,
  })
end

function M.settingsMain()
  Settings.draw()
end

return M
