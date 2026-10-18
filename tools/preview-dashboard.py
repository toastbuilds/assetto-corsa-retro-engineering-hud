"""Render the Dash styles at their default and minimum window sizes."""
import importlib.util
from pathlib import Path

from lupa.lua52 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('instrument_preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)

BOOTSTRAP = r"""
package.path = './?.lua;./?/init.lua;' .. package.path
local calls, path, alpha, font = {}, {}, 1, 'Consolas;Weight=Regular'
local function copyColor(color)
  return {r=color.r,g=color.g,b=color.b,mult=(color.mult or 1)*alpha}
end
local Vec={}
Vec.__index=Vec
Vec.__add=function(a,b) return vec2(a.x+b.x,a.y+b.y) end
Vec.__sub=function(a,b) return vec2(a.x-b.x,a.y-b.y) end
Vec.__mul=function(a,b)
  if type(a)=='number' then return vec2(a*b.x,a*b.y) end
  return vec2(a.x*b,a.y*b)
end
Vec.__div=function(a,b) return vec2(a.x/b,a.y/b) end
local function point(x,y) return setmetatable({x=x,y=y},Vec) end
local function add(kind,a,b,color,extra)
  local item={kind=kind,a=a and point(a.x,a.y) or nil,color=copyColor(color),font=font}
  if b then item.b=point(b.x,b.y) end
  if extra then for key,value in pairs(extra) do item[key]=value end end
  calls[#calls+1]=item
end
function vec2(x,y) return point(x,y) end
function rgbm(r,g,b,mult) return {r=r,g=g,b=b,mult=mult} end
function setSize(w,h) DASH_WIDTH,DASH_HEIGHT=w,h end
function takeCalls() local value=calls; calls={}; return value end
local alphaStack={}
ui={
 windowWidth=function() return DASH_WIDTH end, windowHeight=function() return DASH_HEIGHT end,
 measureDWriteText=function(value,size) return vec2(#tostring(value)*size*0.55,size) end,
 dwriteDrawText=function(value,size,position,color)
   add('text',position,nil,color,{text=tostring(value),size=size})
 end,
 pushStyleVarAlpha=function(value) alphaStack[#alphaStack+1]=alpha; alpha=alpha*value end,
 popStyleVar=function(count) for _=1,count do alpha=table.remove(alphaStack) end end,
 pushDWriteFont=function(value) font=value end, popDWriteFont=function() font='Consolas;Weight=Regular' end,
 drawLine=function(a,b,color,thickness) add('line',a,b,color,{thickness=thickness}) end,
 drawRectFilled=function(a,b,color,rounding) add('rect_fill',a,b,color,{rounding=rounding or 0}) end,
 drawRect=function(a,b,color,rounding,segments,thickness)
   add('rect',a,b,color,{rounding=rounding or 0,thickness=thickness or 1})
 end,
 drawCircleFilled=function(center,radius,color)
   add('circle_fill',center,nil,color,{radius=radius,thickness=1})
 end,
 drawCircle=function(center,radius,color,segments,thickness)
   add('circle',center,nil,color,{radius=radius,thickness=thickness or 1})
 end,
 pathClear=function() path={} end,
 pathLineTo=function(value) path[#path+1]=point(value.x,value.y) end,
 pathFillConvex=function(color)
   local points={}; for i,p in ipairs(path) do points[i]=point(p.x,p.y) end
   add('polygon',points[1],nil,color,{points=points,closed=true})
 end,
 pathStroke=function(color,closed,thickness)
   local points={}; for i,p in ipairs(path) do points[i]=point(p.x,p.y) end
   if #points>0 then add('path',points[1],nil,color,{points=points,closed=closed,thickness=thickness}) end
 end,
 pathArcTo=function(center,radius,first,last,segments)
   segments=segments or 32
   for i=0,segments do
     local angle=first+(last-first)*i/segments
     path[#path+1]=point(center.x+math.cos(angle)*radius,center.y+math.sin(angle)*radius)
   end
 end,
}
local stores={}
ac={storage=function(defaults,prefix)
  prefix=prefix or ''
  local value=stores[prefix] or {}; stores[prefix]=value
  for key,item in pairs(defaults) do if value[key]==nil then value[key]=item end end
  return value
end}
"""


def main():
    output = ROOT / 'output/dashboard'
    output.mkdir(parents=True, exist_ok=True)
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(BOOTSTRAP)
    lua.globals().ui.measureDWriteText = lambda value, size: lua.globals().vec2(
        preview.font(size).getlength(str(value)) / preview.FACTOR, size)
    lua.execute("""
      local history = require('src/pedal_history').new()
      for i=1,90 do
        local throttle=0.5+0.48*math.sin(i*0.11)
        local brake=0.35+0.3*math.sin(i*0.08-1)
        require('src/pedal_history').update(history,1/30,throttle,brake)
      end
      DASH_STATE={available=true,speedText='139',speedUnit='km/h',gearText='2',gear=2,
        rpm=6200,rpmDisplayLimiter=8000,rpmGaugeNormalized=0.775,rpmRedlineFraction=0.96,
        fuel=12.4,maxFuel=60,fuelNormalized=12.4/60,turboAvailable=true,turboBoost=2.1,
        turboDisplayMax=2.5,brake=0.38,throttle=0.68,steeringInput=0.2,steeringAngle=108,
        focusedCarIndex=0,pedalHistory=history,steeringAvailable=true,tcSupported=true,tcActive=false,
        absSupported=true,absActive=false,pitLane=false,pitLaneAvailable=true,pitLimiter=true,lightsAvailable=true,
        headlights=true,highBeams=false,engineLifeLeft=1000,engineWarning=false,
        hybrid={charge=0.65}}
      DASH_MAIN=require('modules/dash/main')
      DASH_GENERAL=require('src/general_settings')
    """)
    state = lua.globals().DASH_STATE
    general = lua.globals().DASH_GENERAL
    settings = lua.eval("require('modules/dash/src/settings')")

    def render(style, theme, width, height, name):
        settings['values']['style'] = style
        general['values']['theme'] = theme
        lua.globals().setSize(width, height)
        lua.globals().DASH_MAIN.windowMain(state)
        calls = lua.globals().takeCalls()
        picture = preview.raster(calls, width, height, '#101216' if theme == 'dark' else '#e9e4d9')
        path = output / f'{style}-{theme}-{name}.png'
        picture.save(path)
        print(path)

    for theme in ('dark', 'light'):
        for style in ('rpm-top', 'side-tach'):
            for width, height, size_name in ((1280, 220, 'default'), (900, 160, 'minimum')):
                general['values']['pressureUnit'] = 'psi'
                render(style, theme, width, height, size_name)

    general['values']['pressureUnit'] = 'bar'
    for key,value in dict(turboBoost=0,throttle=0.15,tcActive=True,absActive=True,
            engineWarning=True,fuelNormalized=0.08,fuel=4.8,leftIndicator=True,indicatorPhase=True).items():
        state[key]=value
    state['hybrid']['charge']=0.10
    for style in ('rpm-top','side-tach'):
        for lights in (False,True):
            state['headlights']=lights
            render(style,'dark',1280,220,'vacuum-lights-on' if lights else 'vacuum-lights-off')


if __name__ == '__main__':
    main()
