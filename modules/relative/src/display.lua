local Relative = require('modules/relative/src/relative')

local Display = {}

local function driverWidth(settings, availableWidth, fontSize)
  fontSize = fontSize or settings.fontSize
  local preferred = math.max(8, math.floor(20 * 18 / fontSize + 0.5))
  if not availableWidth then return preferred end
  local fixed = 2 -- row marker and spacing
  if settings.showOverall then fixed = fixed + 3 end
  if settings.showClassPosition then fixed = fixed + 3 end
  if settings.showClassText then fixed = fixed + 6 end
  if settings.showNumber then fixed = fixed + 4 end
  if settings.showGap then fixed = fixed + 7 end
  fixed = fixed + 8 -- reserve room for PIT, lap difference or FAST
  local capacity = math.floor((availableWidth - 34) / (fontSize * 0.56))
  return math.max(6, math.min(preferred, capacity - fixed))
end

local function shorten(value, count)
  value = value or 'Unknown driver'
  return #value > count and value:sub(1, count - 3) .. '...' or value
end

local function add(parts, enabled, value)
  if enabled and value then table.insert(parts, value) end
end

function Display.headerText(settings, availableWidth, fontSize)
  local width = driverWidth(settings, availableWidth, fontSize)
  local parts = {}
  add(parts, settings.showOverall, string.format('%2s', 'POS'))
  add(parts, settings.showClassPosition, string.format('%2s', 'CP'))
  add(parts, settings.showClassText, string.format('%-5s', 'CLASS'))
  add(parts, settings.showNumber, string.format('%3s', '#'))
  add(parts, settings.showDriver, string.format('%-' .. width .. 's', 'DRIVER'))
  add(parts, settings.showGap, string.format('%6s', 'GAP'))
  return ' ' .. table.concat(parts, ' ')
end

function Display.gapText(row, settings)
  if not row.filteredGap then return '...' end
  if math.abs(row.filteredGap) > settings.maximumGap then return '>' .. settings.maximumGap .. 's' end
  return string.format('%+.' .. settings.decimals .. 'f', row.filteredGap)
end

function Display.rowText(row, isPlayer, player, settings, availableWidth, fontSize)
  local width = driverWidth(settings, availableWidth, fontSize)
  local parts = {}
  add(parts, settings.showOverall, string.format('%2d', row.overall))
  add(parts, settings.showClassPosition, string.format('%2d', row.classPosition))
  add(parts, settings.showClassText, string.format('%-5s', row.classID or 'UNKNOWN'))
  add(parts, settings.showNumber, string.format('%3s', tostring(row.number or '?')))
  add(parts, settings.showDriver, string.format('%-' .. width .. 's', shorten(row.driver, width)))
  add(parts, settings.showGap, string.format('%6s', isPlayer and string.format('%.' .. settings.decimals .. 'f', 0) or Display.gapText(row, settings)))
  add(parts, settings.showPitIndicator and row.inPitlane, 'PIT')
  add(parts, settings.showLapDifference, Relative.lapText(row, player))
  add(parts, row.approaching, 'FAST')
  return (isPlayer and '>' or ' ') .. table.concat(parts, ' ')
end

return Display
