local harness = dofile('tests/gt7_layouts.lua')
local Settings = require('src/gt7_settings')
local DialStyles = require('src/gt7_dial_styles')
local state, values = harness.state, Settings.values

assert(DialStyles.normalize('shelf', 'analog') == 'shelf')
assert(DialStyles.normalize('shelf', 'digital') == 'original')
assert(DialStyles.normalize('bridge', 'digital') == 'bridge')
assert(DialStyles.normalize('bridge', 'analog') == 'original')
assert(#DialStyles.analog == 5 and #DialStyles.digital == 6)

local originalSpeed, originalRpm = values.gt7SpeedDialStyle, values.gt7RpmDialStyle
values.gt7SpeedNeedleMode, values.gt7RpmNeedleMode = 'analog', 'digital'
values.gt7SpeedDialStyle, values.gt7RpmDialStyle = 'shelf', 'orbit'
local current = Settings.current()
assert(current.gt7SpeedDialStyle == 'shelf' and current.gt7RpmDialStyle == 'orbit',
  'speed and RPM styles must persist independently')
values.gt7SpeedNeedleMode = 'digital'
assert(Settings.current().gt7SpeedDialStyle == 'original', 'mode switches must fallback to Original')
values.gt7SpeedNeedleMode, values.gt7SpeedDialStyle = 'analog', 'fan'
package.loaded['src.gt7_settings'] = nil
Settings = require('src.gt7_settings')
assert(Settings.current().gt7SpeedDialStyle == 'fan' and Settings.current().gt7RpmDialStyle == 'orbit',
  'style choices must survive settings proxy reload')
values.gt7SpeedDialStyle, values.gt7RpmDialStyle = 'spoke', 'radial'
harness.pendingButtons['Reset appearance##gt7'] = true
Settings.draw()
assert(values.gt7SpeedDialStyle == 'original' and values.gt7RpmDialStyle == 'original',
  'appearance reset must restore both style selectors to Original')

state.rpmRedline, state.rpmWarning = false, false
state.rpmText, state.rpm, state.rpmGaugeNormalized = '5200', 5200, 0.65
state.speedText, state.speedValue = '139', 139
local function signature(calls)
  local result, hasSpeed, hasRpm = {}, false, false
  for _, call in ipairs(calls) do
    if call.kind == 'arc' and call.a and math.abs(call.a.y - 258) < 0.001
        and (math.abs(call.a.x - 175) < 0.001 or math.abs(call.a.x - 1265) < 0.001) then
      result[#result + 1] = string.format('%.2f:%.4f:%.4f', call.radius, call.startAngle, call.endAngle)
    elseif call.kind == 'polygon' and call.points and call.points[1] then
      local point = call.points[1]
      if (math.abs(point.x - 175) < 160 or math.abs(point.x - 1265) < 160)
          and math.abs(point.y - 258) < 160 then
        result[#result + 1] = string.format('p%.1f:%.1f', point.x, point.y)
      end
    elseif call.kind == 'text' then
      if call.text == '139' then hasSpeed = true end
      if call.text == '5200' then hasRpm = true end
    end
  end
  table.sort(result)
  return table.concat(result, '|') .. '#' .. #calls, hasSpeed, hasRpm
end

for _, mode in ipairs({'analog', 'digital'}) do
  local choices = mode == 'analog' and DialStyles.analog or DialStyles.digital
  local signatures = {}
  for _, choice in ipairs(choices) do
    for _, dial in ipairs({'speed', 'rpm'}) do
      local options = {theme='dark', gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
        gt7SpeedDialStyle='original', gt7RpmDialStyle='original'}
      options[dial == 'speed' and 'gt7SpeedDialStyle' or 'gt7RpmDialStyle'] = choice.value
      local calls = harness.draw('classic', options, state)
      local geometry, speedPresent, rpmPresent = signature(calls)
      assert(speedPresent and (mode == 'analog' or rpmPresent),
        'styles must retain the speed reading and digital RPM value')
      assert(#geometry > 0, 'each dial style must draw its scale bezel')
      signatures[#signatures + 1] = dial .. ':' .. choice.value .. ':' .. geometry
    end
  end
  for _, theme in ipairs({'dark', 'light'}) do
    for _, choice in ipairs(choices) do
      local calls = harness.draw('classic', {theme=theme, gt7SpeedNeedleMode=mode,
        gt7RpmNeedleMode=mode, gt7SpeedDialStyle=choice.value, gt7RpmDialStyle=choice.value}, state)
      local geometry, speedPresent, rpmPresent = signature(calls)
      assert(#geometry > 0 and speedPresent and (mode == 'analog' or rpmPresent),
        'styles must remain legible in both themes: ' .. choice.value)
    end
  end
  -- Every selected variation must change at least one dial's scale geometry.
  for _, choice in ipairs(choices) do
    local calls = harness.draw('classic', {gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
      gt7SpeedDialStyle=choice.value, gt7RpmDialStyle='original'}, state)
    local currentGeometry = signature(calls)
    if choice.value ~= 'original' then
      assert(currentGeometry ~= signature(harness.draw('classic', {
        gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
        gt7SpeedDialStyle='original', gt7RpmDialStyle='original'}, state)),
        'each variation must have recognizable dial geometry: ' .. choice.value)
    end
  end
end

-- These families must change the placement of the primary reading, rather
-- than merely add decorative rings to an otherwise identical face.
local function primaryPosition(style, mode)
  local calls = harness.draw('classic', {gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
    gt7SpeedDialStyle=style, gt7RpmDialStyle='original'}, state)
  for _,call in ipairs(calls) do
    if call.kind=='text' and call.text=='139' and call.size>25 and call.a.x<350 then return call.a end
  end
  error('styled dial must preserve a legible primary reading: ' .. style)
end
local radial, offset, orbit = primaryPosition('radial','digital'),
  primaryPosition('offset','digital'), primaryPosition('orbit','digital')
for _, pair in ipairs({{radial,offset},{radial,orbit},{offset,orbit}}) do
  local a,b=pair[1],pair[2]
  assert(math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)>25,
    'Radial, Offset and Orbit must use visibly different primary reading positions')
end
local shelf, concentric, spoke = primaryPosition('shelf','analog'),
  primaryPosition('concentric','analog'), primaryPosition('spoke','analog')
assert(concentric.y+70<shelf.y and concentric.y+70<spoke.y,
  'Concentric must move the reading into its central core')

state.available, state.fuel, state.maxFuel, state.fuelNormalized = true, 30, 50, 0.6
for _, style in ipairs({'radial','orbit'}) do
  local options={gt7SpeedNeedleMode='digital',gt7RpmNeedleMode='digital',
    gt7SpeedDialStyle=style,gt7RpmDialStyle=style}
  local calls=harness.draw('classic',options,state)
  local lowerBlocks=0
  for _, call in ipairs(calls) do
    if call.kind=='polygon' and call.points and call.points[1] then
      for _,p in ipairs(call.points) do
        local distance=math.sqrt((p.x-175)^2+(p.y-258)^2)
        if math.abs(distance-148)<0.1 and p.y>258 then lowerBlocks=lowerBlocks+1; break end
      end
    end
    assert(not (call.kind=='arc' and call.radius<80 and math.abs(call.a.x-175)<0.1
      and call.a.y>258 and call.a.y<430), 'fuel must use the lower bezel, without a mini dial')
  end
  assert(lowerBlocks>=32,'fuel must span the lower circular rim: '..style)
  state.hybrid={powerKw=120,needle=0.8,charge=0.84}
  local labels={}
  for _,call in ipairs(harness.draw('classic',options,state)) do
    if call.kind=='text' then labels[call.text]=true end
  end
  assert(labels['CHG'] and labels['PWR'] and labels['120 kW'] and labels['84%'],
    'the lower RPM arc must preserve independent hybrid readings')
  state.hybrid=nil
end

values.gt7SpeedDialStyle, values.gt7RpmDialStyle = originalSpeed, originalRpm
print('GT7 dial styles: mode fallback, independent persistence, nine styles, themes and preserved readings passed')
