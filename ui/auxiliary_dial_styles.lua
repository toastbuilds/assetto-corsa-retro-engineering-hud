-- Shared drawing vocabulary for the GT7 auxiliary gauges. Telemetry, scale,
-- warnings and readouts stay with the owning fuel/boost/hybrid instrument.
local Light=require('ui/instrument_illumination')
local Theme=require('src/theme')
local U=require('src/utils')
local M={}

-- The owner supplies the channel's range and warning thresholds. Styles only
-- choose how those same states are displayed.
function M.channel(channel,C,L)
  local kind,zero=channel.kind,channel.zero or 0
  local linear=kind=='fuel' or kind=='battery'
  local warning=channel.warning or 0.9
  local function warningZone(f)
    return linear and f<=warning or not linear and kind~='power' and f>=warning
  end
  local function lit(color) return Light.color(color,L.subSegment) end
  channel.active=function(f)
    if channel.value==nil then return false end
    if linear then return f<=channel.value end
    if channel.value==zero then return false end
    return f>=math.min(zero,channel.value) and f<=math.max(zero,channel.value)
  end
  channel.color=function(f,active)
    if not channel.available then return C.outlineDim end
    if not active then
      return warningZone(f) and (kind=='aero' and C.amberDim or C.redDim) or C.inactive
    end
    if channel.lowInk then return channel.lowInk end
    if warningZone(f) then return kind=='aero' and C.amber or C.red end
    if kind=='power' then return f<zero and C.green or C.cyan end
    if kind=='boost' then return f<zero and C.cyan or C.primary end
    return kind=='battery' and C.green or C.cyan
  end
  channel.spectrum=function(f)
    if channel.lowInk then return channel.lowInk end
    if warningZone(f) then return kind=='aero' and C.amber or C.red end
    if kind=='power' then
      return f<zero and Light.mix(C.green,lit(C.primary),f/math.max(zero,0.01))
        or Light.mix(lit(C.primary),lit(C.cyan),(f-zero)/math.max(1-zero,0.01))
    end
    if linear then
      local progress=U.clamp((f-warning)/math.max(1-warning,0.01),0,1)
      return kind=='battery' and Light.mix(C.green,lit(C.primary),progress*0.4)
        or Light.mix(lit(C.cyan),C.green,progress)
    end
    if kind=='boost' and f<zero then return lit(C.cyan) end
    return Light.mix(lit(kind=='aero' and C.cyan or C.primary),lit(C.amber),
      U.clamp((f-zero)/math.max(warning-zero,0.01),0,1))
  end
  return channel
end

function M.draw(style,center,scale,g,channel,C,L)
  local span=g.last-g.first
  local function p(radius,angle)
    return U.polar(center,radius*scale,angle)
  end
  local function arc(radius,first,last,width,ink)
    ui.pathClear()
    ui.pathArcTo(center,radius*scale,math.min(first,last),math.max(first,last),3)
    ui.pathStroke(ink,false,width*scale)
  end
  if style=='spectrum' then
    for i=1,48 do
      local f=(i-0.5)/48
      local ink=channel.available and Light.color(channel.spectrum(f),L.subSegment) or C.outlineDim
      local a=g.first+span*(i-1)/48
      local b=g.first+span*i/48+span*0.0002
      arc(g.radius,a,b,g.width,ink)
    end
    if channel.available and channel.marker and channel.value~=nil then
      local a=g.first+span*U.clamp(channel.value,0,1)
      local radial,tangent=vec2(math.cos(a),math.sin(a)),vec2(-math.sin(a),math.cos(a))
      local outer=g.radius+g.width/2+1
      local inner=g.radius-g.width/2-1
      local tip=center+radial*(inner*scale)
      local base=center+radial*(outer*scale)
      ui.pathClear()
      ui.pathLineTo(base-tangent*(3*scale))
      ui.pathLineTo(base+tangent*(3*scale))
      ui.pathLineTo(tip)
      ui.pathFillConvex(Theme.withAlpha(C.panel,1))
    end
    return
  end

  local count=style=='jewel' and g.count+2 or g.count
  local baseRadius=math.min(g.width*(style=='jewel' and 0.5 or 0.42),
    math.abs(span)*g.radius/(count+1)*(style=='jewel' and 0.35 or 0.3))
  for i=0,count do
    local f=i/count
    local active=channel.available and channel.active(f)
    local ink=channel.color(f,active)
    local a=g.first+span*f
    local radius=style=='jewel' and i%2~=0 and baseRadius*0.58 or baseRadius
    ui.drawCircleFilled(p(g.radius,a),radius*scale,
      Light.color(ink,active and L.subSegment or L.printedWarning),24)
  end
  if style=='jewel' then
    local outer=g.radius-g.width/2-2
    for i=0,g.count*4 do
      local a=g.first+span*i/(g.count*4)
      Light.line(p(outer-(i%4==0 and 3 or 1.6),a),p(outer,a),
        channel.available and C.secondary or C.outlineDim,0.65*scale,L.inner,scale)
    end
  end
end

return M
