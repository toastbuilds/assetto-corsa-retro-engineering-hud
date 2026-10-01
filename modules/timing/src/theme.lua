local Base = require('modules/delta/src/theme')

local Theme = {}

local function copyPalette(source, purple, purpleDim)
  local target = {}
  for key, value in pairs(source) do target[key] = value end
  target.purple = purple
  target.purpleDim = purpleDim
  return target
end

Theme.palettes = {
  dark = copyPalette(
    Base.get('dark'),
    rgbm(0.70, 0.43, 0.91, 1),
    rgbm(0.28, 0.16, 0.38, 0.94)
  ),
  light = copyPalette(
    Base.get('light'),
    rgbm(0.46, 0.20, 0.66, 1),
    rgbm(0.82, 0.72, 0.90, 0.94)
  )
}

Theme.fonts = Base.fonts
Theme.withAlpha = Base.withAlpha
Theme.blend = Base.blend

function Theme.get(name)
  return Theme.palettes[name] or Theme.palettes.dark
end

return Theme
