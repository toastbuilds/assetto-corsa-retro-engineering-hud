local SettingsUI = require('src/settings_ui')
local ColorPalettes = require('src/color_palettes')
local M = {}
local defaults = {
  version = 0, theme = 'dark', darkPalette = 'original', lightPalette = 'original',
  speedUnit = 'km/h', temperatureUnit = 'C', pressureUnit = 'psi',
  opacity = 1, backgroundOpacity = 0.72,
  pedalDisplay = 'estimated',
  cornerGearHint = true,
  rpmWarningFraction = 0.86, rpmRedlineFraction = 0.96, fallbackRpm = 8000,
  animateIndicators = true, animateFlagAlert = true,
  animateShiftAlert = true, animateRedlineAlert = true
}
M.values = ac.storage(defaults, 'retro-ui.general.')

local function clamp(value, low, high, fallback)
  value = tonumber(value)
  if not value or value ~= value then return fallback end
  return math.max(low, math.min(high, value))
end

function M.initialize(legacy, gt7SpeedUnit, relativeTemperatureUnit, leaderboardTemperatureUnit)
  if (M.values.version or 0) >= 1 then M.normalize(); return end
  -- Newly shared appearance/alerts intentionally start at factory defaults.
  for key, value in pairs(defaults) do
    if key ~= 'version' then M.values[key] = value end
  end
  M.values.theme = legacy.theme
  M.values.speedUnit = legacy.speedUnit
  M.values.temperatureUnit = legacy.temperatureUnit
  if (legacy.sharedUnitsVersion or 0) < 1 then
    if gt7SpeedUnit == 'mph' then M.values.speedUnit = 'mph' end
    if relativeTemperatureUnit == 'F' or leaderboardTemperatureUnit == 'F' then
      M.values.temperatureUnit = 'F'
    end
  end
  M.values.version = 1
  M.normalize()
end

function M.normalize()
  local v = M.values
  v.theme = v.theme == 'light' and 'light' or 'dark'
  v.pedalDisplay = v.pedalDisplay == 'classic' and 'classic' or 'estimated'
  v.cornerGearHint = v.cornerGearHint ~= false
  v.darkPalette = ColorPalettes.normalize('dark', v.darkPalette)
  v.lightPalette = ColorPalettes.normalize('light', v.lightPalette)
  v.speedUnit = v.speedUnit == 'mph' and 'mph' or 'km/h'
  v.temperatureUnit = v.temperatureUnit == 'F' and 'F' or 'C'
  v.pressureUnit = (v.pressureUnit == 'bar' or v.pressureUnit == 'kPa') and v.pressureUnit or 'psi'
  v.opacity = clamp(v.opacity, 0, 1, 1)
  v.backgroundOpacity = clamp(v.backgroundOpacity, 0, 1, 0.72)
  v.rpmRedlineFraction = clamp(v.rpmRedlineFraction, 0.82, 1, 0.96)
  v.rpmWarningFraction = math.min(clamp(v.rpmWarningFraction, 0.70, 0.98, 0.86),
    v.rpmRedlineFraction - 0.04)
  v.fallbackRpm = clamp(v.fallbackRpm, 4000, 16000, 8000)
  for _, key in ipairs({'animateIndicators', 'animateFlagAlert', 'animateShiftAlert', 'animateRedlineAlert'}) do
    v[key] = v[key] ~= false
  end
end

function M.apply(target)
  M.normalize()
  for key in pairs(defaults) do
    if key ~= 'version' then target[key] = M.values[key] end
  end
  target.instrumentOpacity, target.backdropOpacity = M.values.opacity, M.values.backgroundOpacity
  return target
end

function M.selectedPalette(name)
  name = name == 'light' and 'light' or 'dark'
  return ColorPalettes.normalize(name, M.values[name .. 'Palette'])
end

function M.themePalette(source, name)
  return ColorPalettes.resolve(source, name, M.selectedPalette(name))
end

-- Draw backgrounds at their authored 72% reference, then scale their colors
-- once. This retains different materials and removes minimum-opacity floors.
local backgroundRoles = { void=true, surface=true, panel=true, panelRaised=true,
  coreAmber=true, coreRed=true, debug=true }
local paletteCache = setmetatable({}, {__mode='k'})
local colorFactors = setmetatable({}, {__mode='k'})
function M.background(alpha, opacity)
  return math.max(0, math.min(1, alpha * clamp(opacity == nil and M.values.backgroundOpacity or opacity, 0, 1, 0.72) / 0.72))
end

function M.palette(source, opacity)
  opacity = clamp(opacity == nil and M.values.backgroundOpacity or opacity, 0, 1, 0.72)
  if opacity == 0.72 then return source end
  local cached = paletteCache[source]
  if cached and cached.opacity == opacity then return cached.palette end
  local result, factor = {}, opacity / 0.72
  for role, color in pairs(source) do
    if backgroundRoles[role] then
      local scaled = rgbm(color.r, color.g, color.b, math.min(1, color.mult * factor))
      result[role], colorFactors[scaled] = scaled, factor
    else result[role] = color end
  end
  paletteCache[source] = {opacity=opacity, palette=result}
  return result
end

function M.color(color, alpha)
  return rgbm(color.r, color.g, color.b, math.max(0, math.min(1, alpha * (colorFactors[color] or 1))))
end

local function percent(label, key, low, high)
  local value, changed = ui.slider(label, M.values[key] * 100, low * 100, high * 100, '%.0f%%', 1)
  if changed then M.values[key] = value / 100 end
end

function M.draw()
  M.normalize()
  ui.header('General')
  SettingsUI.section('general', 'basics', 'Basics', true, function()
    SettingsUI.choice('general', 'theme', 'Theme', M.values.theme,
      {{label='Dark', value='dark'}, {label='Light', value='light'}}, function(v) M.values.theme=v end)
    local paletteKey = M.values.theme .. 'Palette'
    SettingsUI.choice('general', 'palette', 'Color palette', M.values[paletteKey],
      ColorPalettes.choices(M.values.theme), function(v) M.values[paletteKey]=v end)
    SettingsUI.choice('general', 'speed', 'Speed unit', M.values.speedUnit,
      {{label='km/h', value='km/h'}, {label='mph', value='mph'}}, function(v) M.values.speedUnit=v end)
    SettingsUI.choice('general', 'temperature', 'Temperature unit', M.values.temperatureUnit,
      {{label='Celsius', value='C'}, {label='Fahrenheit', value='F'}}, function(v) M.values.temperatureUnit=v end)
    SettingsUI.choice('general', 'pressure', 'Pressure unit', M.values.pressureUnit,
      {{label='psi', value='psi'}, {label='bar', value='bar'}, {label='kPa', value='kPa'}}, function(v) M.values.pressureUnit=v end)
    percent('Content opacity', 'opacity', 0, 1)
    percent('Background opacity', 'backgroundOpacity', 0, 1)
    SettingsUI.choice('general', 'pedals', 'Pedal display', M.values.pedalDisplay,
      {{label='Estimated dual-layer', value='estimated'}, {label='Classic', value='classic'}},
      function(v) M.values.pedalDisplay=v end)
    ui.textWrapped('Dial and GT7: white pedal input with an estimated colored output overlaid at the same width. TC/ABS, shift cut and auto-blip can change its length. Output is an approximation, not measured engine torque or braking force. Missing physics data shows input only.')
    if ui.checkbox('Suggested corner gear', M.values.cornerGearHint) then
      M.values.cornerGearHint = not M.values.cornerGearHint
    end
    ui.textWrapped('Shows a gear for the next corner on GT7 and Dial while driving. Uses the track AI line and car ratios; hidden when track or car data is unavailable.')
  end)
  SettingsUI.section('general', 'personalization', 'Personalization', false, function()
    ui.text('RPM and alerts - Dial and GT7')
    percent('RPM warning threshold', 'rpmWarningFraction', 0.70, 0.98)
    percent('RPM redline threshold', 'rpmRedlineFraction', 0.82, 1)
    for _, item in ipairs({{'Blink turn indicators','animateIndicators'}, {'Blink race flag alert','animateFlagAlert'},
      {'Blink shift zone','animateShiftAlert'}, {'Blink redline alert','animateRedlineAlert'}}) do
      if ui.checkbox(item[1], M.values[item[2]]) then M.values[item[2]] = not M.values[item[2]] end
    end
  end)
  SettingsUI.section('general', 'advanced', 'Advanced', false, function()
    local value, changed = ui.slider('RPM limit fallback', M.values.fallbackRpm, 4000, 16000, '%.0f rpm', 1)
    if changed then M.values.fallbackRpm = value end
    ui.textWrapped('Used by Dial and GT7 when the car does not provide an RPM limiter.')
  end)
  M.normalize()
  ui.separator()
  SettingsUI.resetAppearance('general', function()
    M.values.theme, M.values.opacity, M.values.backgroundOpacity = 'dark', 1, 0.72
    M.values.darkPalette, M.values.lightPalette = 'original', 'original'
  end)
  SettingsUI.resetAll('general', function()
    for key, value in pairs(defaults) do if key ~= 'version' then M.values[key] = value end end
  end, 'Restore the shared theme, color palettes, units, opacity, pedal display and Dial/GT7 alerts for all instruments?')
end

return M
