local U = require('src/utils')
local M = {}

-- Shared source of the existing GT7 and auxiliary instrument symbols.
local function drawLine(a, b, color, width)
  ui.drawLine(a, b, color, width)
end

local function drawArc(center, radius, first, last, color, width, steps)
  ui.pathClear()
  ui.pathArcTo(center, radius, first, last, steps or 32)
  ui.pathStroke(color, false, width)
end

local function centeredText(value, size, center, color)
  local measured = ui.measureDWriteText(value, size)
  ui.dwriteDrawText(value, size, center - measured / 2, color)
end

-- Shared symbol-only electronics for standalone analog and digital faces.
function M.statusIcon(center,scale,kind,ink)
  local x,y=0,-(kind==1 and 2 or 0)
  local function p(px,py) return center+vec2(px*scale,py*scale) end
  local function line(x1,y1,x2,y2,color,width)
    ui.drawLine(p(x1,y1),p(x2,y2),color,(width or 1)*scale)
  end
  local function arc(cx,cy,r,a,b,color,width)
    ui.pathClear()
    ui.pathArcTo(p(cx,cy),r*scale,math.rad(math.min(a,b)),math.rad(math.max(a,b)),32)
    ui.pathStroke(color,false,(width or 1)*scale)
  end
  local function circle(cx,cy,r,color,filled,width)
    if filled then ui.drawCircleFilled(p(cx,cy),r*scale,color,32)
    else ui.drawCircle(p(cx,cy),r*scale,color,32,(width or 1)*scale) end
  end
  local function poly(points,color,filled,width)
    ui.pathClear()
    for _,v in ipairs(points) do ui.pathLineTo(p(v[1],v[2])) end
    if filled then ui.pathFillConvex(color) else ui.pathStroke(color,true,(width or 1)*scale) end
  end
  if kind==1 then
    -- Car and two skid trails for traction control.
    poly({{x-9,y-1},{x-7,y-10},{x+7,y-10},{x+9,y-1},{x+9,y+5},{x-9,y+5}},ink,false,1.8)
    line(x-6,y-5,x+6,y-5,ink,1.5)
    for _,side in ipairs({-1,1}) do
      line(x+side*10,y-2,x+side*10,y+3,ink,2.5)
      line(x+side*5,y+8,x+side*9,y+11,ink,1.8)
      line(x+side*9,y+11,x+side*5,y+14,ink,1.8)
    end
  elseif kind==2 then
    -- Brake rotor between the conventional brake-warning brackets.
    circle(x,y,9,ink,false,1.8)
    circle(x,y,2.5,ink,true)
    arc(x,y,15,140,220,ink,2)
    arc(x,y,15,-40,40,ink,2)
    for i=0,3 do
      local a=math.rad(45+i*90)
      line(x+5*math.cos(a),y+5*math.sin(a),x+8*math.cos(a),y+8*math.sin(a),ink,1.5)
    end
  elseif kind==3 then
    arc(x-10,y,8,-90,90,ink,2)
    line(x-10,y-8,x-10,y+8,ink,2)
    for j=-1,1 do line(x+2,y+j*4,x+10,y+j*5,ink,2) end
  else
    -- Speed-limiter telltale for the pit limiter.
    arc(x,y+4,12,-180,0,ink,2)
    line(x-12,y+4,x-12,y+7,ink,2)
    line(x+12,y+4,x+12,y+7,ink,2)
    for i=-1,1 do
      local a=math.rad(-90+i*60)
      line(x+8*math.cos(a),y+4+8*math.sin(a),x+12*math.cos(a),y+4+12*math.sin(a),ink,1.5)
    end
    line(x,y+4,x+6,y-5,ink,2)
    circle(x,y+4,2,ink,true)
  end
end

function M.fuelIcon(center, scale, color, spread)
  local extra = 2 * (spread or 0)
  local function p(x, y) return center + vec2(x * scale, y * scale) end
  local function line(x1, y1, x2, y2)
    ui.drawLine(p(x1, y1), p(x2, y2), color, (1.7 + extra) * scale)
  end
  ui.drawRect(p(-7, -11), p(5, 9), color, 1 * scale, nil, (1.7 + extra) * scale)
  ui.drawRect(p(-4, -8), p(2, -2), color, 0, nil, (1.2 + extra) * scale)
  line(-9, 10, 7, 10); line(5, -5, 10, -1); line(10, -1, 10, 8)
  line(10, 8, 13, 8); line(13, 8, 13, -4); line(13, -4, 9, -9)
  line(9, -9, 7, -9)
end

function M.boostIcon(center, scale, color, spread)
  local extra = 2 * (spread or 0)
  local function p(x, y) return center + vec2(x * scale, y * scale) end
  ui.drawCircle(center, 9 * scale, color, 24, (1.7 + extra) * scale)
  ui.drawCircle(center, 3 * scale, color, 16, (1 + extra) * scale)
  for i = 0, 4 do
    local a = i * math.pi * 2 / 5
    ui.drawLine(U.polar(center, 3 * scale, a), U.polar(center, 7 * scale, a + 0.55), color, (1.2 + extra) * scale)
  end
  ui.drawLine(p(1, -9), p(12, -9), color, (1.7 + extra) * scale)
  ui.drawLine(p(12, -9), p(12, -14), color, (1.7 + extra) * scale)
  ui.drawLine(p(8, -14), p(14, -14), color, (1.7 + extra) * scale)
end

function M.aeroIcon(center, scale, color, spread)
  local extra = 2 * (spread or 0)
  local function p(x, y) return center + vec2(x * scale, y * scale) end
  local width = (1.7 + extra) * scale
  ui.drawLine(p(-12, 3), p(12, 3), color, width)
  ui.drawLine(p(-12, 3), p(-9, -3), color, width)
  ui.drawLine(p(12, 3), p(9, -3), color, width)
  ui.drawLine(p(-7, 0), p(7, 0), color, (1.2 + extra) * scale)
  ui.drawLine(p(0, 3), p(0, 10), color, width)
  ui.drawLine(p(-4, 10), p(4, 10), color, width)
end

function M.brakeIcon(center, scale, color)
  ui.drawCircle(center, 12 * scale, color, 24, 2 * scale)
  drawArc(center, 17 * scale, math.rad(120), math.rad(240), color, 2 * scale, 12)
  drawArc(center, 17 * scale, math.rad(-60), math.rad(60), color, 2 * scale, 12)
  centeredText('!', 15 * scale, center, color)
end

function M.lightIcon(center, scale, color)
  ui.drawRectFilled(center + vec2(-12 * scale, -8 * scale), center + vec2(-4 * scale, 8 * scale), color)
  for i = -1, 1 do
    drawLine(center + vec2(1 * scale, i * 5 * scale), center + vec2(16 * scale, i * 8 * scale), color, 2 * scale)
  end
end

function M.engineIcon(center, scale, color)
  -- This icon uses screen-space lines to stay crisp at small HUD scales.
  drawLine(center + vec2(-14 * scale, -8 * scale), center + vec2(10 * scale, -8 * scale), color, 2 * scale)
  drawLine(center + vec2(10 * scale, -8 * scale), center + vec2(15 * scale, -2 * scale), color, 2 * scale)
  drawLine(center + vec2(15 * scale, -2 * scale), center + vec2(15 * scale, 9 * scale), color, 2 * scale)
  drawLine(center + vec2(15 * scale, 9 * scale), center + vec2(-14 * scale, 9 * scale), color, 2 * scale)
  drawLine(center + vec2(-14 * scale, 9 * scale), center + vec2(-14 * scale, -8 * scale), color, 2 * scale)
  drawLine(center + vec2(-8 * scale, -8 * scale), center + vec2(-8 * scale, -13 * scale), color, 2 * scale)
  drawLine(center + vec2(-8 * scale, -13 * scale), center + vec2(2 * scale, -13 * scale), color, 2 * scale)
end

function M.batteryIcon(center, scale, color)
  local function p(x, y) return center + vec2(x * scale, y * scale) end
  ui.drawRect(p(-11, -6), p(8, 6), color, scale, nil, 1.5 * scale)
  ui.drawLine(p(10, -3), p(10, 3), color, 2 * scale)
  ui.drawLine(p(-7, 0), p(-1, 0), color, 1.3 * scale)
  ui.drawLine(p(-4, -3), p(-4, 3), color, 1.3 * scale)
  ui.drawLine(p(2, 0), p(5, 0), color, 1.3 * scale)
end

return M
