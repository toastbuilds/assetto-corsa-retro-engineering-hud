local M = {}
local Settings = require('modules/leaderboard/src/settings')
local ThemeSync = require('modules/leaderboard/src/theme_sync')
local Data = require('modules/leaderboard/src/leaderboard_data')
local Intervals = require('modules/leaderboard/src/intervals')
local Fuel = require('modules/leaderboard/src/fuel')
local Leaderboard = require('modules/leaderboard/ui/leaderboard')
local GlobalSettings = require('src/general_settings')
local WindowAnchor = require('src/window_anchor')

local dataState = Data.new()
local intervalState = Intervals.new()
local fuelState = Fuel.new()
local lastSnapshot = Data.empty()
local lastError = nil

ThemeSync.init()

function M.update(_)
  Settings.values.temperatureUnit = GlobalSettings.values.temperatureUnit
  Settings.normalize()
  local ok, result = pcall(function()
    local snapshot = Data.update(dataState, Settings.values)
    Intervals.update(intervalState, snapshot, Settings.values)
    if snapshot.historyReset then Fuel.reset(fuelState, snapshot.sim and snapshot.sim.currentSessionIndex or 0) end
    snapshot.fuel = Fuel.update(fuelState, snapshot, Settings.values)
    return snapshot
  end)
  if ok and result then
    lastSnapshot, lastError = result, nil
  else
    lastError = tostring(result)
    -- Do not leave stale or blank telemetry onscreen when CSP rejects one
    -- update. The renderer can show this concise fault directly to the driver.
    lastSnapshot = Data.empty()
    lastSnapshot.error = lastError
    pcall(function() ac.error('[Retro Engineering Leaderboard] update error: ' .. lastError) end)
  end
end

function M.getTemperatureUnit() return Settings.values.temperatureUnit end

function M.windowMain(_)
  Settings.values.lockWindow = WindowAnchor.isAnchored('leaderboard')
  local visual = ThemeSync.visual()
  local ok, err = pcall(function() Leaderboard.draw(lastSnapshot, Settings.values, visual) end)
  if not ok then
    pcall(function() ac.error('[Retro Engineering Leaderboard] draw error: ' .. tostring(err)) end)
    ui.text('RETRO ENGINEERING LEADERBOARD')
    ui.text('DRAW ERROR: ' .. tostring(err))
  end
end

function M.windowShow()
  dataState.enteredAt = ui.time()
end

function M.windowSettings()
  Settings.draw()
end

return M
