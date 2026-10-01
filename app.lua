local DialSettings = require('src/settings')
local Gt7Settings = require('src/gt7_settings')
local ConditionSettings = require('src/condition_settings')
local SettingsUI = require('src/settings_ui')
local Telemetry = require('src/telemetry')
local Instruments = require('src/instrument_state')
local GeneralSettings = require('src/general_settings')
local Dial = require('ui/dial')
local Gt7 = require('ui/gt7_retro')
local Condition = require('ui/car_condition')
local ConditionLayout = require('src/car_condition_layout')

local panels = {
  relative = require('modules/relative/main'),
  delta = require('modules/delta/main'),
  timer = require('modules/timer/main'),
  laps = require('modules/laps/main'),
  leaderboard = require('modules/leaderboard/main'),
  telemetry = require('modules/telemetry/main'),
  map = require('modules/map/main')
}

GeneralSettings.initialize(DialSettings.values, Gt7Settings.values.speedUnit,
  panels.relative.getTemperatureUnit(), panels.leaderboard.getTemperatureUnit())

local dialState = Telemetry.new()
local gt7State = Telemetry.new()
local themeTimer = 1
local lastTheme
local gt7SizeChecked = false
local conditionSizeChecked = false
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
    local resolved = type(values) == 'function' and values() or values
    Telemetry.update(state, dt, resolved)
    if name == 'GT7' and resolved.gt7InstrumentsEnabled then
      Instruments.update(state, resolved, dt)
    end
  end)
  if not ok then reportOnce(name .. ' update', tostring(err)) end
end

local function publishTheme(dt)
  themeTimer = themeTimer + (dt or 0)
  local values = GeneralSettings.values
  local payload = string.format('%s|%.3f|%.3f', values.theme, values.backgroundOpacity, values.opacity)
  if payload ~= lastTheme or themeTimer >= 1 then
    if ac.broadcastSharedEvent then ac.broadcastSharedEvent('retro-engineering-hud/theme/v1', payload) end
    lastTheme, themeTimer = payload, 0
  end
end

function script.update(dt)
  updateCore('dial', dialState, dt, DialSettings.current)
  updateCore('GT7', gt7State, dt, Gt7Settings.current)
  local ok, err = pcall(publishTheme, dt)
  if not ok then reportOnce('theme update', tostring(err)) end
  for _, name in ipairs({ 'relative', 'delta', 'timer', 'laps', 'leaderboard', 'telemetry' }) do
    invoke(name, 'update', dt)
  end
end

function script.windowMain(_)
  Dial.draw(dialState, DialSettings.current())
end

function script.gt7Main(_)
  if not gt7SizeChecked then
    gt7SizeChecked = true
    local width, height = ui.windowWidth(), ui.windowHeight()
    if height > 0 and width < height * 1.25 and ui.setNextWindowSize then
      ui.setNextWindowSize(vec2(math.max(width * 1.25, 720), math.min(height, 360)))
    end
  end
  local settings = Gt7Settings.current()
  Gt7.draw(gt7State, settings)
end

function script.conditionMain(_)
  if ac.setWindowSizeConstraints then
    ac.setWindowSizeConstraints('condition', vec2(240, 210), vec2(1280, 1120))
  end
  if not conditionSizeChecked then
    conditionSizeChecked = true
    local width, height = ui.windowWidth(), ui.windowHeight()
    if height > 0 and width / height < 1.05 and ui.setNextWindowSize then
      ui.setNextWindowSize(vec2(math.max(ConditionLayout.width,
        height * ConditionLayout.width / ConditionLayout.height), math.max(height, ConditionLayout.height)))
    end
  end
  Condition.draw(dialState, ConditionSettings.current())
end

function script.relativeMain(_) invoke('relative', 'windowMain', _) end
function script.deltaMain(_) invoke('delta', 'windowMain', _) end
function script.timerMain(_) invoke('timer', 'windowMain', _) end
function script.lapsMain(_) invoke('laps', 'windowMain', _) end
function script.leaderboardMain(_) invoke('leaderboard', 'windowMain', _) end
function script.telemetryMain(_) invoke('telemetry', 'windowMain', _) end
function script.mapMain(_) invoke('map', 'windowMain', _) end

function script.deltaShow(_) invoke('delta', 'windowShow', _) end
function script.deltaHide(_) invoke('delta', 'windowHide', _) end
function script.leaderboardShow(_) invoke('leaderboard', 'windowShow', _) end

local settingsState = ac.storage({ selectedPage = 'general' }, 'retro-ui.settings-ui.')

local pages = {
  { id = 'general', label = 'General', draw = GeneralSettings.draw },
  { id = 'dial', label = 'Dial', draw = DialSettings.draw },
  { id = 'gt7', label = 'GT7', draw = Gt7Settings.draw },
  { id = 'condition', label = 'Condition', draw = ConditionSettings.draw },
  { id = 'relative', label = 'Relative', draw = function() invoke('relative', 'windowSettings') end },
  { id = 'delta', label = 'Delta', draw = function() invoke('delta', 'windowSettings') end },
  { id = 'timer', label = 'Timer', draw = function() invoke('timer', 'windowSettings') end },
  { id = 'laps', label = 'Laps', draw = function() invoke('laps', 'windowSettings') end },
  { id = 'leaderboard', label = 'Leaderboard', draw = function() invoke('leaderboard', 'windowSettings') end },
  { id = 'telemetry', label = 'Telemetry', draw = function() invoke('telemetry', 'settingsMain') end },
  { id = 'map', label = 'Map', draw = function() invoke('map', 'windowSettings') end }
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
      GeneralSettings.draw()
    end)
  end)
  if not ok then
    reportOnce('settings draw', tostring(err))
    ui.text('Settings error: ' .. tostring(err))
  end
end
