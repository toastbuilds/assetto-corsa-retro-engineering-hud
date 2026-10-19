-- Complete auxiliary faces. Owners supply semantic channels, text and icons;
-- profiles only select geometry. Shared by GT7 fuel, boost, aero and hybrid.
local Profiles = require('src/mini_dial_profiles')
local Light = require('ui/instrument_illumination')
local U = require('src/utils')
local M = {}

function M.draw(id, center, scale, digital, channel, C, L, content)
  local f = Profiles.get(id)
  if not f then return end
  center=center+vec2(0,f.offsetY*scale)
  scale=scale*f.sizeScale
  if f.digital==false then digital=0 end
  content = content or {}
  local r, cy = f.radius, f.y
  local function p(x,y) return center+vec2(x*scale,y*scale) end
  local function polar(radius,a) return p(radius*math.cos(a),cy+radius*math.sin(a)) end
  local function line(a,b,ink,width,style)
    Light.line(a,b,ink,width*scale,style or L.inner,scale)
  end
  local function arc(radius,a,b,width,ink,style)
    ui.pathClear()
    ui.pathArcTo(p(0,cy),radius*scale,math.min(a,b),math.max(a,b),32)
    ui.pathStroke(Light.color(ink,style or L.inner),false,width*scale)
  end
  local function circle(radius,width,ink)
    ui.drawCircle(p(0,cy),radius*scale,Light.color(ink,L.inner),48,width*scale)
  end
  local function text(value,size,x,y,ink)
    if value then Light.text(value,size*scale,p(x,y),ink,nil,L.label,scale) end
  end
  local available = channel.available and channel.value~=nil
  local value = U.clamp(channel.value or 0,0,1)
  local fuel=channel.kind=='fuel'
  local fuelLow=available and fuel and value<(channel.warning or 0.15)
  local fuelCaution=available and fuel and value<(channel.warning or 0.15)*2
  local fuelInk=channel.lowInk or (fuelLow and C.red or fuelCaution and C.amber or C.cyan)
  local tint = available and (fuel and fuelCaution and fuelInk or channel.lowInk or C.primary) or C.outlineDim
  local needleValue=U.clamp(channel.needleValue or value,0,1)
  local zero=(fuel or channel.kind=='battery') and 0 or channel.zero or 0
  local analogFirst=Profiles.angle(f,math.min(zero,needleValue))
  local analogLast=Profiles.angle(f,math.max(zero,needleValue))
  local function segmentInk(v,active)
    if not active then return available and C.inactive or C.outlineDim end
    if fuel then return fuelInk end
    return channel.color(v,true)
  end
  local function analogInk(v)
    if fuel then return fuelCaution and fuelInk or C.primary end
    return channel.color(v,true)
  end
  local function analogActive(v)
    return available and needleValue~=zero and v>=math.min(zero,needleValue) and v<=math.max(zero,needleValue)
  end
  local function analogFill(radius,a,b,width,v)
    a,b=math.max(a,analogFirst),math.min(b,analogLast)
    if available and b>a then arc(radius,a,b,width,analogInk(v),L.subSegment) end
  end
  local function cellAngles(i)
    local first,last=f.edges[i],f.edges[i+1]
    local gap=math.min(math.rad(2),(last-first)*0.12)
    return first+gap,last-gap
  end
  local terminalAngle=Profiles.angle(f,0.85)
  local function digitalCell(radius,a,b,width,active,ink)
    local style=active and L.subSegment or L.inner
    if not available or b<=terminalAngle then
      arc(radius,a,b,width,ink,style)
      return
    end
    -- A wide ornament cell can cross 85%. Split its ink, not its geometry or
    -- value step, so the terminal zone remains exactly the last 15%.
    if a<terminalAngle then arc(radius,a,terminalAngle,width,ink,style) end
    arc(radius,math.max(a,terminalAngle),b,width,active and C.red or C.redDim,style)
  end
  local function printedCells(radius,width,ink,persistent,fuelBackground)
    if not persistent and digital>=1 then return end
    ui.pushStyleVarAlpha(persistent and 1 or 1-digital)
    for i=1,f.segmentCount do
      local a,b=cellAngles(i)
      local warningStart=fuelBackground=='cell' and f.edges[f.segmentCount] or terminalAngle
      if available and fuel and fuelBackground and b>warningStart then
        if a<warningStart then arc(radius,a,warningStart,width,ink) end
        arc(radius,math.max(a,warningStart),b,width,fuelLow and fuelInk or C.redDim)
      else arc(radius,a,b,width,ink) end
    end
    ui.popStyleVar(1)
  end
  local function analogCells(radius,width,persistent)
    printedCells(radius,width,available and C.inactive or C.outlineDim,persistent)
    if digital>=1 then return end
    ui.pushStyleVarAlpha(1-digital)
    for i=1,f.segmentCount do
      local a,b=cellAngles(i)
      analogFill(radius,a,b,width,(i-0.5)/f.segmentCount)
    end
    ui.popStyleVar(1)
  end
  -- Leave the surrounding primary face transparent; only the miniature face
  -- receives a panel, matching the original instrument's footprint.
  if not f.half then
    ui.drawCircleFilled(p(0,cy),r*scale,C.panel,48)
    circle(r,2.6,C.metal)
    if f.rim==2 then circle(r-4,1,C.primary) end
  end
  if f.accent then
    arc(r-6,math.rad(300),math.rad(410),3,fuelLow and (channel.alertInk or fuelInk) or C.primary)
  end
  if f.inner then arc(r-8,math.rad(135),math.rad(405),1.4,C.primary) end
  if f.wheel then
    arc(r-9,f.first,f.last,1.6,C.primary)
    arc(r-20,f.first,f.last,1.3,C.primary)
    for _,a in ipairs(f.edges) do
      line(polar(r-20,a),polar(r-9,a),C.primary,1.2)
    end
  end
  if f.cells then
    if fuel then printedCells(r-10.5,4.8,available and C.inactive or C.outlineDim,false,'cell') end
    arc(r-7,f.first,f.last,1,C.primary); arc(r-14,f.first,f.last,1.4,C.primary)
    for _,a in ipairs(f.edges) do
      line(polar(r-14,a),polar(r-7,a),C.primary,1.5)
    end
  end
  if f.inward then analogCells(r-9,10,false) end
  if f.sun then circle(r-17,1.4,C.primary) end
  if f.dashed then
    printedCells(r-8,3,C.primary,false,'terminal')
  end
  if f.arch or f.lattice then
    arc(r-6,math.pi,math.pi*2,1.8,C.primary)
    arc(r-12,math.pi,math.pi*2,1.1,C.primary)
    if f.arch then arc(r-17,math.pi,math.pi*2,1.1,C.primary) end
    line(polar(r-12,math.pi),polar(r-6,math.pi),C.primary,1.2)
    line(polar(r-12,math.pi*2),polar(r-6,math.pi*2),C.primary,1.2)
  end
  if f.shelf then
    arc(r-9,math.rad(155),math.rad(385),1.5,C.primary)
    local shelfY=(r-9)*math.sin(f.first)
    local shelfX=math.abs((r-9)*math.cos(f.first))
    line(p(-shelfX,cy+shelfY),p(shelfX,cy+shelfY),C.primary,1.5)
  end
  if f.sweep then
    local a,b=math.rad(190),math.rad(360)
    arc(r-5,a,b,10,available and C.inactive or C.outlineDim)
    analogFill(r-5,a,b,10,value)
  end
  if f.blocks then
    analogCells(r-9,f.broad and 10 or 6,true)
  end
  if f.base then
    ui.pathClear()
    ui.pathLineTo(p(0,cy))
    for i=0,16 do ui.pathLineTo(polar(13,math.pi+math.pi*i/16)) end
    ui.pathFillConvex(Light.color(C.outline,L.inner))
    line(p(-r+6,cy),p(r-6,cy),C.primary,1.4)
  end
  local tickRadius = f.sun and r-12 or f.shelf and r-12 or f.inward and r-5 or f.half and r or r-7
  for i=0,f.ticks do
    if f.ticks>0 then
      local v=i/f.ticks
      local a=Profiles.angle(f,v)
      local major=i%4==0
      local outer=f.lattice and r-6 or tickRadius
      local inner=f.lattice and r-12 or outer-(major and 7 or 3.5)
      if f.sun then inner,outer=r-17,r-11 end
      if f.inward then inner,outer=r-19,r-15 end
      local ink=available and ((f.inward or major) and C.primary or C.secondary) or C.outlineDim
      if f.inward and digital<1 then
        local activeInk=analogActive(v) and analogInk(v) or available and C.inactive or C.outlineDim
        ink=digital<=0 and activeInk or Light.mix(activeInk,ink,digital)
      end
      if f.shelf and not major then ui.pushStyleVarAlpha(1-digital) end
      line(polar(inner,a),polar(outer,a),ink,major and 1.6 or 0.9)
      if f.shelf and not major then ui.popStyleVar(1) end
    end
  end
  -- Same angular calibration in both modes. Cross-fade the moving indicators
  -- using the owner's existing mode transition, never switching at halfway.
  local rr=f.segmentRadius
  local count=f.segmentCount
  if digital>0 then
    ui.pushStyleVarAlpha(digital)
    for i=1,count do
      local v=(i-0.5)/count
      local a,b=cellAngles(i)
      local active=available and channel.active(v)
      digitalCell(rr,a,b,f.segmentWidth,active,segmentInk(v,active))
    end
    ui.popStyleVar(1)
  end
  if digital<1 then
    ui.pushStyleVarAlpha(1-digital)
    if available then
      local a=Profiles.angle(f,U.clamp(channel.needleValue or value,0,1))
      local dx,dy=math.cos(a),math.sin(a)
      local function hand(x,y) return p(x*dx-y*dy,cy+x*dy+y*dx) end
      local length=f.needleLength
      local ink=channel.lowInk or segmentInk(value,true)
      local width=(f.needle=='spear' or f.needle=='diamond' or f.needle=='cutout') and 3 or 1.5
      if f.needle=='line' then
        line(hand(f.hub=='open' and 4 or 0,0),hand(length,0),ink,1.7,L.subNeedle)
      else
        local back=f.needle=='cutout' and -5 or 0
        ui.pathClear()
        ui.pathLineTo(hand(back,-width)); ui.pathLineTo(hand(length,0)); ui.pathLineTo(hand(back,width))
        ui.pathFillConvex(Light.color(ink,L.subNeedle))
      end
      if f.tail then
        if f.counterweight=='semiarc' then
          line(hand(-8,0),hand(-4,0),ink,1.6,L.subNeedle)
          ui.pathClear()
          for j=0,16 do
            local t=-math.pi/2+math.pi*j/16
            ui.pathLineTo(hand(-12+4*math.cos(t),4*math.sin(t)))
          end
          ui.pathStroke(Light.color(ink,L.subNeedle),false,1.6*scale)
        else
          line(hand(-12,0),hand(-4,0),ink,1.6,L.subNeedle)
        end
        if f.needle=='diamond' then
          ui.pathClear()
          for _,v in ipairs({{-10,-3},{-5,0},{-10,3},{-15,0}}) do ui.pathLineTo(hand(v[1],v[2])) end
          ui.pathFillConvex(Light.color(ink,L.subNeedle))
        end
      end
      if f.hub=='open' or f.needle=='cutout' then
        ui.drawCircleFilled(p(0,cy),3.6*scale,C.panel,20)
        ui.drawCircle(p(0,cy),3.6*scale,Light.color(ink,L.subNeedle),20,1.4*scale)
      else
        ui.drawCircleFilled(p(0,cy),(f.needle=='club' and 4 or 3)*scale,Light.color(ink,L.subNeedle),20)
      end
    end
    ui.popStyleVar(1)
  end
  if channel.kind=='boost' or channel.kind=='power' then
    local a=Profiles.angle(f,channel.zero or 0)
    line(polar(rr-5,a),polar(rr+5,a),C.amber,1,L.inner)
    if channel.kind=='boost' then
      local q=polar(rr-12,a)
      Light.text('0',7*scale,q,C.secondary,nil,L.label,scale)
    end
  end
  if content.battery then
    local battery=content.battery
    local br=r+4
    for i=1,24 do
      local a=Profiles.angle(f,(i-0.87)/24)
      local b=Profiles.angle(f,(i-0.13)/24)
      local active=battery.available and battery.active((i-0.5)/24)
      local ink=not battery.available and C.outlineDim or not active and C.inactive
        or battery.lowInk or C.green
      -- Battery has its own availability; missing power must not suppress its
      -- independent charge reading or terminal color.
      if digital>0 and battery.available then
        ui.pushStyleVarAlpha(1-digital)
        arc(br,a,b,2,ink,active and L.subSegment or L.inner)
        ui.popStyleVar(1)
        ui.pushStyleVarAlpha(digital)
        local style=active and L.subSegment or L.inner
        if a<terminalAngle then arc(br,a,math.min(b,terminalAngle),2,ink,style) end
        if b>terminalAngle then
          arc(br,math.max(a,terminalAngle),b,2,active and C.red or C.redDim,style)
        end
        ui.popStyleVar(1)
      else arc(br,a,b,2,ink,active and L.subSegment or L.inner) end
    end
  end
  if f.plaque then
    ui.drawRectFilled(p(-13,cy+14),p(13,cy+21),Light.color(C.outline,L.inner))
  end
  local caption=not content.icon and content.label or not available and 'N/A' or nil
  if content.icon and available then
    -- Fuel, boost and aero share the centered icon-only presentation.
    content.icon(p(0,f.half and 16 or cy+33),scale*0.5,tint)
  end
  text(content.value,10,0,f.half and 16 or cy+22,tint)
  if caption then
    text(caption,10,0,f.half and 31 or cy+36,
      available and (channel.lowInk or C.secondary) or C.outlineDim)
  end
  -- Side labels leave the lower rim free and remain outside the bezel.
  local function endpoint(value,x)
    if not value then return end
    local position=p(x,f.half and 12 or cy+17)
    local size=11*scale
    local half=ui.measureDWriteText(value,size)/2
    ui.drawRectFilled(position-half-vec2(scale,scale*0.5),
      position+half+vec2(scale,scale*0.5),C.panel)
    Light.text(value,size,position,C.primary,nil,L.label,scale)
  end
  local labelWidth=math.max(ui.measureDWriteText(content.left or '',11*scale).x,
    ui.measureDWriteText(content.right or '',11*scale).x)/scale
  local labelX=f.half and 61 or math.max(r+8,r+3+labelWidth/2)
  endpoint(content.left,-labelX)
  endpoint(content.right,labelX)
end

return M
