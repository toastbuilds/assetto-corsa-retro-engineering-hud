-- Shared by the runtime and the offline shell exporter. Coordinates are in
-- the standalone dial's 620px design space; no telemetry is baked into art.
local M = {}
M.choices = {
  {value='original', label='Original'},
  {value='shelf', label='1 · Classic Shelf'},
  {value='fan', label='3 · Fan'},
  {value='concentric', label='5 · Concentric'},
  {value='spoke', label='6 · Spoke'}
}
M.layouts = {
  shelf = {
    rpm={310,310,264,-185,5}, speed={310,418,54}, gear={154,420,56},
    aux={466,419,116,82}, auxStyle='screen',
    rpmValue={310,226}, steering={310,270,57}, clutch={310,470,76},
    pedals={{310,322,185,-177,-126},{310,322,185,-54,-3}}, pedalStyle='arc',
    statuses={{191,514},{255,514},{319,514},{383,514}},
    turns={{229,310},{391,310}}, warning={447,514}, flag={310,561}
  },
  fan = {
    rpm={310,305,250,-183,3}, speed={310,399,56}, gear={310,480,49},
    aux={145,413,115,91}, auxStyle='screen',
    rpmValue={310,229}, steering={310,258,53}, clutch={310,516,57},
    pedals={{214,375,246,482},{374,482,406,375}}, pedalStyle='line',
    statuses={{445,397},{498,397},{445,455},{498,455}},
    turns={{202,528},{418,528}}, warning={310,559}, flag={475,511}
  },
  concentric = {
    rpm={310,304,252,-210,30}, speed={310,320,57}, gear={310,405,55},
    aux={310,304,199,19}, auxStyle='arc',
    rpmValue={310,186}, steering={310,231,44}, clutch={310,449,60},
    pedals={{310,304,165,143,211},{310,304,165,-31,37}}, pedalStyle='arc',
    statuses={{197,531},{258,542},{319,544},{380,536}},
    turns={{131,505},{491,505}}, warning={443,523}, flag={310,572}
  },
  spoke = {
    rpm={310,300,252,-184,4}, speed={164,383,49}, gear={459,383,61},
    aux={310,466,134,89}, auxStyle='screen',
    rpmValue={310,204}, steering={310,245,51}, clutch={310,515,68},
    pedals={{88,329,219,326},{401,326,532,329}}, pedalStyle='line',
    statuses={{137,458},{175,507},{483,458},{445,507}},
    turns={{214,552},{406,552}}, warning={310,553}, flag={310,586}
  }
}
-- Immutable lookup tables and image paths are prepared once, not per frame.
for id, layout in pairs(M.layouts) do
  layout.id = id
  layout.images = {}
  for _, theme in ipairs({'dark','light'}) do
    layout.images[theme] = {
      back='assets/dial_variants/' .. id .. '_' .. theme .. '_back.png',
      front='assets/dial_variants/' .. id .. '_' .. theme .. '_front.png'
    }
  end
  local r = layout.rpm
  layout.startAngle, layout.endAngle = math.rad(r[4]), math.rad(r[5])
  layout.ticks, layout.bands = {}, {}
  for i=0,80 do
    local a = layout.startAngle + (layout.endAngle-layout.startAngle)*i/80
    layout.ticks[i+1] = {math.cos(a), math.sin(a), i/80}
  end
  for i=1,64 do
    local a = layout.startAngle + (layout.endAngle-layout.startAngle)*(i-0.88)/64
    local b = layout.startAngle + (layout.endAngle-layout.startAngle)*(i-0.12)/64
    layout.bands[i] = {
      {r[1]+r[3]*math.cos(a), r[2]+r[3]*math.sin(a)},
      {r[1]+r[3]*math.cos(b), r[2]+r[3]*math.sin(b)},
      {r[1]+(r[3]-16)*math.cos(b), r[2]+(r[3]-16)*math.sin(b)},
      {r[1]+(r[3]-16)*math.cos(a), r[2]+(r[3]-16)*math.sin(a)}
    }
  end
end
function M.normalize(value)
  return M.layouts[value] and value or 'original'
end
function M.get(value) return M.layouts[value] end
return M
