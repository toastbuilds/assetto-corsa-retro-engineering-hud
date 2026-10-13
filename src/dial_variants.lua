-- Shared by the runtime and the offline shell exporter. Coordinates are in
-- the standalone dial's 620px design space; no telemetry is baked into art.
local M = {}
M.choices = {
  {value='original', label='Original'},
  {value='shelf', label='1 · Classic Shelf'},
  {value='fan', label='3 · Fan'},
  {value='track', label='3A · Track'},
  {value='concentric', label='5 · Concentric'},
  {value='spoke', label='6 · Spoke'}
}
M.layouts = {
  track = {
    shell='shelf',frontLayer=false,
    rpm={310,300,239,-195,25}, speed={310,369,52}, gear={310,451,38},
    rpmValue={310,158},rpmValueSize=18,aux={139,405,104,70},auxStyle='screen',auxIcon=true,
    steeringRing={310,300,56},graduatedSteeringRing=true,clutch={310,506,76},
    pedals={{207,490,207,434},{413,490,413,434}},pedalStyle='line',pedalWidth=7.5,gearBadge={310,451,34},
    statuses={{240,270},{240,326},{380,270},{380,326}},statusRadius=18,
    turns={{229,310},{391,310}},warning={481,500},flag={139,500},needleLength=154
  },
  shelf = {
    rpm={310,310,264,-185,5}, speed={310,418,54}, gear={154,420,56},
    aux={466,419,116,82}, auxStyle='screen',
    rpmValue={310,226}, steering={310,270,57}, clutch={310,470,76},
    pedals={{310,322,185,-177,-126},{310,322,185,-3,-54}}, pedalStyle='arc',
    statuses={{191,514},{255,514},{319,514},{383,514}},
    turns={{229,310},{391,310}}, warning={437,505}, flag={310,549}
  },
  fan = {
    rpm={310,305,250,-183,3}, speed={310,399,56}, gear={310,480,49},
    aux={145,413,115,91}, auxStyle='screen',
    rpmValue={310,229}, steering={310,258,53}, clutch={310,516,57},
    pedals={{246,482,214,375},{374,482,406,375}}, pedalStyle='line',
    statuses={{445,397},{498,397},{445,455},{498,455}},
    turns={{202,528},{418,528}}, warning={310,540}, flag={467,496}
  },
  concentric = {
    rpm={310,304,252,-210,30}, speed={310,315,51}, gear={310,395,49},
    aux={310,304,199,19}, auxStyle='arc',
    hideRpmValue=true,steering={310,210,78}, graduatedSteering=true, clutch={310,442,60},
    pedals={{310,304,165,143,211},{310,304,165,37,-31}}, pedalStyle='arc',
    pairedAux=true,core={310,334,87},
    statuses={{209,520},{271,536},{333,536},{395,522}},
    turns={{131,505},{491,505}}, warning={437,502}, flag={163,487}
  },
  spoke = {
    rpm={310,300,252,-184,4}, speed={164,383,49}, gear={459,383,61},
    aux={310,466,134,89}, auxStyle='screen',
    rpmValue={310,204}, steeringRing={310,300,54}, clutch={310,515,68},
    pedals={{219,326,88,329},{401,326,532,329}}, pedalStyle='line',
    statuses={{137,458},{175,507},{483,458},{445,507}},
    turns={{214,552},{406,552}}, warning={310,540}, flag={373,542}
  }
}
-- Immutable lookup tables and image paths are prepared once, not per frame.
for id, layout in pairs(M.layouts) do
  layout.id = id
  layout.images = {}
  for _, theme in ipairs({'dark','light'}) do
    layout.images[theme] = {back='assets/dial_variants/' .. (layout.shell or id) .. '_' .. theme .. '_back.png'}
    if layout.frontLayer ~= false then
      layout.images[theme].front='assets/dial_variants/' .. (layout.shell or id) .. '_' .. theme .. '_front.png'
    end
  end
  local r = layout.rpm
  layout.startAngle, layout.endAngle = math.rad(r[4]), math.rad(r[5])
  layout.ticks, layout.bands = {}, {}
  for i=0,80 do
    local a = layout.startAngle + (layout.endAngle-layout.startAngle)*i/80
    layout.ticks[i+1] = {math.cos(a), math.sin(a), i/80}
  end
  -- Broad warning blocks match the premium GT7 instrument treatment.
  for i=1,40 do
    local a = layout.startAngle + (layout.endAngle-layout.startAngle)*(i-0.88)/40
    local b = layout.startAngle + (layout.endAngle-layout.startAngle)*(i-0.12)/40
    layout.bands[i] = {
      {r[1]+r[3]*math.cos(a), r[2]+r[3]*math.sin(a)},
      {r[1]+r[3]*math.cos(b), r[2]+r[3]*math.sin(b)},
      {r[1]+(r[3]-20)*math.cos(b), r[2]+(r[3]-20)*math.sin(b)},
      {r[1]+(r[3]-20)*math.cos(a), r[2]+(r[3]-20)*math.sin(a)}
    }
  end
end
function M.normalize(value)
  return M.layouts[value] and value or 'original'
end
function M.get(value) return M.layouts[value] end
return M
