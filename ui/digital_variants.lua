local Layouts=require('src/digital_dial_variants')
local Theme=require('src/theme')
local General=require('src/general_settings')
local U=require('src/utils')
local Auxiliary=require('ui/analog_variants').auxiliary
local M={}
local palettes={}
for _,name in ipairs({'dark','light'}) do
  local p={}
  for k,v in pairs(Theme.get(name)) do p[k]=v end
  if name=='dark' then
    p.primary=rgbm(1,0.93,0.75,1)
    p.cyan=rgbm(0.20,0.75,0.95,1)
    p.amber=rgbm(1,0.69,0.24,1)
    p.green=rgbm(0.27,0.86,0.25,1)
    p.void=rgbm(0.018,0.019,0.017,1)
    p.surface=rgbm(0.035,0.037,0.033,1)
    p.panel=rgbm(0.022,0.025,0.023,1)
    p.inactive=rgbm(0.12,0.115,0.085,1)
  end
  palettes[name]=p
end
local function pt(c,x,y) return c.origin+vec2(x*c.scale,y*c.scale) end
local function text(c,value,size,x,y,color,bold)
  if bold then ui.pushDWriteFont('Consolas;Weight=Bold') end
  local v=tostring(value)
  local p=pt(c,x,y)-ui.measureDWriteText(v,size*c.scale)/2
  if c.state.headlights then
    ui.dwriteDrawText(v,size*c.scale,p+vec2(c.scale*0.7,0),Theme.withAlpha(color or c.C.primary,0.12))
  end
  ui.dwriteDrawText(v,size*c.scale,p,color or c.C.primary)
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
  circle(c,310,304,292,C.void,true)
  circle(c,310,304,287,C.metal,false,3)
  circle(c,310,304,279,C.outlineDim,false,5)
  circle(c,310,304,270,C.surface,true)
  circle(c,310,304,269,C.amber,false,1)
  circle(c,310,304,260,C.outlineDim,false,1)
  -- Fine engraved tracks and framed pedal bays echo the concept carcasses.
  for _,range in ipairs({{-178,-154},{-26,-2},{26,51},{129,154}}) do
    for i=0,15 do
      local a=math.rad(range[1]+(range[2]-range[1])*i/15)
      line(c,310+252*math.cos(a),304+252*math.sin(a),
        310+258*math.cos(a),304+258*math.sin(a),C.amberDim)
    end
  end
  for i,p in ipairs(l.pedals) do
    if #p==4 and (i~=2 or c.settings.showClutch~=false) then
      box(c,p[1],p[2]-5,p[3]+52,p[4]+52,C.panel,true,15)
      box(c,p[1],p[2]-5,p[3]+52,p[4]+52,C.amberDim,false,15)
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
    line(c,235,340,385,340,C.cyan)
    arc(c,310,296,164,-180,0,C.cyan,1)
  elseif l.id=='offset' then
    line(c,359,104,359,424,C.amber)
    line(c,367,119,367,417,C.outlineDim)
  else
    line(c,164,225,456,225,C.cyan)
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
    if l.rpm then poly(c,l.rpmSegments[i],color,true)
    else
      local p=l.rpmBar
      local y=p[2]+p[4]/2-i*p[4]/n
      ui.drawRectFilled(pt(c,p[1]-p[3]/2,y),pt(c,p[1]+p[3]/2,y+p[4]/n-3),color)
    end
  end
  local thousands=maximum/1000
  local step=thousands<=10 and 1 or thousands<=20 and 2 or 5
  if l.rpm then
    local r=l.rpm
    arc(c,r[1],r[2],r[3]+7,r[4],r[5],C.amber)
    arc(c,r[1],r[2],r[3]-33,r[4],r[5],C.outlineDim)
    for i=0,64 do
      local a=math.rad(r[4]+(r[5]-r[4])*i/64)
      local rr=r[3]-37
      line(c,r[1]+rr*math.cos(a),r[2]+rr*math.sin(a),
        r[1]+(rr-5)*math.cos(a),r[2]+(rr-5)*math.sin(a),C.amberDim)
    end
  end
  for v=0,thousands+0.001,step do
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
    arc(c,p[1],p[2],p[3]+20,p[4],p[5],C.amberDim)
    for i=1,10 do
      local span=(p[5]-p[4])/10
      arc(c,p[1],p[2],p[3],p[4]+(i-0.9)*span,p[4]+(i-0.1)*span,
        i<=math.floor(value*10+0.5) and color or C.inactive,25)
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
      y+(horizontal and p[4] or p[4]/count-2)),i<=math.floor(value*count+0.5) and color or C.inactive)
  end
  if horizontal and c.layout.id=='column' then
    text(c,label,10,p[1],p[2]-20,C.primary)
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
    local p=l.steering
    line(c,p[1]-p[3],p[2],p[1]+p[3],p[2],C.outline,1)
    line(c,p[1],p[2]-4,p[1],p[2]+4,C.primary)
    local x=p[1]+p[3]*U.clamp(s.steeringInput or 0,-1,1)
    line(c,x,p[2]-4,x,p[2]+4,C.cyan,3)
  end
end
local function turn(c,p,right,active)
  local x,y=p[1],p[2]
  local ink=active and c.C.green or c.C.outlineDim
  ui.drawRectFilled(pt(c,x-8,y-6),pt(c,x+8,y+6),ink)
  poly(c,right and {{x+2,y-15},{x+18,y},{x+2,y+15}}
    or {{x-2,y-15},{x-2,y+15},{x-18,y}},ink,true)
end
local function statuses(c)
  local s,l,C=c.state,c.layout,c.C
  for i,label in ipairs({'TC','ABS','LIGHTS','PIT'}) do
    if i~=3 or c.settings.showLights~=false then
      local p=l.statuses[i]
      box(c,p[1],p[2],65,54,C.panel,true,5)
      local active=i==1 and s.tcActive or i==2 and s.absActive
        or i==3 and s.headlights and s.lightsAvailable or i==4 and (s.pitLimiter or s.pitLane)
      local color=active and C.amber or C.primary
      box(c,p[1],p[2],65,54,active and C.amber or C.amberDim,false,5)
      text(c,label,11,p[1],p[2]-15,C.primary)
      if i==3 then
        local ink=active and (s.highBeams and C.amber or C.cyan) or C.secondary
        arc(c,p[1]-3,p[2]+7,8,-90,90,ink,2)
        line(c,p[1]-3,p[2]-1,p[1]-3,p[2]+15,ink,2)
        for j=-1,1 do line(c,p[1]+9,p[2]+7+j*5,p[1]+17,p[2]+7+j*6,ink,2) end
      else
        local level=i==1 and s.tcLevel or i==2 and s.absLevel or nil
        text(c,level~=nil and c.settings.showTcAbsLevels~=false and tostring(level) or (active and 'ON' or '—'),
          21,p[1],p[2]+9,color,true)
      end
    end
  end
  local phase=s.indicatorPhase
  local lit=c.settings.animateIndicators==false or phase==true or (type(phase)=='number' and phase>0.5)
    or (phase==nil and blink(c,true,0.42))
  turn(c,l.turns[1],false,lit and (s.leftIndicator or s.hazardLights))
  turn(c,l.turns[2],true,lit and (s.rightIndicator or s.hazardLights))
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
local function auxiliary(c)
  local a=Auxiliary(c.state,c.settings.analogAuxiliaryMode)
  if not a then return end
  local p=c.layout.aux
  local ink=a.recovery and c.C.green or c.C.cyan
  local value=a.label..'  '..a.value
  if a.electric then value=value..'  BAT '..(a.charge and string.format('%.0f%%',a.charge*100) or '--%') end
  text(c,value,a.electric and 11 or 13,p[1],p[2],ink,true)
end
function M.draw(state,settings,origin,scale)
  local layout=Layouts.get(settings.digitalVariant)
  if not layout then return false end
  local c={layout=layout,state=state,settings=settings,origin=origin,scale=scale,
    C=General.palette(palettes[settings.theme=='light' and 'light' or 'dark'],settings.backgroundOpacity)}
  frame(c)
  rpm(c)
  local speed,gear=layout.speed,layout.gear
  if layout.speedLabel then text(c,'SPEED',14,speed[1],speed[2]-speed[3]/2-10) end
  if layout.gearLabel then text(c,'GEAR',14,gear[1],gear[2]-gear[3]/2-10) end
  text(c,state.speedText or '0',speed[3],speed[1],speed[2],c.C.primary,true)
  text(c,state.speedUnit or 'km/h',16,speed[1],speed[2]+speed[3]/2+7)
  text(c,state.gearText or 'N',gear[3],gear[1],gear[2],rpmInk(c),true)
  controls(c)
  auxiliary(c)
  statuses(c)
  return true
end
return M
