local Readout=require('src/dial_readout')
local Light=require('ui/instrument_illumination')
local Layouts = require('src/dial_variants')
local Theme = require('src/theme')
local General = require('src/general_settings')
local U = require('src/utils')
local Config = require('src/instrument_config')
local Needle = require('ui/instrument_needle')
local Hybrid = require('src/hybrid')
local Icons = require('ui/side_instruments')
local Halo = require('ui/halo_dial')
local Selector = require('src/gear_selector')
local M = {}
-- CSP can expose the app root as __dirname inside required modules. Test both
-- root and module contexts against a real asset instead of assuming ui/.
local imageRoot = __dirname and (__dirname .. '/') or ''
local fileExists = io.fileExists or io.exists
if __dirname and fileExists then
  local sample = 'assets/dial_variants/shelf_dark_back.png'
  for _,candidate in ipairs({__dirname .. '/', __dirname .. '/../'}) do
    if fileExists(candidate .. sample) then imageRoot = candidate; break end
  end
end
local imagesByVariant = {}
for id,layout in pairs(Layouts.layouts) do
  imagesByVariant[id] = {}
  for theme,images in pairs(layout.images) do
    imagesByVariant[id][theme] = {back=imageRoot .. images.back,
      front=images.front and (imageRoot .. images.front) or nil}
  end
end

local boldFont = 'Consolas;Weight=Bold'
-- The concept's Classic hand has a broad ivory blade and a covered tail.
-- Prepare its instrument-specific proportions once, preserving the catalog
-- and all other selected needle styles.
local classicHand = {}
for key,value in pairs(Config.needlePreset('a01')) do classicHand[key] = value end
classicHand.width,classicHand.hubRadius = 7,12
classicHand.counterweightLength,classicHand.weightLength = 10,8
classicHand.hubShape,classicHand.hubCenter = 'machined','primary'
classicHand = require('src/instrument_needle_geometry').build(classicHand)
local selectorAnimations = setmetatable({}, {__mode='k'})

local function point(c, x, y) return c.origin + vec2(x*c.scale, y*c.scale) end
local function circle(c,x,y,r,color,filled,width)
  local p=point(c,x,y)
  if filled then ui.drawCircleFilled(p,r*c.scale,color,64)
  else ui.drawCircle(p,r*c.scale,color,64,(width or 1)*c.scale) end
end
local function text(c, value, size, x, y, color, backlight, bold)
  value=Readout.value(value)
  if not value then return end
  if bold then ui.pushDWriteFont(boldFont) end
  local ink=color or c.colors.primary
  local style=backlight and not c.statusDrawing and ink~=c.colors.red and (size>=30 and c.L.value or c.L.label) or nil
  Light.text(tostring(value),size*c.scale,point(c,x,y),ink,nil,style,c.scale)
  if bold then ui.popDWriteFont() end
end
local function line(c,x1,y1,x2,y2,color,width)
  Light.line(point(c,x1,y1),point(c,x2,y2),color,(width or 1)*c.scale,not c.statusDrawing and ((width or 1)>=2 and c.L.major or c.L.minor) or nil,c.scale)
end
local function arc(c,x,y,r,a,b,color,width)
  ui.pathClear()
  ui.pathArcTo(point(c,x,y),r*c.scale,math.rad(math.min(a,b)),math.rad(math.max(a,b)),32)
  ui.pathStroke(color,false,width*c.scale)
end
local function polygon(c,points,color)
  Light.segment(c.origin,c.scale,points,color,c.L.segment)
end
local function pulse(state, enabled, period)
  return enabled == false or math.floor((state.clock or 0)/period)%2 == 0
end
local function rpmColor(c)
  if c.state.rpmRedline then
    return pulse(c.state,c.settings.animateRedlineAlert,0.12) and c.colors.red or c.colors.amber
  end
  return c.state.rpmWarning and c.colors.amber or c.colors.primary
end

-- Mirrors the standalone auxiliary's existing selection rules. A missing
-- channel is never represented as measured zero or fabricated electric kW.
function M.auxiliary(state, mode)
  if mode == 'off' then return nil end
  mode = mode or 'auto'
  local h = Hybrid.forGauge(state,mode)
  if h then
    local value = h.powerKw ~= nil and string.format('%.0f kW',h.powerKw)
      or h.delivery ~= nil and string.format('ERS %.0f%%',h.delivery*100) or 'ERS --'
    if h.batteryRecovery then
      value = h.chargeRecoveryRate and string.format('-%.1f%%/s',h.chargeRecoveryRate) or 'CHG'
    end
    return {label='ERS',value=value,fraction=h.needle,charge=h.charge,
      electric=true,recovery=h.batteryRecovery or (h.powerKw ~= nil and h.powerKw<0),
      maximum=h.maximumKw or 50,minimum=h.recoveryKw or 50,
      measuredPower=h.powerKw~=nil and not h.batteryRecovery}
  end
  if mode == 'electric' then return {label='ERS',value='N/A',fraction=nil,electric=true} end
  if state.available == false then return {label=mode=='auto' and 'AUX' or mode:upper(),value='N/A'} end
  local turbo = mode=='turbo' or (mode=='auto' and state.turboAvailable)
  if mode=='turbo' and not state.turboAvailable then
    return {label='AERO',value=state.aeroDownforceKN ~= nil and string.format('%.1f kN',state.aeroDownforceKN)
      or state.aeroCoefficient ~= nil and string.format('CL %.2f',state.aeroCoefficient)
      or string.format('%d%%',U.round((state.aeroLoadNormalized or 0)*100)),
      fraction=U.clamp(state.aeroLoadNormalized or 0,0,1),maximum=1}
  end
  if turbo and state.turboAvailable then
    local maximum=math.max(state.turboDisplayMax or 1,0.1)
    return {label='TURBO',value=string.format('%.2f BAR',state.turboBoost or 0),
      fraction=U.clamp((state.turboBoost or 0)/maximum,0,1),maximum=maximum}
  end
  return {label='FUEL',value=state.fuel~=nil and state.maxFuel~=nil and string.format('%.0f L',state.fuel) or 'N/A',
    fraction=state.fuel~=nil and state.maxFuel~=nil and U.clamp(state.fuelNormalized or 0,0,1) or nil,
    maximum=state.maxFuel or 1}
end

local function drawRpm(c)
  local l,s,C=c.layout,c.state,c.colors
  if l.haloRpm then
    Halo.rpm(c.origin,c.scale,l,s,c.settings,C,c.L)
    return
  end
  local r=l.rpm
  local limiter=math.max(s.rpmDisplayLimiter or 8000,1000)
  local maximum=math.max(s.rpmGaugeLimiter or math.ceil(limiter/1000)*1000,1000)
  local warning=U.clamp(limiter*(s.rpmWarningFraction or 0.86)/maximum,0,1)
  local red=U.clamp(limiter*(s.rpmRedlineFraction or 0.96)/maximum,0,1)
  arc(c,r[1],r[2],r[3]+3,r[4],r[5],C.outlineDim,1)
  for i,band in ipairs(l.bands) do
    local f=(i-0.5)/#l.bands
    if f>=warning then
      local color=f>=red and (s.rpmRedline and rpmColor(c) or C.red) or C.amber
      if f<red and s.rpmWarning and pulse(s,c.settings.animateShiftAlert,0.14) then color=C.shiftBlue end
      polygon(c,band,color)
    end
  end
  for _,tick in ipairs(l.ticks) do
    if tick[3]<red then
      local length=tick[3]>=warning and 5 or 9
      line(c,r[1]+(r[3]-length)*tick[1],r[2]+(r[3]-length)*tick[2],
        r[1]+r[3]*tick[1],r[2]+r[3]*tick[2],C.primary,1)
    end
  end
  local thousands=maximum/1000
  local step=thousands<=10 and 1 or (thousands<=20 and 2 or 5)
  for value=0,thousands+0.001,step do
    local angle=l.startAngle+(l.endAngle-l.startAngle)*value/thousands
    local dx,dy=math.cos(angle),math.sin(angle)
    line(c,r[1]+(r[3]-25)*dx,r[2]+(r[3]-25)*dy,r[1]+r[3]*dx,r[2]+r[3]*dy,C.primary,3)
  end
  -- Scale labels belong to the face; needle layering is selected per layout.
  for value=0,thousands+0.001,step do
    local angle=l.startAngle+(l.endAngle-l.startAngle)*value/thousands
    text(c,string.format('%.0f',value),26,
      r[1]+(r[3]-40)*math.cos(angle),r[2]+(r[3]-40)*math.sin(angle),C.primary,true,true)
  end
end

local function drawNeedle(c)
  local l,s,C=c.layout,c.state,c.colors
  local r=l.rpm
  local style=Config.normalizeNeedleStyle(c.settings.analogNeedleStyle,'a01')
  local preset=style=='a01' and classicHand or Config.needlePreset(style)
  Needle.draw(point(c,r[1],r[2]),c.scale*(l.needleLength or (r[3]-40))/preset.length,
    l.startAngle+(l.endAngle-l.startAngle)*U.clamp(s.analogNeedleNormalized or 0,0,1),
    preset,C,c.L.light,(s.rpmWarning or s.rpmRedline) and rpmColor(c) or nil)
end

local function selectorCell(c,index,count,gear,labels)
  local C,l=c.colors,c.layout
  local step=(Selector.endAngle-Selector.startAngle)/(count+1)
  local gap=math.min(1.5,math.abs(step)*0.12)
  local direction=step<0 and -1 or 1
  local ring=l.selectorRing
  local inner,outer,radius=ring[1],ring[2],ring[3]
  local a=Selector.startAngle+index*step+gap*direction
  local b=Selector.startAngle+(index+1)*step-gap*direction
  local selected=gear==(index==0 and -1 or index)
  if labels then
    local angle=math.rad((a+b)/2)
    local size=math.min(ring[4],math.abs(step)*2.2*radius/228)
    text(c,index==0 and 'R' or tostring(index),size,
      310+radius*math.cos(angle),304+radius*math.sin(angle)-size*0.065,
      selected and C.amber or C.primary,true,true)
    return
  end
  local points={}
  local segments=math.max(4,math.ceil(math.abs(b-a)/8))
  for i=0,segments do
    local angle=math.rad(a+(b-a)*i/segments)
    points[#points+1]={310+outer*math.cos(angle),304+outer*math.sin(angle)}
  end
  for i=segments,0,-1 do
    local angle=math.rad(a+(b-a)*i/segments)
    points[#points+1]={310+inner*math.cos(angle),304+inner*math.sin(angle)}
  end
  polygon(c,points,selected and C.coreAmber or C.panelRaised)
  arc(c,310,304,outer,a,b,selected and C.amber or C.outline,selected and 2 or 1)
  arc(c,310,304,inner,a,b,selected and C.amber or C.outlineDim,1)
  for _,degrees in ipairs({a,b}) do
    local angle=math.rad(degrees)
    line(c,310+inner*math.cos(angle),304+inner*math.sin(angle),
      310+outer*math.cos(angle),304+outer*math.sin(angle),C.outlineDim,1)
  end
end

local function drawSelectorRing(c)
  local gear=Selector.gear(c.state)
  local count=Selector.count(c.state.gearCount,gear)
  for i=0,count do selectorCell(c,i,count,gear,false) end
  return gear,count
end

local function drawSelectorHub(c,gear,count)
  local s,l,C=c.state,c.layout,c.colors
  local previous=selectorAnimations[s]
  if s.available==false then previous=nil end
  local animation,angle=Selector.sample(previous,gear,count,s.clock or 0,
    c.settings.animateGearSelector,s._gearCountCarKey)
  if s.available==false then selectorAnimations[s]=nil else selectorAnimations[s]=animation end
  angle=math.rad(angle)

  circle(c,310,304,94,C.metalDim,true)
  circle(c,310,304,94,C.metal,false,1.5)
  circle(c,310,304,89,C.panelRaised,true)
  circle(c,310,304,77,C.panel,true)
  circle(c,310,304,77,Light.color(C.amber,c.L.major),false,1.8)
  circle(c,310,304,72,C.outlineDim,false,1)
  local points={}
  for _,p in ipairs({{103,0},{82,10},{82,-10}}) do
    points[#points+1]={310+p[1]*math.cos(angle)-p[2]*math.sin(angle),
      304+p[1]*math.sin(angle)+p[2]*math.cos(angle)}
  end
  polygon(c,points,C.panel)
  polygon(c,points,Light.color(gear and gear~=0 and C.amber or C.outline,c.L.icon))
  circle(c,310,304,16,C.metalDim,true)
  circle(c,310,304,13,C.metal,false,1.5)
  circle(c,310,304,7,C.panelRaised,true)
  circle(c,310,304,3,C.primary,true)
  for i=0,count do selectorCell(c,i,count,gear,true) end
  local p=l.gear
  local reading=gear==nil and '-' or gear==0 and 'N' or gear==-1 and 'R' or tostring(gear)
  text(c,reading,p[3],p[1],p[2],rpmColor(c),true,true)
end

local function bar(c,x,y,w,h,fraction,color,signed)
  local count=signed and 16 or 10
  for i=1,count do
    local active=false
    if fraction~=nil then
      if signed then
        local f=(i-0.5)/count*2-1
        active=(f>0 and fraction>0 and f<=fraction) or (f<0 and fraction<0 and f>=fraction)
      else active=i<=math.floor(U.clamp(fraction,0,1)*count+0.5) end
    end
    local x1=x+(i-1)*w/count
    ui.drawRectFilled(point(c,x1,y),point(c,x1+w/count-2,y+h),active and Light.color(color,c.L.subSegment) or c.colors.inactive)
  end
  if signed then line(c,x+w/2,y-2,x+w/2,y+h+2,c.colors.secondary,1) end
end
local function auxColor(c,a)
  if a.electric then return (a.recovery or (a.fraction or 0)<0) and c.colors.green or c.colors.cyan end
  if a.label=='FUEL' then return Readout.fuelColor(a.fraction,c.state,c.colors,c.colors.primary) end
  return a.label=='AERO' and (a.fraction or 0)>=0.82 and c.colors.amber or c.colors.cyan
end
local function drawSelectorAuxiliary(c)
  local left=M.auxiliary(c.state,c.settings.analogAuxiliaryMode)
  if left and left.label=='FUEL' then left=M.auxiliary(c.state,'turbo') end
  local channels={left,M.auxiliary(c.state,'fuel')}
  for index,a in ipairs(channels) do
    if a then
      local p=c.layout.edgeAux[index]
      local value=a.electric and (a.charge or math.abs(a.fraction or 0)) or a.fraction
      local active=value~=nil and math.floor(U.clamp(value,0,1)*c.layout.edgeBarCount+0.5) or 0
      local color=auxColor(c,a)
      for i=1,c.layout.edgeBarCount do
        local span=(p[5]-p[4])/c.layout.edgeBarCount
        local from=p[4]+(i-0.86)*span
        local to=p[4]+(i-0.14)*span
        arc(c,p[1],p[2],p[3],from,to,
          i<=active and Light.color(color,c.L.segment) or c.colors.inactive,
          c.layout.edgeBarWidth)
      end
      local icon=c.layout.edgeIcons[index]
      local center=point(c,icon[1],icon[2])
      local ink=Light.color(color,c.L.icon)
      if a.electric then
        ui.drawRect(center-vec2(9,6)*c.scale,center+vec2(9,6)*c.scale,ink,0,nil,1.5*c.scale)
        line(c,icon[1]+11,icon[2]-2,icon[1]+11,icon[2]+2,ink,2)
        line(c,icon[1]-5,icon[2],icon[1]-1,icon[2],ink,1)
        line(c,icon[1]-3,icon[2]-2,icon[1]-3,icon[2]+2,ink,1)
      else
        local draw=a.label=='FUEL' and Icons.fuelIcon
          or a.label=='AERO' and Icons.aeroIcon or Icons.boostIcon
        draw(center,c.scale*0.85,ink)
      end
    end
  end
end
local function drawAuxiliary(c)
  local a=M.auxiliary(c.state,c.settings.analogAuxiliaryMode)
  if c.layout.haloRpm then
    if a and a.label=='FUEL' then a=M.auxiliary(c.state,'turbo') end
    Halo.auxiliary(c.origin,c.scale,c.layout,a,M.auxiliary(c.state,'fuel'),c.state,c.colors,c.L)
    return
  end
  if c.layout.edgeAux then drawSelectorAuxiliary(c); return end
  if c.layout.pairedAux then
    local function channel(a,start,finish,iconX,iconY,radius)
      if not a then return end
      local ink=auxColor(c,a)
      for i=1,18 do
        local fraction=a.fraction
        local signed=(i-0.5)/18*2-1
        local active=fraction and (a.electric
          and ((signed>0 and fraction>0 and signed<=fraction) or (signed<0 and fraction<0 and signed>=fraction))
          or (not a.electric and i<=math.floor(U.clamp(fraction,0,1)*18+0.5)))
        local span=(finish-start)/18
        arc(c,310,304,radius or 199,start+(i-0.87)*span,start+(i-0.13)*span,
          active and Light.color(ink,c.L.subSegment) or c.colors.inactive,14)
      end
      local p=point(c,iconX,iconY)
      local icon=a.label=='FUEL' and Icons.fuelIcon or a.label=='AERO' and Icons.aeroIcon or Icons.boostIcon
      if a.electric then
        ui.drawRect(p-vec2(9,5)*c.scale,p+vec2(9,5)*c.scale,Light.color(ink,c.L.icon),0,nil,1.5*c.scale)
        line(c,iconX+11,iconY-2,iconX+11,iconY+2,ink,2)
      else icon(p,c.scale*0.75,Light.color(ink,c.L.icon)) end
    end
    if a and a.label=='FUEL' then a=M.auxiliary(c.state,'turbo') end
    channel(a,62,118,415,461,178)
    channel(M.auxiliary(c.state,'fuel'),-118,-62,423,142,185)
    return
  end
  if not a then return end
  local p,C=c.layout.aux,c.colors
  local color=auxColor(c,a)
  if c.layout.auxStyle=='screen' then
    local x,y,w,h=p[1],p[2],p[3],p[4]
    text(c,a.value,17,x,y-15,color,true,true)
    bar(c,x-w/2+5,y+4,w-10,22,a.fraction,color,a.electric)
    if a.electric then
      bar(c,x-w/2+5,y+30,w-48,7,a.charge,a.charge and a.charge<=0.15 and C.red or C.green)
      text(c,a.charge and string.format('%.0f%%',a.charge*100) or '--%',10,x+w/2-17,y+33,C.primary)
    end
    if c.layout.auxIcon then
      local center=point(c,x,y+43)
      local iconColor=Light.color(color,c.L.icon)
      if a.electric then
        ui.drawRect(center-vec2(7,5)*c.scale,center+vec2(7,5)*c.scale,iconColor,0,nil,1.3*c.scale)
        line(c,x+9,y+41,x+9,y+45,iconColor,1)
      else
        local icon=a.label=='FUEL' and Icons.fuelIcon or a.label=='AERO' and Icons.aeroIcon or Icons.boostIcon
        icon(center,c.scale*0.72,iconColor)
      end
    end
  else
    local dial=c.layout.auxStyle=='dial'
    local start,finish=dial and -220 or 62,dial and 50 or 118
    local radius=p[3]-(dial and 29 or 0)
    local count=a.electric and 20 or 14
    for i=1,count do
      local f=dial and (i-0.5)/count or (count-i+0.5)/count
      local signed=f*2-1
      local active=a.fraction~=nil and (a.electric
        and ((signed>0 and a.fraction>0 and signed<=a.fraction) or (signed<0 and a.fraction<0 and signed>=a.fraction))
        or (not a.electric and f<=a.fraction))
      local span=(finish-start)/count
      arc(c,p[1],p[2],radius,start+(i-0.87)*span,start+(i-0.13)*span,active and color or C.inactive,dial and 12 or 18)
    end
    if dial then
      for i=0,4 do
        local angle=math.rad(start+(finish-start)*i/4)
        line(c,p[1]+(p[3]-9)*math.cos(angle),p[2]+(p[3]-9)*math.sin(angle),
          p[1]+(p[3]-17)*math.cos(angle),p[2]+(p[3]-17)*math.sin(angle),C.primary,1)
        if a.maximum~=nil or a.electric then
          local label
          if a.electric then
            local signed=i/2-1
            if a.measuredPower then
              label=string.format('%.0f',signed*(signed<0 and a.minimum or a.maximum))
            else
              label=i==0 and 'CHG' or (i==2 and '0' or (i==4 and 'PWR' or ''))
            end
          else
            label=string.format(a.label=='TURBO' and '%.1f' or '%.0f',a.maximum*i/4)
          end
          text(c,label,10,
            p[1]+(p[3]-24)*math.cos(angle),p[2]+(p[3]-24)*math.sin(angle),C.secondary)
        end
      end
      text(c,a.label,14,p[1],p[2]-22,C.primary,true)
      text(c,a.value,20,p[1],p[2]+3,color,true,true)
      if a.electric then
        bar(c,p[1]-35,p[2]+28,70,6,a.charge,C.green)
        text(c,a.charge and string.format('BAT %.0f%%',a.charge*100) or 'BAT --%',10,p[1],p[2]+43)
      end
    else
      text(c,a.label,12,207,438,C.primary,true)
      text(c,a.value,16,207,456,color,true,true)
      if a.electric then
        for i=1,20 do
          local active=a.charge~=nil and i<=math.floor(a.charge*20+0.5)
          arc(c,p[1],p[2],radius-20,70+(i-0.87)*40/20,70+(i-0.13)*40/20,
            active and (a.charge<=0.15 and C.red or C.green) or C.inactive,5)
        end
        text(c,a.charge and string.format('BAT %.0f%%',a.charge*100) or 'BAT --%',10,408,450)
      end
    end
  end
end

local function drawControls(c)
  local l,s,C=c.layout,c.state,c.colors
  for i,p in ipairs(l.pedals) do
    local value=U.clamp(i==1 and (s.brake or 0) or (s.throttle or 0),0,1)
    local color=i==1 and C.red or C.cyan
    local width=l.pedalWidth or 6
    if l.pedalStyle=='arc' then
      local a,b=p[4],p[5]
      arc(c,p[1],p[2],p[3],a,b,C.inactive,width)
      if value>0 then arc(c,p[1],p[2],p[3],a,a+(b-a)*value,color,width) end
      local mid=math.rad((a+b)/2)
      text(c,i==1 and 'BRK' or 'THR',8,p[1]+(p[3]-12)*math.cos(mid),p[2]+(p[3]-12)*math.sin(mid),C.secondary)
    else
      line(c,p[1],p[2],p[3],p[4],C.inactive,width)
      if value>0 then line(c,p[1],p[2],p[1]+(p[3]-p[1])*value,p[2]+(p[4]-p[2])*value,color,width) end
    end
  end
  if c.settings.showClutch~=false and not l.noClutch and l.clutch then
    local p=l.clutch
    line(c,p[1]-p[3]/2,p[2],p[1]+p[3]/2,p[2],C.inactive,4)
    line(c,p[1]-p[3]/2,p[2],p[1]-p[3]/2+p[3]*U.clamp(s.clutch or 0,0,1),p[2],C.cyan,4)
    text(c,'CL',8,p[1]-p[3]/2-11,p[2],C.secondary)
  end
  if c.settings.showSteering~=false and not l.hideSteering then
    if l.steeringRing then
      local p=l.steeringRing
      if l.graduatedSteeringRing then
        arc(c,p[1],p[2],p[3],-190,10,C.outlineDim,4)
        for i=0,20 do
          local a=math.rad(-190+i*10)
          local length=i%5==0 and 8 or 4
          line(c,p[1]+(p[3]-length)*math.cos(a),p[2]+(p[3]-length)*math.sin(a),
            p[1]+(p[3]+2)*math.cos(a),p[2]+(p[3]+2)*math.sin(a),
            i==10 and C.primary or C.secondary,i%5==0 and 2 or 1)
        end
      else
        arc(c,p[1],p[2],p[3],0,360,C.outlineDim,4)
      end
      local angle=-90+U.clamp(s.steeringInput or 0,-1,1)*(l.graduatedSteeringRing and 100 or 145)
      arc(c,p[1],p[2],p[3],angle-7,angle+7,Light.color(C.cyan,c.L.icon),5)
      ui.drawCircleFilled(point(c,p[1]+p[3]*math.cos(math.rad(angle)),
        p[2]+p[3]*math.sin(math.rad(angle))),3.5*c.scale,Light.color(C.cyan,c.L.icon),24)
      return
    end
    local p=l.steering
    line(c,p[1]-p[3],p[2],p[1]+p[3],p[2],C.outline,2)
    if l.graduatedSteering then
      for i=-10,10 do
        local x=p[1]+p[3]*i/10
        local height=i==0 and 8 or i%5==0 and 6 or 3
        line(c,x,p[2]-height,x,p[2]+height,i==0 and C.primary or C.secondary,i==0 and 2 or 1)
      end
      local x=p[1]+U.clamp(s.steeringInput or 0,-1,1)*p[3]
      line(c,x,p[2]-10,x,p[2]+10,C.cyan,3)
    else
      line(c,p[1],p[2]-5,p[1],p[2]+5,C.primary,1)
      ui.drawCircleFilled(point(c,p[1]+U.clamp(s.steeringInput or 0,-1,1)*p[3],p[2]),3*c.scale,C.cyan,16)
      text(c,s.steeringAngle and string.format('%+d°',U.round(s.steeringAngle)) or 'INPUT',9,p[1],p[2]+14,C.secondary)
    end
  end
end

local function status(c,position,label,level,available,active,color)
  local x,y=position[1],position[2]
  local C=c.colors
  local p=point(c,x,y)
  local radius=(c.layout.statusRadius or 22)*c.scale
  ui.drawCircleFilled(p,radius,C.panel,32)
  ui.drawCircle(p,radius,active and color or (available and C.amberDim or C.outlineDim),32,(active and 2 or 1)*c.scale)
  local ink=active and color or (available and C.primary or C.secondary)
  if c.layout.iconStatuses then
    local kind=label=='TC' and 1 or label=='ABS' and 2 or label=='PIT' and 4 or 3
    Icons.statusIcon(p,c.scale,kind,Light.color(ink,c.L.icon))
    return
  end
  local levels=c.settings.showTcAbsLevels~=false and (label=='TC' or label=='ABS')
  text(c,label,label=='ABS' and 12 or 14,x,y-(levels and 7 or 0),ink,active)
  if levels then text(c,level~=nil and tostring(level) or '—',12,x,y+10,ink) end
end
local function drawStatuses(c)
  local s,l,C=c.state,c.layout,c.colors
  status(c,l.statuses[1],'TC',s.tcLevel,s.tcSupported or s.tcLevel~=nil,s.tcActive==true,C.amber)
  status(c,l.statuses[2],'ABS',s.absLevel,s.absSupported or s.absLevel~=nil,s.absActive==true,C.amber)
  if c.settings.showLights~=false then
    local p=l.statuses[3]
    status(c,p,'',nil,s.lightsAvailable,s.headlights and s.lightsAvailable,s.highBeams and C.amber or C.cyan)
    if not l.iconStatuses then
      local ink=s.headlights and s.lightsAvailable and (s.highBeams and C.amber or C.cyan) or C.secondary
      arc(c,p[1]-1,p[2],8,-90,90,ink,2)
      line(c,p[1]-1,p[2]-8,p[1]-1,p[2]+8,ink,2)
      for j=-1,1 do line(c,p[1]-13,p[2]+j*5,p[1]-5,p[2]+j*4,ink,1) end
    end
  end
  status(c,l.statuses[4],'PIT',nil,s.pitLimiter~=nil or s.pitLane,s.pitLimiter==true or s.pitLane,C.amber)
  local p=l.warning
  local color=(s.handbrake or 0)>0.9 and C.red or C.outlineDim
  line(c,p[1],p[2]-18,p[1]+18,p[2]+14,color,3)
  line(c,p[1]+18,p[2]+14,p[1]-18,p[2]+14,color,3)
  line(c,p[1]-18,p[2]+14,p[1],p[2]-18,color,3)
  text(c,'!',22,p[1],p[2]+1,color)
  local flag=s.raceFlagType
  local flagColor=flag==2 and C.flagYellow or (flag==5 or flag==8) and C.red
    or flag==12 and C.shiftBlue or (flag==13 or flag==14) and C.primary or nil
  local lit=flagColor and pulse(s,c.settings.animateFlagAlert,0.42)
  p=l.flag
  local ink=lit and flagColor or C.outlineDim
  line(c,p[1]-9,p[2]-9,p[1]-9,p[2]+9,ink,2)
  ui.drawRectFilled(point(c,p[1]-7,p[2]-9),point(c,p[1]+10,p[2]),ink)
end

function M.draw(state,settings,origin,scale)
  local layout=Layouts.get(settings.analogVariant)
  if not layout then return false end
  local c={layout=layout,state=state,settings=settings,origin=origin,scale=scale,
    colors=General.palette(Theme.get(settings.theme),settings.backgroundOpacity)}
  c.L=Light.resolve(c.colors,settings.theme,state.gt7Instruments and state.gt7Instruments.light or (state.headlights and 1 or 0))
  local images=imagesByVariant[layout.id][settings.theme=='light' and 'light' or 'dark']
  local tint=rgbm(1,1,1,U.clamp((settings.backgroundOpacity or 0.72)/0.72,0,1))
  local finish=point(c,620,620)
  -- The structural bezel is also drawn natively: first-frame asynchronous
  -- texture loading can never leave the instrument floating without a face.
  local center=point(c,310,304)
  if layout.id=='concentric' then
    ui.drawCircleFilled(center,176*scale,Theme.withAlpha(Theme.get(settings.theme).surface,0.10),96)
    arc(c,310,304,221,0,360,c.colors.surface,90)
  else
    ui.drawCircleFilled(center,266*scale,c.colors.void,96)
    ui.drawCircleFilled(center,266*scale,c.colors.surface,96)
  end
  if not layout.nativeFace then ui.drawImage(images.back,origin,finish,tint) end
  drawRpm(c)
  local selectorGear,selectorCount
  if layout.selector then
    selectorGear,selectorCount=drawSelectorRing(c)
    drawNeedle(c)
  elseif layout.id=='concentric' then
    drawControls(c)
    drawNeedle(c)
  end
  if layout.selector then drawSelectorHub(c,selectorGear,selectorCount) end
  if layout.id=='concentric' then
    -- Opaque center masks the hand regardless of shell opacity.
    local p=layout.core
    ui.drawCircleFilled(point(c,p[1],p[2]),p[3]*scale,
      Theme.withAlpha(Theme.get(settings.theme).panel,1),96)
  end
  if images.front then ui.drawImage(images.front,origin,finish,tint) end
  if layout.gearBadge then
    local p=layout.gearBadge
    ui.drawCircleFilled(point(c,p[1],p[2]),p[3]*scale,c.colors.panel,64)
    ui.drawCircle(point(c,p[1],p[2]),p[3]*scale,c.colors.amber,64,2*scale)
    ui.drawCircle(point(c,p[1],p[2]),(p[3]-5)*scale,c.colors.outlineDim,64,1*scale)
    text(c,'GEAR',10,p[1],p[2]+p[3]-7,c.colors.secondary)
  end
  local speed,gear=layout.speed,layout.gear
  text(c,state.speedText or '000',speed[3],speed[1],speed[2],c.colors.primary,true,true)
  text(c,state.speedUnit or 'km/h',16,speed[1],speed[2]+speed[3]/2+9,c.colors.primary,true)
  if not layout.selector then text(c,state.gearText or 'N',gear[3],gear[1],gear[2],rpmColor(c),true,true) end
  if not layout.hideRpmValue then
    local p=layout.rpmValue
    text(c,'RPM ×1000',13,p[1],p[2]-22,c.colors.primary,true)
    text(c,state.rpmText or '0000',layout.rpmValueSize or 15,p[1],p[2],rpmColor(c),true)
  end
  drawAuxiliary(c)
  if layout.id~='concentric' then drawControls(c) end
  c.statusDrawing=true
  drawStatuses(c)
  c.statusDrawing=false
  if layout.id~='concentric' and not layout.selector then drawNeedle(c) end
  return true
end
return M
