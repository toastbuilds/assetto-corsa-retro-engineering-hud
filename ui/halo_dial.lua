-- Shared live geometry for the standalone 6A/6D Halo faces.
local U=require('src/utils')
local Theme=require('src/theme')
local Readout=require('src/dial_readout')
local Light=require('ui/instrument_illumination')
local Icons=require('ui/side_instruments')
local M={}

local function prepare(layout)
  if layout.haloGeometry then return layout.haloGeometry end
  local r=layout.rpm
  local g={dots={},ticks={}}
  for i=0,16 do
    local a=math.rad(r[4]+(r[5]-r[4])*i/16)
    if i~=8 then g.dots[#g.dots+1]={r[1]+r[3]*math.cos(a),r[2]+r[3]*math.sin(a),i/16} end
  end
  for i=0,79 do
    local a=math.rad(-90+i*4.5)
    local length=i%10==0 and 8 or i%5==0 and 5 or 3
    g.ticks[#g.ticks+1]={r[1]+(254-length)*math.cos(a),r[2]+(254-length)*math.sin(a),
      r[1]+254*math.cos(a),r[2]+254*math.sin(a),i%10==0}
  end
  layout.haloGeometry=g
  return g
end
local function pulse(state,enabled,period)
  return enabled==false or math.floor((state.clock or 0)/period)%2==0
end
local function warningInk(state,settings,C)
  if state.rpmRedline then
    return pulse(state,settings.animateRedlineAlert,0.12) and C.red or C.amber
  end
  return pulse(state,settings.animateShiftAlert,0.14) and C.shiftBlue or C.amber
end

function M.rpm(origin,scale,layout,state,settings,C,L)
  local function p(x,y) return origin+vec2(x*scale,y*scale) end
  local r,g=layout.rpm,prepare(layout)
  local maximum=math.max(state.rpmGaugeLimiter or state.rpmDisplayLimiter or 8000,1000)
  local limiter=math.max(state.rpmDisplayLimiter or maximum,1000)
  local fraction=U.clamp(state.rpmGaugeNormalized or (state.rpm or 0)/maximum,0,1)
  local warning=U.clamp(limiter*(state.rpmWarningFraction or 0.86)/maximum,0,1)
  local red=U.clamp(limiter*(state.rpmRedlineFraction or 0.96)/maximum,0,1)
  for _,t in ipairs(g.ticks) do
    ui.drawLine(p(t[1],t[2]),p(t[3],t[4]),t[5] and C.secondary or C.outlineDim,scale)
  end
  for _,dot in ipairs(g.dots) do
    local color=dot[3]>=red and C.red or dot[3]>=warning and C.amber
      or dot[3]<0.45 and C.green or C.amber
    local active=fraction>0 and dot[3]<=fraction
    if active and (state.rpmRedline or state.rpmWarning) then color=warningInk(state,settings,C) end
    local center=p(dot[1],dot[2])
    local halo=active and Light.halo(color,L.segment)
    if halo then ui.drawCircleFilled(center,15*scale,halo,32) end
    ui.drawCircleFilled(center,12*scale,active and Light.color(color,L.segment) or Theme.withAlpha(color,0.18),32)
    ui.drawCircle(center,12*scale,active and Light.color(color,L.segment) or Theme.withAlpha(color,0.45),32,scale)
  end
  -- The reference's fixed twelve-o'clock chevron sits between the upper dots.
  ui.pathClear()
  ui.pathLineTo(p(r[1]-11,r[2]-257))
  ui.pathLineTo(p(r[1]+11,r[2]-257))
  ui.pathLineTo(p(r[1],r[2]-229))
  ui.pathFillConvex(Light.color(C.primary,L.icon))
  if layout.haloNumbers then
    local thousands=maximum/1000
    local step=thousands<=10 and 1 or thousands<=20 and 2 or 5
    ui.pushDWriteFont('Consolas;Weight=Bold')
    for v=0,thousands+0.001,step do
      local a=math.rad(r[4]+(r[5]-r[4])*v/thousands)
      Light.text(string.format('%.0f',v),26*scale,
        p(r[1]+194*math.cos(a),r[2]+194*math.sin(a)),C.primary,nil,L.label,scale)
    end
    ui.popDWriteFont()
  end
end

local function auxInk(a,state,C)
  if a.label=='FUEL' then return Readout.fuelColor(a.fraction,state,C,C.amber) end
  return a.recovery and C.green or a.label=='AERO' and C.amber or C.cyan
end
function M.auxiliary(origin,scale,layout,left,fuel,state,C,L)
  local function p(x,y) return origin+vec2(x*scale,y*scale) end
  local function channel(index,a)
    if not a then return end
    local track=layout.edgeAux[index]
    local ink=auxInk(a,state,C)
    local value=a.electric and a.charge~=nil and a.charge or a.fraction
    value=value and U.clamp(math.abs(value),0,1) or nil
    for i=1,18 do
      local span=(track[5]-track[4])/18
      local a1=math.rad(track[4]+(i-0.88)*span)
      local a2=math.rad(track[4]+(i-0.12)*span)
      ui.pathClear()
      ui.pathArcTo(p(track[1],track[2]),track[3]*scale,math.min(a1,a2),math.max(a1,a2),16)
      ui.pathStroke(value and i<=math.floor(value*18+0.5) and Light.color(ink,L.subSegment) or C.inactive,false,8*scale)
    end
    local icon=layout.edgeIcons[index]
    local center=p(icon[1],icon[2])
    local iconInk=Light.color(ink,L.icon)
    if a.electric then
      ui.drawRect(center-vec2(8,5)*scale,center+vec2(8,5)*scale,iconInk,0,nil,1.5*scale)
      ui.drawLine(center+vec2(10,-2)*scale,center+vec2(10,2)*scale,iconInk,2*scale)
    else
      local draw=a.label=='FUEL' and Icons.fuelIcon or a.label=='AERO' and Icons.aeroIcon or Icons.boostIcon
      draw(center,scale*0.75,iconInk)
    end
    local position=layout.edgeReadings[index]
    local reading=a.value:match('[%+%-]?%d+%.?%d*')
    if not reading then
      reading=a.electric and a.charge~=nil and string.format('%.0f',a.charge*100) or Readout.value(a.value)
    end
    if reading then Light.text(reading,12*scale,p(position[1],position[2]),ink,nil,L.label,scale) end
  end
  channel(1,left)
  channel(2,fuel)
end
return M
