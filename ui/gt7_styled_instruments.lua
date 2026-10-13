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
local Selector = require('src/gear_selector')
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

local inspiredFaces = {
  analog = {
    track_analog={analog=true,motif='track',x=0,y=0,r=147,value={0,28,42},unit={0,56},aux={0,128,0.92}},
    halo_analog={analog=true,motif='halo',x=0,y=-4,r=147,value={0,28,44},unit={0,56},aux={0,128,0.92}},
    jewel_analog={analog=true,motif='jewel',x=0,y=0,r=147,value={0,28,44},unit={0,56},aux={0,128,0.92}},
    spectrum_analog={analog=true,motif='spectrum',x=0,y=0,r=147,value={0,28,44},unit={0,56},aux={0,128,0.92}},
    snap_analog={analog=true,motif='snap',x=0,y=0,r=147,value={-8,58,20},unit={38,59},aux={0,134,0.9}}
  },
  digital = {
    halo_digital={motif='halo',x=0,y=-4,r=147,value={0,-10,54},unit={0,22},aux={0,106,1}},
    jewel_digital={motif='jewel',x=0,y=-4,r=147,value={0,-10,54},unit={0,22},aux={0,106,1}},
    spectrum_digital={motif='spectrum',x=0,y=0,r=147,value={0,-10,54},unit={0,22},aux={0,106,1}},
    snap_digital={motif='snap',x=0,y=0,r=147,value={-8,58,20},unit={38,59},aux={0,134,0.9}}
  }
}

for mode, group in pairs(inspiredFaces) do
  for id, f in pairs(group) do
    local profile=DialStyles.get(id,mode,id:match('^snap_') and 'rpm' or 'speed')
    f.first,f.last=math.rad(profile.first),math.rad(profile.last)
  end
end

local function resolveFace(id,mode)
  if mode and inspiredFaces[mode] and inspiredFaces[mode][id] then
    return inspiredFaces[mode][id],true
  end
  return faces[id],false
end

function M.supports(id,mode,role)
  if id:match('^snap_') and role~='rpm' then return false end
  local face=resolveFace(id,mode)
  return face~=nil
end

local selectorAnimations=setmetatable({}, {__mode='k'})
local drawSnapSelector

local function drawInspired(id,f,center,scale,state,settings,C,L,digital,light,rpm,rpmColor,
    auxiliary,lowerAuxiliary,useLowerArc)
  local motif=f.motif
  local dotsOnly=motif=='halo' or motif=='jewel'
  local pivot=center+vec2(f.x*scale,f.y*scale)
  local function p(x,y) return center+vec2(x*scale,y*scale) end
  local function line(x1,y1,x2,y2,color,width)
    Light.line(p(x1,y1),p(x2,y2),color,width*scale,L.inner,scale)
  end
  local function arc(radius,first,last,color,width,steps)
    ui.pathClear()
    ui.pathArcTo(pivot,radius*scale,math.min(first,last),math.max(first,last),steps or 48)
    ui.pathStroke(color,false,width*scale)
  end
  local function label(value,size,x,y,color,style,maxWidth)
    Light.text(value,size*scale,p(x,y),color,maxWidth and maxWidth*scale,style or L.label,scale)
  end
  local function filledCircle(x,y,r,color,style)
    ui.drawCircleFilled(p(x,y),r*scale,Light.color(color,style or L.segment),32)
  end
  local maximum=rpm and math.max((state.rpmGaugeLimiter or 8000)/1000,1)
    or (state.speedGaugeMaximum or 320)
  local step=rpm and (maximum<=9 and 1 or maximum<=18 and 2 or math.ceil(maximum/8))
    or (state.speedGaugeStep or maximum/8)
  local fraction=rpm and U.clamp(state.rpmGaugeNormalized or 0,0,1)
    or U.clamp((state.speedValue or 0)/math.max(maximum,1),0,1)
  local redline=U.clamp((state.rpmDisplayLimiter or 8000)*(state.rpmRedlineFraction or 0.96)
    /math.max(state.rpmGaugeLimiter or 8000,1),0,1)
  local function progressInk(progress)
    if rpm then return rpmColor(progress,true,state,settings) end
    if progress<0.48 then return C.cyan end
    if progress<0.78 then return C.amber end
    return C.red
  end
  local function arcValue(progress)
    local color=progressInk(progress)
    if rpm and progress>=redline and not state.rpmRedline then color=C.redDim end
    return color
  end
  local value=rpm and (state.rpmText or tostring(U.round(state.rpm or 0))) or state.speedText or '000'
  local valueColor=rpm and state.rpmRedline and C.red or C.primary

  ui.drawCircleFilled(center,f.r*scale,Theme.withAlpha(C.panel,0.88),72)
  if not dotsOnly and motif~='spectrum' then
    arc(f.r-23,f.first,f.last,C.panelRaised,20)
  end
  if light>0 and not dotsOnly then
    arc(f.r+3,f.first,(f.first+f.last)/2,L.ringCold,1)
    arc(f.r+3,(f.first+f.last)/2,f.last,L.ringWarm,1)
  end

  if f.analog and not dotsOnly then
    local divisions=math.max(1,math.ceil(maximum/step*10))
    for i=0,divisions do
      local fraction=i/divisions
      local a=f.first+(f.last-f.first)*fraction
      local major=i%10==0 or i==divisions
      if not (rpm and fraction>=redline) then
        local outer=motif=='spectrum' and f.r+10 or f.r
        local inner=outer-(major and 12 or i%5==0 and 7 or 4)
        local ink=i%5==0 and C.primary or C.secondary
        line(f.x+inner*math.cos(a),f.y+inner*math.sin(a),
          f.x+outer*math.cos(a),f.y+outer*math.sin(a),ink,major and 2.8 or 0.85)
      end
    end
    if rpm and motif~='spectrum' then
      for i=1,28 do
        local a=f.first+(f.last-f.first)*(i-0.88)/28
        local b=f.first+(f.last-f.first)*(i-0.12)/28
        if i/28>=redline then
          arc(f.r-4,a,b,state.rpmRedline and arcValue(i/28) or C.redDim,9,3)
        end
      end
    end
  elseif not f.analog and not dotsOnly and motif~='spectrum' then
    for i=1,40 do
      local a=f.first+(f.last-f.first)*(i-0.86)/40
      local b=f.first+(f.last-f.first)*(i-0.14)/40
      local progress=i/40
      local active=progress<=fraction
      local color=active and arcValue(progress) or (rpm and progress>=redline and C.redDim or C.inactive)
      arc(f.r-7,a,b,color,12,3)
    end
  end

  if motif=='track' then
    arc(83,f.first,f.last,C.outlineDim,2)
    for i=1,28 do
      local a=f.first+(f.last-f.first)*(i-0.84)/28
      local b=f.first+(f.last-f.first)*(i-0.16)/28
      arc(83,a,b,i/28<=fraction and arcValue(i/28) or C.inactive,4.5,3)
    end
    for _,a in ipairs({f.first,f.last}) do
      local x,y=math.cos(a),math.sin(a)
      line(f.x+x*89,f.y+y*89,f.x+x*98,f.y+y*98,C.amber,2)
    end
  elseif motif=='halo' then
    for i=0,16 do
      if i~=8 then
        local progress=i/16
        local a=f.first+(f.last-f.first)*progress
        local active=progress<=fraction or (rpm and state.rpmRedline and progress>=redline)
        local ink=active and arcValue(progress) or (rpm and progress>=redline and C.redDim or C.outlineDim)
        filledCircle(f.x+(f.r-4)*math.cos(a),f.y+(f.r-4)*math.sin(a),6,ink,
          active and L.segment or L.printedWarning)
      end
    end
    ui.pathClear()
    ui.pathLineTo(p(f.x-7,f.y-f.r-7))
    ui.pathLineTo(p(f.x+7,f.y-f.r-7))
    ui.pathLineTo(p(f.x,f.y-f.r+12))
    ui.pathFillConvex(Light.color(C.primary,L.major))
  elseif motif=='jewel' then
    for i=0,24 do
      local progress=i/24
      local a=f.first+(f.last-f.first)*progress
      local active=progress<=fraction or (rpm and state.rpmRedline and progress>=redline)
      local ink=active and arcValue(progress) or Theme.withAlpha(progressInk(progress),0.28)
      filledCircle(f.x+(f.r-4)*math.cos(a),f.y+(f.r-4)*math.sin(a),i%2==0 and 5 or 3.3,ink,
        active and L.segment or L.printedWarning)
    end
    for i=0,80 do
      local a=f.first+(f.last-f.first)*i/80
      local outer=Config.dial.innerRadius
      local inner=outer-Config.dial.innerTickLength
      line(f.x+inner*math.cos(a),f.y+inner*math.sin(a),
        f.x+outer*math.cos(a),f.y+outer*math.sin(a),C.secondary,Config.dial.innerTickWidth)
      if i%10==0 then
        filledCircle(f.x+(inner+outer)/2*math.cos(a),f.y+(inner+outer)/2*math.sin(a),
          Config.dial.innerDotRadius,C.primary)
      end
    end
  elseif motif=='spectrum' then
    local green=Light.color(C.green,L.segment)
    local amber=Light.color(C.amber,L.segment)
    local red=Light.color(C.red,L.segment)
    -- Adjacent slices overlap slightly so the spectrum reads as one solid band.
    for i=1,96 do
      local progress=(i-0.5)/96
      local a=f.first+(f.last-f.first)*(i-1)/96
      local b=math.min(f.last,f.first+(f.last-f.first)*i/96+0.002)
      local ink=progress<0.55 and Light.mix(green,amber,progress/0.55)
        or Light.mix(amber,red,(progress-0.55)/0.45)
      if rpm and state.rpmRedline and progress>=redline then ink=arcValue(progress) end
      arc(f.r-10,a,b,ink,22,3)
    end
    if not f.analog then
      local a=f.first+(f.last-f.first)*fraction
      local radial,tangent=vec2(math.cos(a),math.sin(a)),vec2(-math.sin(a),math.cos(a))
      ui.pathClear()
      ui.pathLineTo(pivot+radial*((f.r+2)*scale)-tangent*(5*scale))
      ui.pathLineTo(pivot+radial*((f.r+2)*scale)+tangent*(5*scale))
      ui.pathLineTo(pivot+radial*((f.r-23)*scale))
      ui.pathFillConvex(Theme.withAlpha(C.panel,1))
    end
  end

  local labelRadius=f.r-39
  local n=0
  while not (motif=='spectrum' and not f.analog) and n<=maximum+step*0.01 do
    local progress=n/math.max(maximum,1)
    local a=f.first+(f.last-f.first)*progress
    label(tostring(U.round(n)),f.analog and 14 or 12,
      f.x+labelRadius*math.cos(a),f.y+labelRadius*math.sin(a),C.primary,L.number)
    n=n+step
  end

  if useLowerArc then
    lowerAuxiliary(center,scale,state,settings,C,light,rpm,L)
  elseif f.aux and auxiliary then
    local aux=f.aux
    local auxScale=scale*aux[3]
    auxiliary(p(aux[1],aux[2])-vec2(0,Config.sub.offsetY*auxScale),auxScale,
      state,settings,C,f.analog and 0 or 1,light,rpm,L)
  end

  if f.analog then
    local needleFraction=rpm and state.gt7RpmNeedleNormalized or state.gt7SpeedNeedleNormalized
    local needleStyle=rpm and settings.gt7RpmNeedleStyle or settings.gt7SpeedNeedleStyle
    local tint=rpm and (state.rpmRedline and arcValue(1) or state.rpmWarning and C.amber or nil) or nil
    Needle.draw(pivot,scale*f.r/150,f.first+(f.last-f.first)*U.clamp(needleFraction or fraction,0,1),
      Config.needlePreset(needleStyle),C,light,tint,L)
  end

  if motif=='snap' then
    label(value,f.value[3],f.value[1],f.value[2],valueColor,L.value,70)
    label('RPM',9,f.unit[1],f.unit[2],C.secondary,L.label)
    drawSnapSelector(center,scale,state,settings,C,L)
  else
    label(value,rpm and f.value[3]*0.92 or f.value[3],f.value[1],f.value[2],valueColor,L.value,150)
    label(rpm and 'RPM' or settings.speedUnit,11,f.unit[1],f.unit[2],C.secondary,L.label)
  end
end

local function drawSelectorWedge(center,scale,inner,outer,a,b,fill,stroke)
  local points={}
  local segments=math.max(3,math.ceil(math.abs(b-a)/5))
  for i=0,segments do
    local angle=math.rad(a+(b-a)*i/segments)
    points[#points+1]=center+vec2(outer*scale*math.cos(angle),outer*scale*math.sin(angle))
  end
  for i=segments,0,-1 do
    local angle=math.rad(a+(b-a)*i/segments)
    points[#points+1]=center+vec2(inner*scale*math.cos(angle),inner*scale*math.sin(angle))
  end
  local area=0
  for i,p in ipairs(points) do
    local q=points[i%#points+1]
    area=area+p.x*q.y-q.x*p.y
  end
  if area<0 then
    local reversed={}
    for i=#points,1,-1 do reversed[#reversed+1]=points[i] end
    points=reversed
  end
  ui.pathClear()
  for _,p in ipairs(points) do ui.pathLineTo(p) end
  ui.pathFillConvex(fill)
  ui.pathClear()
  ui.pathArcTo(center,outer*scale,math.rad(math.min(a,b)),math.rad(math.max(a,b)),16)
  ui.pathStroke(stroke,false,1*scale)
end

drawSnapSelector=function(center,scale,state,settings,C,L)
  local gear=Selector.gear(state)
  local count=Selector.count(state.gearCount,gear)
  local span=(Selector.endAngle-Selector.startAngle)/(count+1)
  local gap=math.min(1.4,math.abs(span)*0.1)
  for i=0,count do
    local first=Selector.startAngle+i*span+gap
    local last=Selector.startAngle+(i+1)*span-gap
    local selected=gear==(i==0 and -1 or i)
    drawSelectorWedge(center,scale,49,79,first,last,
      selected and C.coreAmber or C.panelRaised,selected and C.amber or C.outlineDim)
    local angle=math.rad((first+last)/2)
    local caption=i==0 and 'R' or tostring(i)
    Light.text(caption,math.min(12,math.max(8,span*0.58))*scale,
      center+vec2(64*scale*math.cos(angle),64*scale*math.sin(angle)),
      selected and C.primary or C.secondary,nil,L.number,scale)
  end
  local previous=selectorAnimations[state]
  if state.available==false then previous=nil end
  local animation,angle=Selector.sample(previous,gear,count,state.clock or 0,
    settings.animateGearSelector,state._gearCountCarKey or state._speedGaugeCarKey)
  if state.available==false then selectorAnimations[state]=nil else selectorAnimations[state]=animation end
  local a=math.rad(angle)
  local tangent=vec2(-math.sin(a),math.cos(a))
  local radial=vec2(math.cos(a),math.sin(a))
  local tip=center+radial*(55*scale)
  local base=center+radial*(45*scale)
  ui.drawCircleFilled(center,45*scale,C.panel,48)
  ui.drawCircle(center,45*scale,Light.color(C.amber,L.major),48,1.5*scale)
  local points={tip,base+tangent*(4.5*scale),base-tangent*(4.5*scale)}
  local area=(points[1].x*points[2].y-points[2].x*points[1].y)
    +(points[2].x*points[3].y-points[3].x*points[2].y)
    +(points[3].x*points[1].y-points[1].x*points[3].y)
  if area<0 then points[2],points[3]=points[3],points[2] end
  ui.pathClear()
  for _,point in ipairs(points) do ui.pathLineTo(point) end
  ui.pathFillConvex(C.amber)
  local reading=gear==nil and '–' or gear==0 and 'N' or gear==-1 and 'R' or tostring(gear)
  Light.text(reading,34*scale,center,gear and gear~=0 and gear~=-1 and Light.color(C.amber,L.value) or C.primary,
    72*scale,L.value,scale)
end

function M.draw(id, center, scale, state, settings, C, L, digital, light, rpm, rpmColor,
    auxiliary, lowerAuxiliary, mode, role, useLowerArc)
  local f,inspired=resolveFace(id,mode)
  if not f then return end
  if inspired then
    drawInspired(id,f,center,scale,state,settings,C,L,digital,light,rpm,rpmColor,
      auxiliary,lowerAuxiliary,useLowerArc)
    return
  end
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
  if useLowerArc then
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
