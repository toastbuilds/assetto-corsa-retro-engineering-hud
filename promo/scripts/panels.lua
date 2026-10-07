-- Export-only CSP adapter. Every widget below calls the current product Lua.
-- Geometry comes from nativeTrack (installed Daytona AI line, validated by
-- export-ui.py). The data and track label remain openly demonstrative.
local M = {}

function M.installRecorder()
  local calls, path, alpha, offset, window = {}, {}, 1, vec2(), vec2(620, 620)
  local alphaStack, fontStack, clipDepth = {}, {}, 0
  local pushFont, popFont = ui.pushDWriteFont, ui.popDWriteFont
  local pushAlpha, popAlpha = ui.pushStyleVarAlpha, ui.popStyleVar
  local function color(value)
    return rgbm(value.r, value.g, value.b, (value.mult or 1) * alpha)
  end
  local function record(kind, values)
    values.kind = kind
    if values.color then values.color = color(values.color) end
    calls[#calls + 1] = values
  end
  ui.windowWidth = function() return window.x end
  ui.windowHeight = function() return window.y end
  ui.windowSize = function() return window end
  ui.windowPos = function() return offset end
  ui.getMainViewportSize = function() return vec2(1920, 1080) end
  ui.getCursor = function() return vec2() end
  ui.mouseLocalPos = function() return vec2(-1, -1) end
  ui.mouseClicked = function() return false end
  ui.mouseDown = function() return false end
  ui.MouseButton = {Left=0, Right=1}
  ui.pushDWriteFont = function(font)
    fontStack[#fontStack+1] = font
    if pushFont then pushFont(font) end
  end
  ui.popDWriteFont = function()
    assert(#fontStack > 0, 'Font stack underflow')
    table.remove(fontStack)
    if popFont then popFont() end
  end
  ui.measureDWriteText = function(value, size)
    return nativeMeasureText(tostring(value), size, fontStack[#fontStack] or 'Consolas;Weight=Regular')
  end
  ui.pushStyleVarAlpha = function(value)
    alphaStack[#alphaStack+1] = alpha; alpha = alpha * value
    if pushAlpha then pushAlpha(value) end
  end
  ui.popStyleVar = function(count)
    for _=1,count or 1 do
      assert(#alphaStack > 0, 'Alpha stack underflow')
      alpha = table.remove(alphaStack)
    end
    if popAlpha then popAlpha(count or 1) end
  end
  ui.pushClipRect = function(first, last)
    clipDepth = clipDepth + 1
    record('clip_push', {a=first+offset, b=last+offset})
  end
  ui.popClipRect = function()
    assert(clipDepth > 0, 'Clip stack underflow')
    clipDepth=clipDepth-1; record('clip_pop', {})
  end
  ui.dwriteDrawText = function(value, size, position, paint)
    record('text', {text=tostring(value), size=size, a=position+offset, color=paint,
      font=fontStack[#fontStack] or 'Consolas;Weight=Regular'})
  end
  ui.drawLine = function(first, last, paint, thickness)
    record('line', {a=first+offset, b=last+offset, color=paint, thickness=thickness})
  end
  ui.drawCircle = function(center, radius, paint, segments, thickness)
    record('circle', {a=center+offset, radius=radius, color=paint, thickness=thickness, segments=segments})
  end
  ui.drawCircleFilled = function(center, radius, paint, segments)
    record('circle_fill', {a=center+offset, radius=radius, color=paint, segments=segments})
  end
  ui.drawRect = function(first, last, paint, rounding, flags, thickness)
    assert(flags == nil or flags == 0, 'Selective rounded corners need an explicit replay opcode')
    record('rect', {a=first+offset, b=last+offset, color=paint, rounding=rounding, thickness=thickness})
  end
  ui.drawRectFilled = function(first, last, paint, rounding, flags)
    assert(flags == nil or flags == 0, 'Selective rounded corners need an explicit replay opcode')
    record('rect_fill', {a=first+offset, b=last+offset, color=paint, rounding=rounding})
  end
  ui.drawRectFilledMultiColor = function(first, last, tl, tr, br, bl)
    record('rect_multicolor', {a=first+offset, b=last+offset,
      colors={color(tl), color(tr), color(br), color(bl)}})
  end
  ui.drawTriangleFilled = function(a, b, c, paint)
    record('polygon', {points={a+offset,b+offset,c+offset}, color=paint})
  end
  ui.pathClear = function() path = {} end
  ui.pathLineTo = function(position) path[#path+1]={kind='line',a=position+offset} end
  ui.pathArcTo = function(center, radius, startAngle, endAngle, segments)
    path[#path+1]={kind='arc',a=center+offset,radius=radius,startAngle=startAngle,
      endAngle=endAngle,segments=segments}
  end
  local function recordPath(paint, closed, thickness, fill)
    if #path == 1 and path[1].kind == 'arc' and not fill then
      local arc=path[1]
      record('arc', {a=arc.a,radius=arc.radius,startAngle=arc.startAngle,
        endAngle=arc.endAngle,segments=arc.segments,color=paint,thickness=thickness})
      return
    end
    local points, compound = {}, false
    for _,segment in ipairs(path) do
      if segment.kind == 'arc' then compound=true end
      points[#points+1]=segment.a
    end
    if compound then
      record('compound_path', {commands=path,color=paint,closed=closed,fill=fill,thickness=thickness})
    else
      -- CSP accepts either winding; the old GT7 mock only asserted one winding.
      record(fill and 'polygon' or 'path', {points=points,color=paint,closed=closed,thickness=thickness})
    end
  end
  ui.pathFillConvex = function(paint) recordPath(paint, true, 1, true) end
  ui.pathStroke = function(paint, closed, thickness) recordPath(paint, closed, thickness, false) end
  local function balanced()
    assert(#alphaStack==0 and #fontStack==0 and clipDepth==0, 'Unbalanced native drawing state')
  end
  return {
    count=function() return #calls end,
    reset=function(width,height) balanced(); calls,path={},{}; offset,window=vec2(),vec2(width,height) end,
    calls=function() balanced(); return calls end,
    window=function(x,y,width,height) offset,window=vec2(x,y),vec2(width,height) end
  }
end

function M.new(recorder)
  local now, stores, grid = 0, {}, {}
  function rgb(r,g,b) return {r=r,g=g,b=b,clone=function(v) return rgb(v.r,v.g,v.b) end} end
  function vec3(x,y,z) return {x=x,y=y,z=z} end
  __dirname='modules/relative'
  ac.storage=setmetatable({}, {__call=function(_,defaults,prefix)
    prefix=prefix or ''; stores[prefix]=stores[prefix] or {}
    for key,value in pairs(defaults) do if stores[prefix][key]==nil then stores[prefix][key]=value end end
    return stores[prefix]
  end})
  ac.INIConfig={load=function() return {get=function() return '' end} end}
  ac.log=function() end
  ac.error=function(message) error(message) end
  ac.SessionType={Race=3,Practice=1,Qualify=2}
  ac.FlagType={None=0,Caution=2,FasterCar=12}
  ac.WeatherType={Clear=1}
  local sim={currentSessionIndex=0,trackLengthM=nativeTrack.length,raceFlagType=0,
    ambientTemperature=23,roadTemperature=29,rainIntensity=0,
    weatherConditions={currentType=1,upcomingType=1},lapSplits={[0]=0,[1]=0.33,[2]=0.66}}
  local session={type=ac.SessionType.Race,laps=15,isTimedRace=false}
  local function circuit(spline)
    spline=spline%1
    local points=nativeTrack.points
    local low,high=1,#points
    while low+1<high do
      local middle=math.floor((low+high)/2)
      if points[middle].spline<=spline then low=middle else high=middle end
    end
    local a,b=points[low],points[high]
    local p=(spline-a.spline)/math.max(0.0000001,b.spline-a.spline)
    return vec3(a.x+(b.x-a.x)*p,0,a.z+(b.z-a.z)*p)
  end
  ac.getSim=function() return sim end
  ac.getSession=function() return session end
  ac.getTrackFullID=function() return 'launch_trailer_demo_'..nativeTrack.id end
  ac.getTrackName=function() return 'DEMO CIRCUIT' end
  ac.trackCoordinateToWorld=function(coordinate) return circuit(coordinate.z) end
  ac.getCar=function(index) return grid[index+1] end
  ac.iterateCars=function() return ipairs(grid) end
  ac.getCarID=function() return 'retro_ui_demo_gt3' end
  ui.time=function() return now end
  local names={'YOU','A. VEGA','M. COSTA','J. REED','S. MARTIN','L. MOREAU','D. SILVA',
    'T. MASON','N. COLE','R. WEST','K. STONE','F. KING','E. LAKE','V. CROSS','B. HILL','C. VALE'}
  for index=0,15 do
    local name,number=names[index+1],20+index
    grid[index+1]={index=index,isConnected=true,isActive=true,physicsAvailable=true,
      isLapValid=true,isLastLapValid=true,clutch=1,tyreCompound='M',
      id=function() return 'demo_gt3_'..index end,
      name=function() return 'DEMO GT3' end,
      driverName=function() return name end,driverNumber=function() return number end}
  end
  local Global=require('src/general_settings')
  Global.values.theme,Global.values.opacity,Global.values.backgroundOpacity='dark',1,0.72
  local Relative=require('modules/relative/main')
  stores['retro-ui.relative.'].uiScale=1.3; stores['retro-ui.relative.'].fontSize=22
  local Leader=require('modules/leaderboard/src/leaderboard_data')
  local LeaderUI=require('modules/leaderboard/ui/leaderboard')
  local LeaderSettings=require('modules/leaderboard/src/settings').values
  LeaderSettings.hudScale=1.2
  local Intervals=require('modules/leaderboard/src/intervals')
  local Fuel=require('modules/leaderboard/src/fuel')
  local leaderState,intervalState,fuelState=Leader.new(),Intervals.new(),Fuel.new()
  local Map=require('modules/map/main')
  local MapSettings=require('modules/map/src/settings').values
  MapSettings.backgroundMode,MapSettings.markerScale='surface',1.65
  local Timer=require('modules/timer/src/display')
  local Laps=require('modules/laps/src/display')
  local Delta=require('modules/delta/src/display')
  local Telemetry=require('modules/telemetry/src/telemetry')
  local History=require('modules/telemetry/src/history')
  local TelemetryUI=require('modules/telemetry/ui/telemetry_panel')
  local TelemetrySettings=require('modules/telemetry/src/settings').values
  TelemetrySettings.hudScale,TelemetrySettings.graphWidth,TelemetrySettings.layout=1.2,750,'left'
  TelemetrySettings.showLegend=true
  local telemetryState,history=Telemetry.new(),History.new()
  local timingVisual={palette=require('modules/timing/src/theme').get('dark'),instrumentOpacity=1,animateLapChanges=true}
  local telemetryVisual={palette=require('modules/telemetry/src/theme').get('dark'),instrumentOpacity=1}
  local leaderVisual=require('modules/leaderboard/src/theme_sync').visual()
  local f,leaderSnapshot
  local deltaSettings={scale=1.5,showDetails=true,position=1}
  local relativeSettings=stores['retro-ui.relative.']
  local function step(moment,dt)
    f=demoFrame; now=moment
    sim.sessionTimeLeft=f.sessionTimeLeft*1000
    sim.raceFlagType=f.raceFlagType; sim.raceFlagCause=1
    sim.ambientTemperature,sim.roadTemperature,sim.rainIntensity=f.ambientTemperature,f.roadTemperature,f.rainIntensity
    local rivalRank=f.position>1 and f.position-1 or 2
    local remaining={}
    for rank=1,16 do if rank~=f.position and rank~=rivalRank then remaining[#remaining+1]=rank end end
    for _,car in ipairs(grid) do
      car.racePosition=car.index==0 and f.position or car.index==1 and rivalRank or remaining[car.index-1]
      local separation=(f.position-car.racePosition)*0.023
      if car.index==1 then separation=f.gap/f.referenceLapTimeMs*1000 end
      local progress=f.lapProgress+separation
      car.splinePosition=progress%1; car.position=circuit(car.splinePosition)
      car.lapCount=f.lap-1+math.floor(progress)
      car.lapTimeMs=car.index==0 and f.currentLapTimeMs or car.splinePosition*f.referenceLapTimeMs
      car.currentSector=car.index==0 and f.currentSector or math.min(2,math.floor(car.splinePosition*3))
      car.previousLapTimeMs=f.previousLapTimeMs+car.index*70
      car.bestLapTimeMs=f.bestLapTimeMs+car.index*70
      car.gas,car.brake,car.clutch,car.steer=f.gas,f.brake,f.clutch,f.steer
      car.steerLock,car.ffbFinal,car.speedKmh=f.steerLock,f.ffbFinal,f.speedKmh
      car.fuel,car.maxFuel=f.fuel,f.maxFuel
      car.isLapValid,car.isInPit=f.isLapValid,f.isInPit
      car.look=vec3(math.sin(f.steer*math.pi/180),0,math.cos(f.steer*math.pi/180))
      car.wheelsOutside=f.wheelsOutside or 0
    end
    Relative.update(dt)
    leaderSnapshot=Leader.update(leaderState,LeaderSettings)
    Intervals.update(intervalState,leaderSnapshot,LeaderSettings)
    leaderSnapshot.fuel=Fuel.update(fuelState,leaderSnapshot,LeaderSettings)
    Telemetry.update(telemetryState,dt); History.update(history,dt,telemetryState)
  end
  local sizes={relative={820,620},board={1300,620},circuit={640,640},
    delta_native={1100,400},timer_native={1200,185},laps_native={700,300},inputs_native={1150,290}}
  local function draw(component)
    local size=assert(sizes[component],'Unknown native panel: '..tostring(component))
    recorder.reset(size[1],size[2]); ui.pushClipRect(vec2(),vec2(size[1],size[2]))
    if component=='relative' then Relative.windowMain()
    elseif component=='board' then LeaderUI.draw(leaderSnapshot,LeaderSettings,leaderVisual)
    elseif component=='circuit' then Map.windowMain()
    elseif component=='delta_native' then
      Delta.draw({timeDelta=f.delta*1000,speedDelta=f.speedDelta or 0,sector=f.currentSector,
        sectorCount=3,lapNumber=f.lap,currentLapTime=f.currentLapTimeMs,
        modeLabel=f.deltaMode or 'SESSION LAP',modeShortLabel=f.deltaMode or 'SESSION LAP',
        notification1=f.notification1,notification2=f.notification2,
        personalSector={time=f.personalSectorTimeMs or 44150},sessionSector={time=f.sessionSectorTimeMs or 43990}},
        deltaSettings,timingVisual)
    elseif component=='timer_native' then
      Timer.draw({currentLapTime=f.currentLapTimeMs,result=f.result,invalid=not f.isLapValid,
        finalLap=f.finalLap,inPits=f.isInPit},{scale=2,backgroundOpacity=.72},timingVisual)
    elseif component=='laps_native' then
      Laps.draw({current={number=f.lap,progress=f.lapProgress,inPits=f.isInPit},
        transitionStartedAt=f.transitionStartedAt,
        history=f.lapHistory or {{number=7,time=f.previousLapTimeMs,status='slower'},
          {number=6,time=132910,status='slower'},{number=5,time=133146,status='slower'}}},
        {scale=1.6,rows=4},timingVisual)
    elseif component=='inputs_native' then TelemetryUI.draw(telemetryState,history,TelemetrySettings,telemetryVisual) end
    ui.popClipRect(); return recorder.calls()
  end
  return {step=step,draw=draw,sizes=sizes,telemetry=telemetryState,history=history,
    session=session,sim=sim,grid=grid,relativeSettings=relativeSettings,leaderSettings=LeaderSettings,
    deltaSettings=deltaSettings,
    theme=function(theme)
      Global.values.theme=theme
      timingVisual.palette=require('modules/timing/src/theme').get(theme)
      telemetryVisual.palette=require('modules/telemetry/src/theme').get(theme)
      leaderVisual.palette=require('modules/leaderboard/src/theme').get(theme)
    end}
end
return M
