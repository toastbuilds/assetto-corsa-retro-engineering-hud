-- Compact compositions adapted from the individual dial concepts.
-- Values, needle springs, warning colors and auxiliary telemetry are shared
-- with the original GT7 instruments; only their placement changes here.
local Config = require('src/instrument_config')
local Theme = require('src/theme')
local Light = require('ui/instrument_illumination')
local Needle = require('ui/instrument_needle')
local U = require('src/utils')
local Layout = require('src/gt7_retro_layout')
local DialStyles = require('src/gt7_dial_styles')
local M = {}

local faces = {
  shelf={analog=true, x=0,y=-6,r=147,
    value={-65,91,40},unit={-65,121},aux={70,110,0.60}},
  concentric={analog=true,x=0,y=-6,r=148,
    value={0,-14,43},unit={0,22},aux={0,119,0.60},core={0,-6,69}},
  spoke={analog=true,x=0,y=0,r=147,
    value={-72,83,39},unit={-72,113},aux={72,105,0.66}},
  radial={x=0,y=-6,r=147,
    value={0,12,51},unit={0,47},aux={0,126,0.58},core={0,18,65}},
  offset={x=0,y=0,r=147,
    value={-37,-20,53},unit={-37,20},aux={-37,119,0.55},vertical=true},
  orbit={x=0,y=0,r=148,
    value={0,-16,52},unit={0,22},aux={0,126,0.60},core={0,0,87}}
}

for id, f in pairs(faces) do
  local profile=DialStyles.get(id,f.analog and 'analog' or 'digital')
  f.first, f.last = math.rad(profile.first), math.rad(profile.last)
  f.ticks, f.blocks = {}, {}
  for i=0,80 do
    local a=f.first+(f.last-f.first)*i/80
    f.ticks[i+1]={math.cos(a),math.sin(a),i/80}
  end
  for i=1,40 do
    local a=f.first+(f.last-f.first)*(i-0.88)/40
    local b=f.first+(f.last-f.first)*(i-0.12)/40
    local depth=f.analog and 14 or (f==faces.radial and 22 or 17)
    f.blocks[i]={{f.r*math.cos(a),f.r*math.sin(a)},
      {f.r*math.cos(b),f.r*math.sin(b)},
      {(f.r-depth)*math.cos(b),(f.r-depth)*math.sin(b)},
      {(f.r-depth)*math.cos(a),(f.r-depth)*math.sin(a)}}
  end
end

function M.supports(id) return faces[id] ~= nil end

function M.draw(id, center, scale, state, settings, C, L, digital, light, rpm, rpmColor, auxiliary, lowerAuxiliary)
  local f=faces[id]
  local function p(x,y) return center+vec2(x*scale,y*scale) end
  local pivot=p(f.x,f.y)
  local function line(x1,y1,x2,y2,color,width)
    Light.line(p(x1,y1),p(x2,y2),color,width*scale,L.inner,scale)
  end
  local function arc(radius,first,last,color,width)
    ui.pathClear(); ui.pathArcTo(pivot,radius*scale,first,last,48)
    ui.pathStroke(color,false,width*scale)
  end
  local function label(value,size,x,y,color,style,maxWidth)
    Light.text(value,size*scale,p(x,y),color,maxWidth and maxWidth*scale,style or L.label,scale)
  end
  local function circle(x,y,r,color,width)
    ui.drawCircle(p(x,y),r*scale,Light.color(color,L.inner),64,width*scale)
  end
  local maximum=rpm and math.max((state.rpmGaugeLimiter or 8000)/1000,1) or (state.speedGaugeMaximum or 320)
  local step=rpm and (maximum<=9 and 1 or (maximum<=18 and 2 or math.ceil(maximum/8)))
    or (state.speedGaugeStep or maximum/8)
  local fraction=rpm and U.clamp(state.rpmGaugeNormalized or 0,0,1)
    or U.clamp((state.speedValue or 0)/maximum,0,1)
  local redline=U.clamp((state.rpmDisplayLimiter or 8000)*(state.rpmRedlineFraction or 0.96)
    /math.max(state.rpmGaugeLimiter or 8000,1),0,1)
  local warningColor=C.red
  if rpm and state.rpmRedline and settings.animateRedlineAlert~=false
      and math.floor((state.clock or 0)/Layout.redlineBlinkPeriod)%2~=0 then warningColor=C.amber end
  local value=rpm and (state.rpmText or tostring(U.round(state.rpm or 0))) or state.speedText or '000'

  if id=='shelf' then
    ui.pathClear()
    for _,v in ipairs({{-143,46},{143,46},{108,135},{-108,135}}) do ui.pathLineTo(p(v[1],v[2])) end
    ui.pathFillConvex(C.panelRaised)
    ui.pathClear()
    for _,v in ipairs({{-143,46},{143,46},{108,135},{-108,135}}) do ui.pathLineTo(p(v[1],v[2])) end
    ui.pathStroke(C.metalDim,true,1.5*scale)
    line(5,59,5,138,C.metalDim,1.5)
  elseif id=='spoke' then
    for _, endpoint in ipairs({{-147,58},{147,58},{0,157}}) do
      line(0,0,endpoint[1],endpoint[2],C.metalDim,8)
      line(0,0,endpoint[1],endpoint[2],C.outlineSoft,1)
    end
  elseif id=='offset' then
    ui.drawRectFilled(p(-129,-79),p(58,48),C.panelRaised,12*scale)
    ui.drawRect(p(-129,-79),p(58,48),Light.color(C.cyan,L.inner),12*scale,nil,1*scale)
    line(78,-126,78,139,C.metalDim,2)
  elseif id=='radial' then
    for _, a in ipairs({f.first,f.last}) do
      local x,y=math.cos(a),math.sin(a)
      line(f.x+x*147,f.y+y*147,x*74,18+y*74,C.cyan,1.2)
    end
    circle(0,18,75,C.cyan,1)
  elseif id=='orbit' then
    circle(0,0,99,C.metalDim,2)
    for i=0,59 do
      local a=math.pi*2*i/60
      local inside=i%5==0 and 92 or 95
      line(math.cos(a)*inside,math.sin(a)*inside,
        math.cos(a)*99,math.sin(a)*99,C.secondary,i%5==0 and 1.4 or 0.7)
    end
  end

  if not f.vertical then
    arc(f.r-24,f.first,f.last,C.panelRaised,21)
    if light>0 then
      arc(f.r+4,f.first,(f.first+f.last)/2,L.ringCold,1)
      arc(f.r+4,(f.first+f.last)/2,f.last,L.ringWarm,1)
    end
  end
  if f.analog then
    for i,t in ipairs(f.ticks) do
      local major=(i-1)%10==0
      if not (rpm and t[3]>=redline) then
        local inside=f.r-(major and 16 or 6)
        Light.line(pivot+vec2(t[1]*inside*scale,t[2]*inside*scale),
          pivot+vec2(t[1]*f.r*scale,t[2]*f.r*scale),C.primary,
          (major and 3.6 or 0.8)*scale,major and L.major or L.minor,scale)
      end
    end
    if rpm then
      for i,block in ipairs(f.blocks) do
        if i/40>=redline then Light.segment(pivot,scale,block,
          state.rpmRedline and warningColor or C.redDim,state.rpmRedline and L.segment or L.printedWarning) end
      end
    end
  else
    for i,block in ipairs(f.blocks) do
      local progress=i/40
      local active=i<=math.floor(fraction*40+0.5)
      local color=rpm and (active and rpmColor(progress,true,state,settings)
        or (progress>=redline and C.redDim or C.inactive)) or (active and C.primary or C.inactive)
      if f.vertical then
        local bottom=93-(i-1)*5.2
        ui.drawRectFilled(p(99,bottom-4.1),p(120,bottom),Light.color(color,active and L.segment or nil),0)
      else Light.segment(pivot,scale,block,color,active and L.segment or nil) end
    end
  end

  if f.vertical then
    label('0',12,110,108,C.secondary)
    label(tostring(U.round(maximum)),11,106,-121,C.primary)
    for i=0,8 do line(125,93-i*26,132,93-i*26,C.secondary,1) end
  else
    local n=0
    while n<=maximum+step*0.01 do
      local a=f.first+(f.last-f.first)*n/maximum
      local labelRadius=f.r-(id=='radial' and 38 or 28)
      label(tostring(U.round(n)),f.analog and 16 or 14,
        f.x+labelRadius*math.cos(a),f.y+labelRadius*math.sin(a),C.primary,L.number)
      n=n+step
    end
  end
  if id=='radial' or id=='orbit' then
    lowerAuxiliary(center,scale,state,settings,C,light,rpm,L)
  else
    local aux=f.aux
    local auxScale=scale*aux[3]
    auxiliary(p(aux[1],aux[2])-vec2(0,Config.sub.offsetY*auxScale),auxScale,
      state,settings,C,digital,light,rpm,L)
  end

  if f.analog then
    local needleFraction=rpm and state.gt7RpmNeedleNormalized or state.gt7SpeedNeedleNormalized
    local needleStyle=rpm and settings.gt7RpmNeedleStyle or settings.gt7SpeedNeedleStyle
    local tint=rpm and (state.rpmRedline and warningColor or (state.rpmWarning and C.amber or nil)) or nil
    Needle.draw(pivot,scale*f.r/150,f.first+(f.last-f.first)*U.clamp(needleFraction or fraction,0,1),
      Config.needlePreset(needleStyle),C,light,tint,L)
  end
  if f.core then
    ui.drawCircleFilled(p(f.core[1],f.core[2]),f.core[3]*scale,C.panel,64)
    circle(f.core[1],f.core[2],f.core[3],C.primary,1.2)
    if id=='concentric' then circle(0,-6,78,C.metalDim,4) end
  end
  local v=f.value
  label(value,rpm and v[3]*0.87 or v[3],v[1],v[2],
    rpm and state.rpmRedline and warningColor or C.primary,L.value,id=='offset' and 172 or 150)
  label(rpm and 'RPM' or settings.speedUnit,11,f.unit[1],f.unit[2],C.secondary,L.label)
end

return M
