-- Palette-aware counterparts of the fixed-color shell layers. Coordinates
-- match tools/build-dial-shells.py; the original palette keeps its PNG art.
local Theme = require('src/theme')
local M = {}

local function painter(c)
  local C, scale = c.colors, c.scale
  local function point(x,y) return c.origin + vec2(x*scale,y*scale) end
  local function circle(x,y,r,ink,width)
    ui.drawCircle(point(x,y),r*scale,ink,64,(width or 1)*scale)
  end
  local function disc(x,y,r,ink) ui.drawCircleFilled(point(x,y),r*scale,ink,64) end
  local function panel(points)
    ui.pathClear()
    for _,p in ipairs(points) do ui.pathLineTo(point(p[1],p[2])) end
    ui.pathFillConvex(C.surface)
    ui.pathClear()
    for _,p in ipairs(points) do ui.pathLineTo(point(p[1],p[2])) end
    ui.pathStroke(C.metal,true,2*scale)
  end
  local function screen(x,y,w,h,gear)
    local a,b=point(x-w/2,y-h/2),point(x+w/2,y+h/2)
    ui.drawRectFilled(a,b,C.panel,13*scale)
    ui.drawRect(a,b,gear and C.amber or C.outlineDim,13*scale,nil,scale)
  end
  return circle,disc,panel,screen
end

function M.back(c)
  local l,C=c.layout,c.colors
  local circle,disc=painter(c)
  if l.id=='shelf' then
    for _,r in ipairs({165,160,83}) do circle(l.rpm[1],l.rpm[2],r,C.outlineDim) end
  elseif l.id=='fan' or l.id=='spoke' then
    local x,y,r=l.rpm[1],l.rpm[2],l.rpm[3]-5
    for i=0,8 do
      local a=math.rad(-183+i*186/9)
      local b=math.rad(-183+(i+1)*186/9)
      -- A thick arc supplies the annular sector in one draw call.
      ui.pathClear()
      ui.pathArcTo(c.origin+vec2(x*c.scale,y*c.scale),(r+96)/2*c.scale,a,b,16)
      ui.pathStroke(Theme.withAlpha(C.outlineDim,i%2==0 and .08 or .16),false,(r-96)*c.scale)
    end
    if l.id=='spoke' then
      disc(310,300,60,C.metal)
      disc(310,300,49,C.panel)
      circle(310,300,58,C.metal,2)
      circle(310,300,47,C.outlineDim)
    end
  end
end

function M.front(c)
  local l,C=c.layout,c.colors
  local circle,disc,panel,screen=painter(c)
  if l.id=='shelf' then
    panel({{48,368},{572,368},{549,428},{517,480},{103,480},{71,428}})
    screen(l.speed[1],l.speed[2]+10,158,104)
  elseif l.id=='fan' then
    panel({{409,350},{565,351},{552,439},{522,483},{415,479},{397,405}})
  elseif l.id=='concentric' then
    local x,y,r=l.core[1],l.core[2],l.core[3]
    disc(x,y,r,C.panel)
    circle(x,y,r,C.outline,3)
    circle(x,y,r-9,C.outlineDim)
  elseif l.id=='spoke' then
    panel({{81,418},{199,432},{225,512},{177,546},{122,523}})
    panel({{421,432},{539,418},{498,523},{443,546},{395,512}})
    panel({{273,520},{347,520},{365,579},{255,579}})
  end
  if l.id~='spoke' then
    screen(l.gear[1],l.gear[2],l.id=='fan' and 75 or 90,l.id=='fan' and 65 or 86,true)
  end
  if l.id=='shelf' and l.auxStyle=='screen' then
    screen(l.aux[1],l.aux[2],l.aux[3]+18,l.aux[4]+10)
  end
end

return M
