local Readout=require('src/dial_readout')
local Light=require('ui/instrument_illumination')
local Layouts=require('src/digital_dial_variants')
local Theme=require('src/theme')
local General=require('src/general_settings')
local U=require('src/utils')
local Auxiliary=require('ui/analog_variants').auxiliary
local Icons=require('ui/side_instruments')
local M={}
local function pt(c,x,y) return c.origin+vec2(x*c.scale,y*c.scale) end
local function text(c,value,size,x,y,color,bold)
  value=Readout.value(value)
  if not value then return end
  if bold then ui.pushDWriteFont('Consolas;Weight=Bold') end
  local ink=color or c.C.primary
  Light.text(tostring(value),size*c.scale,pt(c,x,y),ink,nil,
    not c.statusDrawing and (size>=30 and c.L.value or c.L.label) or nil,c.scale)
  if bold then ui.popDWriteFont() end
end
local function line(c,x,y,a,b,color,width)
  ui.drawLine(pt(c,x,y),pt(c,a,b),color,(width or 1)*c.scale)
end
local function arc(c,x,y,r,a,b,color,width)
  ui.pathClear()
  ui.pathArcTo(pt(c,x,y),r*c.scale,math.rad(math.min(a,b)),math.rad(math.max(a,b)),64)
  ui.pathStroke(color,false,(width or 1)*c.scale)
end
local function poly(c,points,color,fill,width)
  ui.pathClear()
  for _,p in ipairs(points) do ui.pathLineTo(pt(c,p[1],p[2])) end
  if fill then ui.pathFillConvex(color) else ui.pathStroke(color,true,(width or 1)*c.scale) end
end
local function box(c,x,y,w,h,color,fill,cut)
  local a,b=w/2,h/2
  local d=cut or 12
  poly(c,{{x-a+d,y-b},{x+a-d,y-b},{x+a,y-b+d},{x+a,y+b-d},
    {x+a-d,y+b},{x-a+d,y+b},{x-a,y+b-d},{x-a,y-b+d}},color,fill)
end
local function circle(c,x,y,r,color,filled,width)
  if filled then ui.drawCircleFilled(pt(c,x,y),r*c.scale,color,96)
  else ui.drawCircle(pt(c,x,y),r*c.scale,color,96,(width or 1)*c.scale) end
end
local function blink(c,enabled,period)
  return enabled==false or math.floor((c.state.clock or 0)/period)%2==0
end
local function rpmInk(c)
  if c.state.rpmRedline then return blink(c,c.settings.animateRedlineAlert,0.12) and c.C.red or c.C.amber end
  if c.state.rpmWarning then return blink(c,c.settings.animateShiftAlert,0.14) and c.C.shiftBlue or c.C.amber end
  return c.C.primary
end
local function frame(c)
  local C,l=c.C,c.layout
  circle(c,310,304,266,C.void,true)
  circle(c,310,304,266,C.surface,true)
  circle(c,310,304,260,C.outlineDim,false,1)
  -- Fine engraved tracks and framed pedal bays echo the concept carcasses.
  for _,range in ipairs(l.cleanPerimeter and {} or {{-178,-154},{-26,-2},{26,51},{129,154}}) do
    for i=0,15 do
      local a=math.rad(range[1]+(range[2]-range[1])*i/15)
      line(c,310+252*math.cos(a),304+252*math.sin(a),
        310+258*math.cos(a),304+258*math.sin(a),C.amberDim)
    end
  end
  for i,p in ipairs(l.pedals) do
    if #p==4 and (i~=2 or c.settings.showClutch~=false) then
      local height=p[4]+(l.id=='orbit' and 16 or 38)
      box(c,p[1],p[2]-5,p[3]+30,height,C.panel,true,15)
      box(c,p[1],p[2]-5,p[3]+30,height,C.amberDim,false,15)
    end
  end
  for _,p in ipairs(l.panels or {}) do
    box(c,p[1],p[2],p[3],p[4],C.panel,true,24)
    box(c,p[1],p[2],p[3],p[4],C.cyan,false,24)
  end
  if l.core then
    local p=l.core
    circle(c,p[1],p[2],p[3]+9,C.cyan,false)
    circle(c,p[1],p[2],p[3],C.panel,true)
    circle(c,p[1],p[2],p[3],C.amber,false,2)
    circle(c,p[1],p[2],p[3]-7,C.outlineDim,false)
  end
  if l.id=='column' then
    line(c,250,220,370,220,C.cyan)
  elseif l.id=='radial' then
    for _,a in ipairs({-140,-40,140,40}) do
      local angle=math.rad(a)
      line(c,310+131*math.cos(angle),307+131*math.sin(angle),
        310+253*math.cos(angle),307+253*math.sin(angle),C.cyan)
    end
    line(c,235,315,385,315,C.cyan)
  elseif l.id=='orbit' then
    line(c,235,326,385,326,C.cyan)
    arc(c,310,315,172,-180,0,C.cyan,1)
  elseif l.id=='offset' then
    line(c,415,139,415,402,C.outline)
    line(c,422,147,422,394,C.outlineDim)
  else
    if not l.graduatedSteering then line(c,164,225,456,225,C.cyan) end
  end
end
local function rpm(c)
  local l,s,C=c.layout,c.state,c.C
  local maximum=math.max(s.rpmGaugeLimiter or s.rpmDisplayLimiter or 8000,1000)
  local limiter=math.max(s.rpmDisplayLimiter or maximum,1000)
  local fraction=U.clamp(s.rpmGaugeNormalized or (s.rpm or 0)/maximum,0,1)
  local warning=U.clamp(limiter*(s.rpmWarningFraction or 0.86)/maximum,0,1)
  local red=U.clamp(limiter*(s.rpmRedlineFraction or 0.96)/maximum,0,1)
  local n=l.rpm and 32 or 18
  for i=1,n do
    local f=(i-0.5)/n
    local color=f>=red and C.red or f>=warning and C.amber or C.primary
    if f>fraction then color=Theme.withAlpha(color,0.22)
    elseif s.rpmRedline or s.rpmWarning then color=rpmInk(c) end
    if l.rpm then Light.segment(c.origin,c.scale,l.rpmSegments[i],color,f<=fraction and c.L.segment or nil)
    else
      local p=l.rpmBar
      local y=p[2]+p[4]/2-i*p[4]/n
      ui.drawRectFilled(pt(c,p[1]-p[3]/2,y),pt(c,p[1]+p[3]/2,y+p[4]/n-3),f<=fraction and Light.color(color,c.L.segment) or color)
    end
  end
  local thousands=maximum/1000
  local step=thousands<=10 and 1 or thousands<=20 and 2 or 5
  if l.rpm then
    local r=l.rpm
    arc(c,r[1],r[2],r[3]+7,r[4],r[5],C.amber)
    arc(c,r[1],r[2],r[3]-33,r[4],r[5],C.outlineDim)
    for i=0,(l.dotAux and -1 or 64) do
      local a=math.rad(r[4]+(r[5]-r[4])*i/64)
      local rr=r[3]-37
      line(c,r[1]+rr*math.cos(a),r[2]+rr*math.sin(a),
        r[1]+(rr-5)*math.cos(a),r[2]+(rr-5)*math.sin(a),C.amberDim)
    end
  end
  for v=0,(l.hideRpmNumbers and -1 or thousands+0.001),step do
    if l.rpm then
      local r=l.rpm
      local a=math.rad(r[4]+(r[5]-r[4])*v/thousands)
      local rr=(l.id=='bridge' or l.id=='orbit') and r[3]-51 or r[3]+23
      text(c,string.format('%.0f',v),16,r[1]+rr*math.cos(a),r[2]+rr*math.sin(a),C.primary,true)
    else
      local p=l.rpmBar
      text(c,string.format('%.0f',v),14,p[1]+39,p[2]+p[4]/2-p[4]*v/thousands,C.primary)
    end
  end
  local p=l.rpmText
  text(c,'RPM',14,p[1],p[2]-25,C.primary)
  text(c,s.rpmText or '0',35,p[1],p[2],rpmInk(c),true)
end
local function meter(c,p,value,color,label,horizontal)
  local C=c.C
  if #p==5 then
    if not c.layout.cleanPerimeter then arc(c,p[1],p[2],p[3]+20,p[4],p[5],C.amberDim) end
    for i=1,10 do
      local span=(p[5]-p[4])/10
      arc(c,p[1],p[2],p[3],p[4]+(i-0.9)*span,p[4]+(i-0.1)*span,
        i<=math.floor(value*10+0.5) and Light.color(color,c.L.subSegment) or C.inactive,25)
    end
    local a=math.rad((p[4]+p[5])/2)
    text(c,label,12,p[1]+(p[3]-32)*math.cos(a),p[2]+(p[3]-32)*math.sin(a),C.primary)
    return
  end
  box(c,p[1],p[2],p[3]+10,p[4]+10,C.panel,true,2)
  box(c,p[1],p[2],p[3]+10,p[4]+10,C.amberDim,false,2)
  local count=horizontal and 20 or 10
  for i=1,count do
    local x=p[1]-p[3]/2+(horizontal and (i-1)*p[3]/count or 0)
    local y=p[2]+p[4]/2-(horizontal and p[4] or i*p[4]/count)
    ui.drawRectFilled(pt(c,x,y),pt(c,x+(horizontal and p[3]/count-2 or p[3]),
      y+(horizontal and p[4] or p[4]/count-2)),i<=math.floor(value*count+0.5) and Light.color(color,c.L.subSegment) or C.inactive)
  end
  if horizontal and c.layout.id=='column' then
    text(c,'CL',10,p[1]-p[3]/2-17,p[2],C.primary)
  elseif horizontal then
    text(c,label,10,p[1]-p[3]/2-27,p[2],C.primary)
  else
    text(c,label,12,p[1],p[2]-p[4]/2-14,C.primary)
  end
end
local function controls(c)
  local l,s,C=c.layout,c.state,c.C
  meter(c,l.pedals[1],U.clamp(s.brake or 0,0,1),C.red,'BRAKE',false)
  if c.settings.showClutch~=false then
    meter(c,l.pedals[2],U.clamp(s.clutch or 0,0,1),C.amber,'CLUTCH',l.id=='column' or l.id=='radial' or l.id=='orbit')
  end
  meter(c,l.pedals[3],U.clamp(s.throttle or 0,0,1),C.cyan,'THROTTLE',false)
  if c.settings.showSteering~=false then
    if l.id=='orbit' or l.steeringRing then
      local p=l.core
      local angle=-math.pi/2+U.clamp(s.steeringInput or 0,-1,1)*math.rad(145)
      local radius=p[3]+9
      if l.id=='orbit' then
        for i=-16,16 do
          local a=-math.pi/2+math.rad(145)*i/16
          local length=i==0 and 9 or i%4==0 and 6 or 3
          line(c,p[1]+radius*math.cos(a),p[2]+radius*math.sin(a),
            p[1]+(radius+length)*math.cos(a),p[2]+(radius+length)*math.sin(a),
            i==0 and C.primary or C.outline, i==0 and 2 or 1)
        end
      end
      local x,y=p[1]+radius*math.cos(angle),p[2]+radius*math.sin(angle)
      local halo=Light.halo(C.cyan,c.L.icon)
      if halo then circle(c,x,y,8,halo,true) end
      circle(c,x,y,5,Light.color(C.cyan,c.L.icon),true)
      circle(c,x,y,5,C.outline,false)
      circle(c,x,y,1.7,C.primary,true)
    else
    local p=l.steering
    line(c,p[1]-p[3],p[2],p[1]+p[3],p[2],C.outline,1)
    if l.graduatedSteering then
      for i=-10,10 do
        local x=p[1]+p[3]*i/10
        local height=i==0 and 9 or i%5==0 and 6 or 3
        line(c,x,p[2]-height,x,p[2]+height,i==0 and C.primary or C.outline, i==0 and 2 or 1)
      end
    else line(c,p[1],p[2]-4,p[1],p[2]+4,C.primary) end
    local x=p[1]+p[3]*U.clamp(s.steeringInput or 0,-1,1)
    line(c,x,p[2]-(l.graduatedSteering and 10 or 4),x,p[2]+(l.graduatedSteering and 10 or 4),Light.color(C.cyan,c.L.icon),3)
    end
  end
end
local function statuses(c)
  local s,l,C=c.state,c.layout,c.C
  for i,label in ipairs({'TC','ABS','LIGHTS','PIT'}) do
    if i~=3 or c.settings.showLights~=false then
      local p=l.statuses[i]
      box(c,p[1],p[2],58,44,C.panel,true,5)
      local active=i==1 and s.tcActive or i==2 and s.absActive
        or i==3 and s.headlights and s.lightsAvailable or i==4 and (s.pitLimiter or s.pitLane)
      local color=active and C.amber or C.primary
      box(c,p[1],p[2],58,44,active and C.amber or C.amberDim,false,5)
      text(c,label,11,p[1],p[2]-11,C.primary)
      if i==3 then
        local ink=active and (s.highBeams and C.amber or C.cyan) or C.secondary
        arc(c,p[1]-10,p[2],8,-90,90,ink,2)
        line(c,p[1]-10,p[2]-8,p[1]-10,p[2]+8,ink,2)
        for j=-1,1 do line(c,p[1]+2,p[2]+j*5,p[1]+10,p[2]+j*6,ink,2) end
      else
        local level=i==1 and s.tcLevel or i==2 and s.absLevel or nil
        text(c,level~=nil and c.settings.showTcAbsLevels~=false and tostring(level) or (active and 'ON' or '—'),
          21,p[1],p[2]+8,color,true)
      end
    end
  end
  local p=l.warning
  local ink=(s.handbrake or 0)>0.9 and C.red or C.outlineDim
  poly(c,{{p[1],p[2]-11},{p[1]+12,p[2]+10},{p[1]-12,p[2]+10}},ink,false,2)
  text(c,'!',16,p[1],p[2]+2,ink,true)
  p=l.flag
  local flag=s.raceFlagType
  local flagColor=flag==2 and C.flagYellow or (flag==5 or flag==8) and C.red
    or flag==12 and C.shiftBlue or (flag==13 or flag==14) and C.primary or nil
  ink=flagColor and blink(c,c.settings.animateFlagAlert,0.42) and flagColor or C.outlineDim
  line(c,p[1]-7,p[2]-8,p[1]-7,p[2]+8,ink,2)
  ui.drawRectFilled(pt(c,p[1]-5,p[2]-8),pt(c,p[1]+9,p[2]),ink)
end
local function upperGauge(c,p,label,value,fraction,color)
  circle(c,p[1],p[2],47,c.C.panel,true)
  arc(c,p[1],p[2],46,-210,30,c.C.outline,1)
  for i=1,16 do
    local ink=fraction and i<=math.floor(U.clamp(fraction,0,1)*16+0.5) and color or c.C.inactive
    arc(c,p[1],p[2],40,-210+(i-0.9)*15,-210+(i-0.1)*15,Light.color(ink,c.L.subSegment),5)
  end
  text(c,label,10,p[1],p[2]-9,c.C.secondary)
  text(c,value,16,p[1],p[2]+10,color,true)
end
local function valueFraction(a)
  if a.electric and a.charge~=nil then return U.clamp(a.charge,0,1) end
  return a.fraction and U.clamp(math.abs(a.fraction),0,1) or nil
end
local function meterColor(c,a)
  if a.label=='FUEL' then return Readout.fuelColor(a.fraction,c.state,c.C,c.C.amber) end
  return a.recovery and c.C.green or (a.label=='TURBO' or a.electric) and c.C.cyan or c.C.amber
end
local function drawPerimeterBar(c,p,a,label,position)
  local value=valueFraction(a)
  local ink=meterColor(c,a)
  local count,start,finish=12,p[4],p[5]
  for i=1,count do
    local delta=(finish-start)/count
    local from=start+(i-0.88)*delta
    local to=start+(i-0.12)*delta
    arc(c,p[1],p[2],p[3],from,to,
      value and i<=math.floor(value*count+0.5) and Light.color(ink,c.L.segment) or c.C.inactive,
      c.layout.id=='orbit' and 7 or 15)
  end
  local mid=math.rad((start+finish)/2)
  text(c,label,11,p[1]+(p[3]-20)*math.cos(mid),p[2]+(p[3]-20)*math.sin(mid),c.C.secondary)
  local reading=(c.layout.hideUnits or c.layout.hideAuxUnits) and (a.value:match('[%+%-]?%d+%.?%d*') or a.value) or a.value
  if not c.layout.hideAuxValues then
    text(c,reading,position and 12 or 10,
      position and position[1] or p[1]+(p[3]-20)*math.cos(mid),
      position and position[2] or p[2]+(p[3]-20)*math.sin(mid)+16,ink,true)
  end
end
local function edgeIcon(c,p,a)
  if not p or not a then return end
  local ink=Light.color(meterColor(c,a),c.L.icon)
  local center=pt(c,p[1],p[2])
  if a.electric then
    ui.drawRect(center-vec2(8,5)*c.scale,center+vec2(8,5)*c.scale,ink,0,nil,1.5*c.scale)
    line(c,p[1]+10,p[2]-2,p[1]+10,p[2]+2,ink,2)
    line(c,p[1]-5,p[2],p[1]-1,p[2],ink,1)
    line(c,p[1]-3,p[2]-2,p[1]-3,p[2]+2,ink,1)
    line(c,p[1]+3,p[2],p[1]+5,p[2],ink,1)
  else
    local draw=a.label=='FUEL' and Icons.fuelIcon or a.label=='AERO' and Icons.aeroIcon or Icons.boostIcon
    draw(center,c.scale*0.8,ink)
  end
end
local function drawSideBar(c,p,a,label)
  local value=valueFraction(a)
  local active=value and math.floor(value*14+0.5) or 0
  local ink=meterColor(c,a)
  local x,y,w,h=p[1],p[2],p[3],p[4]
  box(c,x,y,w+16,h+20,c.C.panel,true,5)
  box(c,x,y,w+16,h+20,c.C.amberDim,false,5)
  text(c,label,11,x,y-h/2-24,c.C.primary)
  text(c,a.value,10,x,y+h/2+21,ink,true)
  for i=1,14 do
    local top=y+h/2-i*h/14
    ui.drawRectFilled(pt(c,x-w/2,top),pt(c,x+w/2,top+h/14-2),
      i<=active and Light.color(ink,c.L.segment) or c.C.inactive)
  end
end
local function auxiliary(c)
  local a=Auxiliary(c.state,c.settings.analogAuxiliaryMode)
  if c.layout.dotAux then
    local r=c.layout.rpm
    local value=a and valueFraction(a)
    local ink=a and meterColor(c,a) or c.C.inactive
    for i=0,64 do
      local angle=math.rad(r[4]+(r[5]-r[4])*i/64)
      local active=value and (i+0.5)/65<=value
      circle(c,r[1]+(r[3]-37)*math.cos(angle),r[2]+(r[3]-37)*math.sin(angle),
        1.8,active and Light.color(ink,c.L.subSegment) or c.C.inactive,true)
    end
    if a then
      local value=a.value
      if a.electric then value=value..'  '..(a.charge and string.format('%.0f%%',a.charge*100) or '--%') end
      text(c,value,13,c.layout.aux[1],c.layout.aux[2],ink,true)
    end
    return
  end
  if c.layout.edgeAux then
    local left=a
    if left and left.label=='FUEL' then left=Auxiliary(c.state,'turbo') end
    if left and left.label=='AERO' and c.settings.analogAuxiliaryMode=='electric' then
      left=Auxiliary(c.state,'electric')
    end
    if left and left.electric and left.charge~=nil then
      left.value=string.format('%.0f%%',left.charge*100)
    end
    local fuel=Auxiliary(c.state,'fuel')
    local readings=c.layout.edgeReadings
    if left then drawPerimeterBar(c,c.layout.edgeAux[1],left,
      left.electric and 'BAT' or left.label,readings and readings[1]) end
    drawPerimeterBar(c,c.layout.edgeAux[2],fuel,'FUEL',readings and readings[2])
    if c.layout.edgeIcons then
      edgeIcon(c,c.layout.edgeIcons[1],left)
      edgeIcon(c,c.layout.edgeIcons[2],fuel)
    end
    return
  end
  if c.layout.sideAux then
    local left=a
    if left and left.label=='FUEL' then left=Auxiliary(c.state,'turbo') end
    if left and left.electric and left.charge~=nil then
      left.value=string.format('%.0f%%',left.charge*100)
    end
    local fuel=Auxiliary(c.state,'fuel')
    if left then drawSideBar(c,c.layout.sideAux[1],left,left.electric and 'BATTERY' or left.label) end
    drawSideBar(c,c.layout.sideAux[2],fuel,'FUEL')
    return
  end
  if c.layout.fuel then
    local fuel=Auxiliary(c.state,'fuel')
    upperGauge(c,c.layout.fuel,'FUEL',fuel.value,fuel.fraction,
      fuel.fraction and fuel.fraction<0.15 and c.C.red or c.C.primary)
    if not a then return end
    if a.label=='FUEL' then a=Auxiliary(c.state,'turbo') end
    upperGauge(c,c.layout.aux,a.electric and 'BATTERY' or a.label,
      a.electric and (a.charge and string.format('%.0f%%',a.charge*100) or 'N/A') or a.value,
      a.electric and a.charge or a.fraction,a.recovery and c.C.green or c.C.cyan)
    return
  end
  if not a then return end
  local p=c.layout.aux
  local ink=meterColor(c,a)
  local value=a.label..'  '..a.value
  if a.electric then value=value..'  BAT '..(a.charge and string.format('%.0f%%',a.charge*100) or '--%') end
  text(c,value,a.electric and 11 or 13,p[1],p[2],ink,true)
end
function M.draw(state,settings,origin,scale)
  local layout=Layouts.get(settings.digitalVariant)
  if not layout then return false end
  local c={layout=layout,state=state,settings=settings,origin=origin,scale=scale,
    C=General.palette(Theme.get(settings.theme),settings.backgroundOpacity)}
  c.L=Light.resolve(c.C,settings.theme,state.gt7Instruments and state.gt7Instruments.light or (state.headlights and 1 or 0))
  frame(c)
  rpm(c)
  local speed,gear=layout.speed,layout.gear
  if layout.speedLabel then text(c,'SPEED',14,speed[1],speed[2]-speed[3]/2-10) end
  if layout.gearLabel then text(c,'GEAR',14,gear[1],gear[2]-gear[3]/2-10) end
  text(c,state.speedText or '0',speed[3],speed[1],speed[2],c.C.primary,true)
  if not layout.hideUnits then text(c,state.speedUnit or 'km/h',16,speed[1],speed[2]+speed[3]/2+7) end
  text(c,state.gearText or 'N',gear[3],gear[1],gear[2],rpmInk(c),true)
  controls(c)
  auxiliary(c)
  c.statusDrawing=true
  statuses(c)
  return true
end
return M
