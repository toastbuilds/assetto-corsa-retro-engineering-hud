local SettingsUI = require('src/settings_ui')

local M = {}

M.values = ac.storage({
  mode = 'full',
  miniOrientation = 'heading',
  miniRadius = 500,
  backgroundMode = 'dots',
  surfaceOpacity = 0.45,
  dotOpacity = 0.12,
  dotThickness = 1.15,
  radialDotTaper = true,
  markerScale = 1.25,
  pathWidth = 1.00,
  carDotSize = 4.0
}, 'retro-ui.map.')

local function resetAppearance()
  M.values.backgroundMode = 'dots'
  M.values.surfaceOpacity = 0.45
  M.values.dotOpacity = 0.12
  M.values.dotThickness = 1.15
  M.values.radialDotTaper = true
  M.values.markerScale = 1.25
  M.values.pathWidth = 1.00
  M.values.carDotSize = 4.0
end

local function resetAll()
  M.values.mode = 'full'
  M.values.miniOrientation = 'heading'
  M.values.miniRadius = 500
  resetAppearance()
end

function M.current()
  local values = M.values
  if values.mode ~= 'mini' then values.mode = 'full' end
  if values.miniOrientation ~= 'fixed' then values.miniOrientation = 'heading' end
  if values.backgroundMode ~= 'surface' then values.backgroundMode = 'dots' end
  values.miniRadius = math.max(200, math.min(1200, tonumber(values.miniRadius) or 500))
  values.surfaceOpacity = math.max(0, math.min(1, tonumber(values.surfaceOpacity) or 0.45))
  values.dotOpacity = math.max(0, math.min(0.28, tonumber(values.dotOpacity) or 0.12))
  values.dotThickness = math.max(0.50, math.min(4.00, tonumber(values.dotThickness) or 1.15))
  values.radialDotTaper = values.radialDotTaper ~= false
  values.markerScale = math.max(0.80, math.min(2.00, tonumber(values.markerScale) or 1.25))
  values.pathWidth = math.max(0.50, math.min(4.00, tonumber(values.pathWidth) or 1.00))
  values.carDotSize = math.max(2.0, math.min(8.0, tonumber(values.carDotSize) or 4.0))
  return values
end

function M.draw()
  local values = M.current()
  ui.header('Map')
  SettingsUI.section('map', 'view', 'View', true, function()
    SettingsUI.choice('map', 'mode', 'Mode', values.mode,
      { { label = 'Full circuit', value = 'full' }, { label = 'Mini map', value = 'mini' } },
      function(value) values.mode = value end)
    ui.textWrapped('The mini map follows your car. The window retains its size when changing mode.')
    if values.mode == 'mini' then
      SettingsUI.choice('map', 'miniOrientation', 'Orientation', values.miniOrientation,
        { { label = 'Follow heading', value = 'heading' }, { label = 'Fixed circuit', value = 'fixed' } },
        function(value) values.miniOrientation = value end)
      local radius, changed = ui.slider('Visible radius', values.miniRadius, 200, 1200, '%.0f m', 1)
      if changed then values.miniRadius = radius end
    end
  end)
  SettingsUI.section('map', 'appearance', 'Appearance', true, function()
    SettingsUI.choice('map', 'backgroundMode', 'Background', values.backgroundMode,
      { { label = 'Dots', value = 'dots' }, { label = 'Surface', value = 'surface' } },
      function(value) values.backgroundMode = value end)
    if values.backgroundMode == 'surface' then
      local surface, surfaceChanged = ui.slider('Radial surface', values.surfaceOpacity * 100,
        0, 100, '%.0f%%', 1)
      if surfaceChanged then values.surfaceOpacity = surface / 100 end
      ui.textWrapped('Race flag alerts color the track.')
    else
      local opacity, changed = ui.slider('Background dots', values.dotOpacity * 100, 0, 28, '%.0f%%', 1)
      if changed then values.dotOpacity = opacity / 100 end
      local dotThickness, thicknessChanged = ui.slider('Dot thickness', values.dotThickness,
        0.50, 4.00, '%.2fx', 1)
      if thicknessChanged then values.dotThickness = dotThickness end
      if ui.checkbox('Radial dot taper', values.radialDotTaper) then
        values.radialDotTaper = not values.radialDotTaper
      end
    end
    local markerScale, markerChanged = ui.slider('Highlighted markers', values.markerScale,
      0.80, 2.00, '%.2fx', 1)
    if markerChanged then values.markerScale = markerScale end
    local pathWidth, pathChanged = ui.slider('Track width', values.pathWidth,
      0.50, 4.00, '%.2fx', 1)
    if pathChanged then values.pathWidth = pathWidth end
    local carDotSize, carDotChanged = ui.slider('Car dots', values.carDotSize,
      2.0, 8.0, '%.1f px', 1)
    if carDotChanged then values.carDotSize = carDotSize end
    ui.textWrapped('Set the selected background opacity to 0% for a fully clear background.')
    SettingsUI.resetAppearance('map', resetAppearance)
  end)
  SettingsUI.section('map', 'reset', 'Reset', false, function()
    SettingsUI.resetAll('map', resetAll, 'Restore map mode, mini orientation, zoom and appearance?')
  end)
end

return M
