local harness = dofile('tests/gt7_layouts.lua')
local state = harness.state

local function values(showLevels)
  local result, label = {}, nil
  for _, call in ipairs(harness.drawDial({instrumentMode='digital', showTcAbsLevels=showLevels}, state)) do
    if call.kind == 'text' then
      if call.text == 'TC' or call.text == 'ABS' then label = call.text
      elseif label then result[label], label = call.text, nil end
    end
  end
  return result
end

for _, sample in ipairs({{tc=2, abs=3}, {tc=4, abs=0}, {tc=false, abs=5}, {tc=2, abs=false}}) do
  state.tcLevel, state.absLevel = sample.tc ~= false and sample.tc or nil, sample.abs ~= false and sample.abs or nil
  local drawn = values(true)
  assert(drawn.TC == (sample.tc ~= false and tostring(sample.tc) or '—'), 'TC must display its own level')
  assert(drawn.ABS == (sample.abs ~= false and tostring(sample.abs) or '—'), 'ABS must display its own level independently of TC')
  drawn = values(false)
  assert(drawn.TC == (sample.tc ~= false and 'ON' or '—'))
  assert(drawn.ABS == (sample.abs ~= false and 'ON' or '—'))
end
print('Dial electronics: independent ABS/TC levels, zero, unavailable channels and hidden levels passed')
