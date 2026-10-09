local Layouts = require('src/dial_variants')
local Theme = require('src/theme')
local General = require('src/general_settings')
local U = require('src/utils')
local Config = require('src/instrument_config')
local Needle = require('ui/instrument_needle')
local Hybrid = require('src/hybrid')
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
    imagesByVariant[id][theme] = {back=imageRoot .. images.back,front=imageRoot .. images.front}
  end
end

local variantPalettes = {}
for _,theme in ipairs({'dark','light'}) do
  local palette = {}
  for role,color in pairs(Theme.get(theme)) do palette[role] = color end
  if theme == 'dark' then
    palette.primary = rgbm(0.96,0.955,0.90,1)
    palette.secondary = rgbm(0.62,0.63,0.61,0.95)
    palette.cyan = rgbm(0.19,0.80,0.91,1)
    palette.amber = rgbm(1,0.72,0.12,1)
    palette.green = rgbm(0.32,0.90,0.20,1)
  end
  variantPalettes[theme] = palette
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

local function point(c, x, y) return c.origin + vec2(x*c.scale, y*c.scale) end
local function text(c, value, size, x, y, color, backlight, bold)
  if bold then ui.pushDWriteFont(boldFont) end
  size = size*c.scale
  local p = point(c,x,y) - ui.measureDWriteText(tostring(value),size)/2
  if backlight and c.state.headlights then
    local glow = Theme.withAlpha(c.colors.backlight,0.18)
    ui.dwriteDrawText(tostring(value),size,p+vec2(-c.scale,0),glow)
    ui.dwriteDrawText(tostring(value),size,p+vec2(c.scale,0),glow)
  end
  ui.dwriteDrawText(tostring(value),size,p,color or c.colors.primary)
  if bold then ui.popDWriteFont() end
end
local function line(c,x1,y1,x2,y2,color,width)
  ui.drawLine(point(c,x1,y1),point(c,x2,y2),color,(width or 1)*c.scale)
end
local function arc(c,x,y,r,a,b,color,width)
  ui.pathClear()
  ui.pathArcTo(point(c,x,y),r*c.scale,math.rad(a),math.rad(b),32)
  ui.pathStroke(color,false,width*c.scale)
end
local function polygon(c,points,color)
  ui.pathClear()
  for _,p in ipairs(points) do ui.pathLineTo(point(c,p[1],p[2])) end
  ui.pathFillConvex(color)
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
  local r=l.rpm
  local limiter=math.max(s.rpmDisplayLimiter or 8000,1000)
  local maximum=math.max(s.rpmGaugeLimiter or math.ceil(limiter/1000)*1000,1000)
  local warning=U.clamp(limiter*(s.rpmWarningFraction or 0.86)/maximum,0,1)
  local red=U.clamp(limiter*(s.rpmRedlineFraction or 0.96)/maximum,0,1)
  arc(c,r[1],r[2],r[3]+3,r[4],r[5],C.outlineDim,1)
  for i,band in ipairs(l.bands) do
    local f=(i-0.5)/64
    if f>=warning then
      local color=f>=red and (s.rpmRedline and rpmColor(c) or C.red) or C.amber
      if f<red and s.rpmWarning and pulse(s,c.settings.animateShiftAlert,0.14) then color=C.shiftBlue end
      polygon(c,band,color)
    end
  end
  for _,tick in ipairs(l.ticks) do
    local length=tick[3]>=warning and 5 or 9
    line(c,r[1]+(r[3]-length)*tick[1],r[2]+(r[3]-length)*tick[2],
      r[1]+r[3]*tick[1],r[2]+r[3]*tick[2],C.primary,1)
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
  Needle.draw(point(c,r[1],r[2]),c.scale*(r[3]-40)/preset.length,
    l.startAngle+(l.endAngle-l.startAngle)*U.clamp(s.analogNeedleNormalized or 0,0,1),
    preset,C,s.headlights and 1 or 0,s.rpmWarning and rpmColor(c) or nil)
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
    ui.drawRectFilled(point(c,x1,y),point(c,x1+w/count-2,y+h),active and color or c.colors.inactive)
  end
  if signed then line(c,x+w/2,y-2,x+w/2,y+h+2,c.colors.secondary,1) end
end
local function auxColor(c,a)
  if a.electric then return (a.recovery or (a.fraction or 0)<0) and c.colors.green or c.colors.cyan end
  if a.label=='FUEL' then return (a.fraction or 1)<0.15 and c.colors.red or c.colors.primary end
  return a.label=='AERO' and (a.fraction or 0)>=0.82 and c.colors.amber or c.colors.cyan
end
local function drawAuxiliary(c)
  local a=M.auxiliary(c.state,c.settings.analogAuxiliaryMode)
  if not a then return end
  local p,C=c.layout.aux,c.colors
  local color=auxColor(c,a)
  if c.layout.auxStyle=='screen' then
    local x,y,w,h=p[1],p[2],p[3],p[4]
    text(c,a.label,13,x,y-h/2+10,C.primary,true)
    text(c,a.value,17,x,y-h/2+30,color,true,true)
    bar(c,x-w/2+5,y-2,w-10,22,a.fraction,color,a.electric)
    if a.electric then
      bar(c,x-w/2+5,y+25,w-48,7,a.charge,a.charge and a.charge<=0.15 and C.red or C.green)
      text(c,a.charge and string.format('%.0f%%',a.charge*100) or '--%',10,x+w/2-17,y+29,C.primary)
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
    if l.pedalStyle=='arc' then
      local a,b=p[4],p[5]
      arc(c,p[1],p[2],p[3],a,b,C.inactive,6)
      if value>0 then arc(c,p[1],p[2],p[3],a,a+(b-a)*value,color,6) end
      local mid=math.rad((a+b)/2)
      text(c,i==1 and 'BRK' or 'THR',8,p[1]+(p[3]-12)*math.cos(mid),p[2]+(p[3]-12)*math.sin(mid),C.secondary)
    else
      line(c,p[1],p[2],p[3],p[4],C.inactive,6)
      if value>0 then line(c,p[1],p[2],p[1]+(p[3]-p[1])*value,p[2]+(p[4]-p[2])*value,color,6) end
    end
  end
  if c.settings.showClutch~=false then
    local p=l.clutch
    line(c,p[1]-p[3]/2,p[2],p[1]+p[3]/2,p[2],C.inactive,4)
    line(c,p[1]-p[3]/2,p[2],p[1]-p[3]/2+p[3]*U.clamp(s.clutch or 0,0,1),p[2],C.cyan,4)
    text(c,'CL',8,p[1]-p[3]/2-11,p[2],C.secondary)
  end
  if c.settings.showSteering~=false then
    local p=l.steering
    line(c,p[1]-p[3],p[2],p[1]+p[3],p[2],C.outline,2)
    line(c,p[1],p[2]-5,p[1],p[2]+5,C.primary,1)
    ui.drawCircleFilled(point(c,p[1]+U.clamp(s.steeringInput or 0,-1,1)*p[3],p[2]),3*c.scale,C.cyan,16)
    text(c,s.steeringAngle and string.format('%+d°',U.round(s.steeringAngle)) or 'INPUT',9,p[1],p[2]+14,C.secondary)
  end
end

local function status(c,position,label,level,available,active,color)
  local x,y=position[1],position[2]
  local C=c.colors
  local p=point(c,x,y)
  ui.drawCircleFilled(p,22*c.scale,C.panel,32)
  ui.drawCircle(p,22*c.scale,active and color or (available and C.amberDim or C.outlineDim),32,(active and 2 or 1)*c.scale)
  local ink=active and color or (available and C.primary or C.secondary)
  local levels=c.settings.showTcAbsLevels~=false and (label=='TC' or label=='ABS')
  text(c,label,label=='ABS' and 12 or 14,x,y-(levels and 7 or 0),ink,active)
  if levels then text(c,level~=nil and tostring(level) or '—',12,x,y+10,ink) end
end
local function turn(c,position,right,active)
  local x,y=position[1],position[2]
  local color=active and c.colors.green or c.colors.outlineDim
  -- Two convex pieces: CSP cannot fill the concave outline of a whole arrow.
  ui.drawRectFilled(point(c,x-9,y-5),point(c,x+7,y+5),color)
  if right then
    polygon(c,{{x+2,y-13},{x+17,y},{x+2,y+13}},color)
  else
    polygon(c,{{x-2,y-13},{x-2,y+13},{x-17,y}},color)
  end
end
local function drawStatuses(c)
  local s,l,C=c.state,c.layout,c.colors
  status(c,l.statuses[1],'TC',s.tcLevel,s.tcSupported or s.tcLevel~=nil,s.tcActive==true,C.amber)
  status(c,l.statuses[2],'ABS',s.absLevel,s.absSupported or s.absLevel~=nil,s.absActive==true,C.amber)
  if c.settings.showLights~=false then
    local p=l.statuses[3]
    status(c,p,'',nil,s.lightsAvailable,s.headlights and s.lightsAvailable,s.highBeams and C.amber or C.cyan)
    local ink=s.headlights and s.lightsAvailable and (s.highBeams and C.amber or C.cyan) or C.secondary
    arc(c,p[1]-1,p[2],8,-90,90,ink,2)
    line(c,p[1]-1,p[2]-8,p[1]-1,p[2]+8,ink,2)
    for j=-1,1 do line(c,p[1]-13,p[2]+j*5,p[1]-5,p[2]+j*4,ink,1) end
  end
  status(c,l.statuses[4],'PIT',nil,s.pitLimiter~=nil or s.pitLane,s.pitLimiter==true or s.pitLane,C.amber)
  local phase=s.indicatorPhase
  local blink=c.settings.animateIndicators==false or (type(phase)=='boolean' and phase)
    or (type(phase)=='number' and phase>0.5)
    or (phase==nil and pulse(s,true,0.42))
  turn(c,l.turns[1],false,(s.leftIndicator or s.hazardLights) and blink)
  turn(c,l.turns[2],true,(s.rightIndicator or s.hazardLights) and blink)
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
    colors=General.palette(variantPalettes[settings.theme=='light' and 'light' or 'dark'],settings.backgroundOpacity)}
  local images=imagesByVariant[layout.id][settings.theme=='light' and 'light' or 'dark']
  local tint=rgbm(1,1,1,U.clamp((settings.backgroundOpacity or 0.72)/0.72,0,1))
  local finish=point(c,620,620)
  -- The structural bezel is also drawn natively: first-frame asynchronous
  -- texture loading can never leave the instrument floating without a face.
  local center=point(c,310,304)
  if layout.id=='concentric' then
    -- Leave the center opening genuinely transparent, even before PNG loading.
    arc(c,310,304,234,0,360,c.colors.surface,116)
  else
    ui.drawCircleFilled(center,292*scale,c.colors.void,96)
    ui.drawCircleFilled(center,268*scale,c.colors.surface,96)
  end
  ui.drawCircle(center,290*scale,c.colors.metal,96,3*scale)
  ui.drawCircle(center,279*scale,c.colors.metalDim,96,4*scale)
  ui.drawCircle(center,268*scale,c.colors.outlineDim,96,2*scale)
  ui.drawImage(images.back,origin,finish,tint)
  drawRpm(c)
  if layout.id~='shelf' and layout.id~='fan' then drawNeedle(c) end
  if layout.id=='concentric' then
    -- Opaque center masks the hand regardless of shell opacity.
    ui.drawCircleFilled(point(c,310,334),99*scale,
      settings.theme=='light' and rgbm(0.925,0.925,0.92,1) or rgbm(0.04,0.04,0.035,1),96)
  end
  ui.drawImage(images.front,origin,finish,tint)
  local speed,gear=layout.speed,layout.gear
  text(c,state.speedText or '000',speed[3],speed[1],speed[2],c.colors.primary,true,true)
  text(c,state.speedUnit or 'km/h',16,speed[1],speed[2]+speed[3]/2+9,c.colors.primary,true)
  text(c,state.gearText or 'N',gear[3],gear[1],gear[2],rpmColor(c),true,true)
  local p=layout.rpmValue
  text(c,'RPM ×1000',13,p[1],p[2]-22,c.colors.primary,true)
  text(c,state.rpmText or '0000',15,p[1],p[2],rpmColor(c),true)
  drawAuxiliary(c)
  drawControls(c)
  drawStatuses(c)
  if layout.id=='shelf' or layout.id=='fan' then drawNeedle(c) end
  return true
end
return M
