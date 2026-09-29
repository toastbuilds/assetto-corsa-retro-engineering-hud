local DialSettings = require('src/settings')
local Gt7Settings = require('src/gt7_settings')
local ConditionSettings = require('src/condition_settings')
local SettingsUI = require('src/settings_ui')
local Telemetry = require('src/telemetry')
local Dial = require('ui/dial')
local Gt7 = require('ui/gt7_retro')
local Condition = require('ui/car_condition')

local panels = {
  relative = require('modules/relative/main'),
  delta = require('modules/delta/main'),
  leaderboard = require('modules/leaderboard/main'),
  telemetry = require('modules/telemetry/main')
}

if (DialSettings.values.sharedUnitsVersion or 0) < 1 then
  if Gt7Settings.values.speedUnit == 'mph' then DialSettings.values.speedUnit = 'mph' end
  if panels.relative.getTemperatureUnit() == 'F' or panels.leaderboard.getTemperatureUnit() == 'F' then
    DialSettings.values.temperatureUnit = 'F'
  end
  DialSettings.values.sharedUnitsVersion = 1
end

local dialState = Telemetry.new()
local gt7State = Telemetry.new()
local themeTimer = 1
local lastTheme
local gt7SizeChecked = false
local settingsSizeChecked = false
local lastErrors = {}

local function reportOnce(key, message)
  if lastErrors[key] == message then return end
  lastErrors[key] = message
  pcall(function() ac.error('[Retro UI ' .. key .. '] ' .. message) end)
end

local function invoke(name, method, ...)
  local panel = panels[name]
  if not panel or not panel[method] then return end
  local ok, err = pcall(panel[method], ...)
  if not ok then
    local message = tostring(err)
    reportOnce(name .. ' ' .. method, message)
    if method ~= 'update' then ui.text(name .. ': ' .. message) end
  end
end

local function updateCore(name, state, dt, values)
  local ok, err = pcall(function()
    Telemetry.update(state, dt, type(values) == 'function' and values() or values)
  end)
  if not ok then reportOnce(name .. ' update', tostring(err)) end
end

local function publishTheme(dt)
  themeTimer = themeTimer + (dt or 0)
  local values = DialSettings.values
  local payload = string.format('%s|%.3f|%.3f', values.theme, values.backgroundOpacity, values.opacity)
  if payload ~= lastTheme or themeTimer >= 1 then
    if ac.broadcastSharedEvent then ac.broadcastSharedEvent('retro-engineering-hud/theme/v1', payload) end
    lastTheme, themeTimer = payload, 0
  end
end

function script.update(dt)
  updateCore('dial', dialState, dt, DialSettings.values)
  updateCore('GT7', gt7State, dt, Gt7Settings.current)
  local ok, err = pcall(publishTheme, dt)
  if not ok then reportOnce('theme update', tostring(err)) end
  for _, name in ipairs({ 'relative', 'delta', 'leaderboard', 'telemetry' }) do
    invoke(name, 'update', dt)
  end
end

function script.windowMain(_)
  Dial.draw(dialState, DialSettings.values)
end

function script.gt7Main(_)
  if not gt7SizeChecked then
    gt7SizeChecked = true
    local width, height = ui.windowWidth(), ui.windowHeight()
    if height > 0 and width < height * 1.25 and ui.setNextWindowSize then
      ui.setNextWindowSize(vec2(math.max(width * 1.25, 720), math.min(height, 360)))
    end
  end
  Gt7.draw(gt7State, Gt7Settings.current())
end

function script.conditionMain(_)
  Condition.draw(dialState, ConditionSettings.current(DialSettings.values))
end

function script.relativeMain(_) invoke('relative', 'windowMain', _) end
function script.deltaMain(_) invoke('delta', 'windowMain', _) end
function script.leaderboardMain(_) invoke('leaderboard', 'windowMain', _) end
function script.telemetryMain(_) invoke('telemetry', 'windowMain', _) end

function script.deltaShow(_) invoke('delta', 'windowShow', _) end
function script.deltaHide(_) invoke('delta', 'windowHide', _) end
function script.leaderboardShow(_) invoke('leaderboard', 'windowShow', _) end

local settingsState = ac.storage({ selectedPage = 'general' }, 'retro-ui.settings-ui.')

local function drawGeneral()
  local values = DialSettings.values
  ui.header('General')
  SettingsUI.section('general', 'theme', 'Theme and units', true, function()
    SettingsUI.choice('general', 'theme', 'Theme', values.theme,
      { { label = 'Dark', value = 'dark' }, { label = 'Light', value = 'light' } },
      function(value) values.theme = value end)
    SettingsUI.choice('general', 'speed', 'Speed', values.speedUnit,
      { { label = 'km/h', value = 'km/h' }, { label = 'mph', value = 'mph' } },
      function(value) values.speedUnit = value end)
    SettingsUI.choice('general', 'temperature', 'Temperature', values.temperatureUnit,
      { { label = 'Celsius', value = 'C' }, { label = 'Fahrenheit', value = 'F' } },
      function(value) values.temperatureUnit = value end)
  end)
  SettingsUI.section('general', 'reset', 'Reset', false, function()
    SettingsUI.resetAll('general', function()
      values.theme, values.speedUnit, values.temperatureUnit = 'dark', 'km/h', 'C'
    end, 'Restore the shared theme, speed and temperature units?')
  end)
end

local pages = {
  { id = 'general', label = 'General', draw = drawGeneral },
  { id = 'dial', label = 'Dial', draw = DialSettings.draw },
  { id = 'gt7', label = 'GT7', draw = Gt7Settings.draw },
  { id = 'condition', label = 'Condition', draw = ConditionSettings.draw },
  { id = 'relative', label = 'Relative', draw = function() invoke('relative', 'windowSettings') end },
  { id = 'delta', label = 'Delta', draw = function() invoke('delta', 'windowSettings') end },
  { id = 'leaderboard', label = 'Leaderboard', draw = function() invoke('leaderboard', 'windowSettings') end },
  { id = 'telemetry', label = 'Telemetry', draw = function() invoke('telemetry', 'settingsMain') end }
}

function script.settingsMain(_)
  local ok, err = pcall(function()
    if not settingsSizeChecked then
      settingsSizeChecked = true
      local width, height = ui.windowWidth(), ui.windowHeight()
      if width < 650 and ui.setNextWindowSize then
        ui.setNextWindowSize(vec2(800, math.max(height, 600)))
      end
    end
    ui.header('Retro UI Settings')
    local available = ui.availableSpace()
    ui.childWindow('retro-ui-navigation', vec2(158, available.y), function()
      for _, page in ipairs(pages) do
        local selected = settingsState.selectedPage == page.id
        if ui.button((selected and '> ' or '  ') .. page.label .. '##nav-' .. page.id,
            vec2(ui.availableSpaceX(), 30)) then
          settingsState.selectedPage = page.id
        end
      end
    end)
    ui.sameLine()
    ui.childWindow('retro-ui-content-' .. settingsState.selectedPage, ui.availableSpace(), function()
      for _, page in ipairs(pages) do
        if settingsState.selectedPage == page.id then page.draw(); return end
      end
      settingsState.selectedPage = 'general'
      drawGeneral()
    end)
  end)
  if not ok then
    reportOnce('settings draw', tostring(err))
    ui.text('Settings error: ' .. tostring(err))
  end
end
