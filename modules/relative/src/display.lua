local Relative = require('modules/relative/src/relative')
local Display = {}

function Display.gapText(row, settings)
  if not row.filteredGap then return '...' end
  if math.abs(row.filteredGap) > settings.maximumGap then return '>' .. settings.maximumGap .. 's' end
  return string.format('%+.' .. settings.decimals .. 'f', row.filteredGap)
end

local function specifications(settings)
  return {
    {key='overall', label='POS', sample='999', enabled=settings.showOverall},
    {key='classPosition', label='CP', sample='99', enabled=settings.showClassPosition},
    {key='classID', label='CLASS', sample='UNKNOWN', enabled=settings.showClassText},
    {key='number', label='#', sample='999', enabled=settings.showNumber},
    {key='driver', label='DRIVER', sample='DRIVER', enabled=settings.showDriver},
    {key='pit', label='', sample='PIT', enabled=settings.showPitIndicator},
    {key='lap', label='', sample='+99L', enabled=settings.showLapDifference},
    {key='fast', label='', sample='FAST', enabled=true},
    {key='gap', label='GAP', sample=string.format('%+.' .. settings.decimals .. 'f', settings.maximumGap), enabled=settings.showGap, right=true}
  }
end

function Display.columns(settings, width, size)
  local specs, fixed, gap = specifications(settings), 0, size * 0.4
  for _, column in ipairs(specs) do
    if column.enabled then
      column.width = math.max(ui.measureDWriteText(column.sample, size).x, ui.measureDWriteText(column.label, size).x)
      if column.key ~= 'driver' then fixed = fixed + column.width + gap end
    end
  end
  local columns, x = {}, 0
  for _, column in ipairs(specs) do
    if column.enabled then
      if column.key == 'driver' then column.width = math.max(0, width - fixed - gap) end
      if column.right then column.x = width - column.width else column.x = x end
      columns[#columns + 1] = column
      x = x + column.width + gap
    end
  end
  return columns
end

function Display.fontSize(settings, width, scale)
  local size = settings.fontSize * scale
  local minimum = size * 0.4
  for _, column in ipairs(specifications(settings)) do
    if column.enabled then
      minimum = minimum + math.max(ui.measureDWriteText(column.sample,size).x,
        ui.measureDWriteText(column.label,size).x) + size * 0.4
    end
  end
  return size * math.min(1, width / math.max(1,minimum))
end

function Display.truncate(value, width, size)
  value = tostring(value or 'Unknown driver')
  if ui.measureDWriteText(value,size).x <= width then return value end
  local suffix = '...'
  if ui.measureDWriteText(suffix,size).x > width then return '' end
  while #value > 0 and ui.measureDWriteText(value .. suffix,size).x > width do
    local start = #value
    while start > 1 and value:byte(start) >= 128 and value:byte(start) < 192 do start = start - 1 end
    value = value:sub(1,start-1)
  end
  return value .. suffix
end

function Display.draw(row, isPlayer, player, settings, x1, x2, y, height, size, color)
  local values = row and {
    overall=tostring(row.overall), classPosition=tostring(row.classPosition),
    classID=row.classID or 'UNKNOWN', number=tostring(row.number or '?'), driver=row.driver,
    pit=row.inPitlane and 'PIT' or '', lap=Relative.lapText(row,player) or '',
    fast=row.approaching and 'FAST' or '',
    gap=isPlayer and string.format('%.' .. settings.decimals .. 'f',0) or Display.gapText(row,settings)
  } or nil
  for _, column in ipairs(Display.columns(settings,x2-x1,size)) do
    local value = Display.truncate(values and values[column.key] or column.label,column.width,size)
    local measured = ui.measureDWriteText(value,size)
    local x = x1 + column.x + (column.right and column.width-measured.x or 0)
    ui.dwriteDrawText(value,size,vec2(x,y+(height-measured.y)/2),color)
  end
end
return Display
