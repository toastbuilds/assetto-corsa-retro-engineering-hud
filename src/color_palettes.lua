local M = {}

-- IDs match outputs/variaciones-color. Each row stores the exact preview
-- assignment: background, readings, labels, accent and bezel.
local definitions = {
  ['01'] = {'Midnight Yellow', '11012E', 'FFCC00', 'FFCC00', 'FF018F', '2A0C62'},
  ['02'] = {'Fuchsia Focus', '11012E', 'FF018F', 'FFCC00', 'FFCC00', '2A0C62'},
  ['04'] = {'Inverted Yellow', 'FFCC00', '11012E', '11012E', 'FF018F', '2A0C62'},
  ['05'] = {'Fuchsia Panel', 'FF018F', '11012E', '11012E', 'FFCC00', '2A0C62'},
  ['06'] = {'Dual Neon', '11012E', 'FFCC00', 'FF018F', 'FFCC00', 'FF018F'},
  ['07'] = {'Orange Ash', '212529', 'E9ECEF', 'E9ECEF', 'FB5607', '8338EC'},
  ['08'] = {'Instrument Orange', '212529', 'FB5607', 'E9ECEF', '8338EC', 'FB5607'},
  ['09'] = {'Violet Focus', '8338EC', 'E9ECEF', 'E9ECEF', 'FB5607', '212529'},
  ['10'] = {'Volcanic Paper', 'E9ECEF', '212529', '212529', 'FB5607', '8338EC'},
  ['11'] = {'Inverted Orange', 'FB5607', '212529', '212529', 'E9ECEF', '8338EC'},
  ['12'] = {'Violet Paper', 'E9ECEF', '8338EC', '212529', 'FB5607', '8338EC'},
  ['13'] = {'Lime and Turquoise', '222222', 'FBFF12', '41EAD4', 'FF206E', '41EAD4'},
  ['14'] = {'Turquoise Focus', '222222', '41EAD4', '41EAD4', 'FF206E', 'FBFF12'},
  ['15'] = {'Instrument Pink', '222222', 'FF206E', 'FBFF12', '41EAD4', 'FF206E'},
  ['19'] = {'Cyan Night', '3A0CA3', '4CC9F0', '4CC9F0', 'FF007F', '4361EE'},
  ['22'] = {'Inverted Cyan', '4CC9F0', '3A0CA3', '3A0CA3', 'FF007F', '4361EE'},
  ['25'] = {'Carbon / Cyan / Orange', '212529', '4CC9F0', 'E9ECEF', 'FB5607', '8338EC'},
  ['26'] = {'Midnight / Lime / Pink', '11012E', 'FBFF12', '41EAD4', 'FF007F', '4361EE'},
  ['27'] = {'Paper / Violet / Pink', 'E9ECEF', '3A0CA3', '212529', 'FF206E', '8338EC'},
  ['28'] = {'Carbon / Orange / Turquoise', '222222', 'FB5607', '41EAD4', 'FF018F', '4CC9F0'},
  ['30'] = {'Paper / Carbon / Blue', 'E9ECEF', '212529', '3A0CA3', '4361EE', 'FF007F'},
  ['31'] = {'Turquoise / Midnight / Orange', '41EAD4', '11012E', '212529', 'FB5607', '8338EC'},
  ['32'] = {'Midnight / White / Pink', '11012E', 'E9ECEF', '4CC9F0', 'FF206E', '8338EC'}
}
local order = {
  dark = {'01','02','06','07','08','13','14','15','25','26','28','32'},
  light = {'04','05','09','10','11','12','19','27','22','30','31'}
}
local allowed, choices = {}, {}
for theme, ids in pairs(order) do
  allowed[theme], choices[theme] = {original=true}, {{label='Original', value='original'}}
  for _, id in ipairs(ids) do
    allowed[theme][id] = true
    choices[theme][#choices[theme]+1] = {label=id .. ' - ' .. definitions[id][1], value=id}
  end
end

local function themeName(name) return name == 'light' and 'light' or 'dark' end

function M.normalize(name, id)
  return allowed[themeName(name)][id] and id or 'original'
end

function M.choices(name) return choices[themeName(name)] end

local function color(hex)
  return rgbm(tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255,
    tonumber(hex:sub(5,6),16)/255, 1)
end

local function blend(a, b, amount)
  -- Match the preview's RGB mixtures, including its 8-bit rounding.
  local function channel(x,y) return math.floor((x*amount+y*(1-amount))*255+0.5)/255 end
  return rgbm(channel(a.r,b.r), channel(a.g,b.g), channel(a.b,b.b), 1)
end

local cache = setmetatable({}, {__mode='k'})
function M.resolve(source, name, id)
  id = M.normalize(name, id)
  if id == 'original' then return source end
  local variants = cache[source]
  if not variants then variants = {}; cache[source] = variants end
  if variants[id] then return variants[id] end
  local row = definitions[id]
  local bg, primary, secondary, accent, trim = color(row[2]), color(row[3]), color(row[4]), color(row[5]), color(row[6])
  local result = {}
  -- Preserve module-specific roles, official flags and race classification colors.
  for role, value in pairs(source) do result[role] = value end
  local roles = {
    void=bg, surface=bg, panel=bg, panelRaised=bg, coreAmber=bg, coreRed=bg, debug=bg,
    primary=primary, secondary=secondary, amber=accent, backlight=primary,
    cyan=secondary, shiftBlue=trim, green=secondary, red=accent,
    metal=trim, metalDim=blend(trim,bg,.40), outline=trim,
    outlineSoft=blend(trim,bg,.70), outlineDim=blend(trim,bg,.30), divider=blend(trim,bg,.30),
    amberDim=blend(accent,bg,.25), cyanDim=blend(secondary,bg,.35),
    shiftBlueDim=trim, redDim=accent, inactive=blend(trim,bg,.25)
  }
  for role, value in pairs(roles) do result[role] = value end
  result.flagRed = source.red
  result.flagBlue = source.shiftBlue or source.blue
  result.flagNeutral = source.primary
  variants[id] = result
  return result
end

return M
