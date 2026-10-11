package.path = './?.lua;./?/init.lua;' .. package.path

local Vec = {}
Vec.__index = Vec
function vec2(x, y) return setmetatable({x=x or 0, y=y or 0}, Vec) end
function Vec.__add(a,b) return vec2(a.x+b.x,a.y+b.y) end
function Vec.__sub(a,b) return vec2(a.x-b.x,a.y-b.y) end
function Vec.__mul(a,b)
  if type(a)=='number' then return vec2(a*b.x,a*b.y) end
  return vec2(a.x*b,a.y*b)
end
function Vec.__div(a,b) return vec2(a.x/b,a.y/b) end
function rgbm(r,g,b,m) return {r=r,g=g,b=b,mult=m} end
function rgb(r,g,b)
  return {r=r,g=g,b=b,clone=function(self) return rgb(self.r,self.g,self.b) end}
end
__dirname = '.'

local stores = {
  ['']={layoutVersion=9, sharedUnitsVersion=1, theme='light', speedUnit='mph', temperatureUnit='F',
    opacity=0.3, backgroundOpacity=0.2, rpmWarningFraction=0.7, analogNeedleStyle='c03', hudScale=0.65},
  ['retro-ui.gt7.']={version=1, compositionVersion=1, opacity=0.4, backgroundOpacity=0.3,
    rpmWarningFraction=0.8, gt7SpeedNeedleStyle='d05', gt7RpmNeedleStyle='a02', hudScale=0.8},
  ['retro-ui.relative.']={opacity=0.2, instrumentOpacity=0.3, backgroundOpacity=0.4},
  ['retro-ui.delta.']={opacity=0.3},
  ['retro-ui.timer.']={scale=1},
  ['retro-ui.laps.']={scale=1,rows=10},
  ['retro-ui.leaderboard.']={opacity=0.4, fallbackTheme='light'},
  ['retro-ui.telemetry.']={opacity=0.2, theme='light'},
  ['retro-ui.map.']={dotOpacity=0.4, surfaceOpacity=0.9}
}
local errors, files, writes = {}, {}, {}
local function noop() end
ac = {
  storage=setmetatable({}, {__call=function(_,defaults,prefix)
    prefix=prefix or ''
    local saved=stores[prefix] or {}; stores[prefix]=saved
    for key,value in pairs(defaults) do if saved[key]==nil then saved[key]=value end end
    return setmetatable({}, {__index=saved,__newindex=saved,__pairs=function() return next,{},nil end})
  end}),
  INIConfig={load=function() return {get=function() return '' end} end},
  FolderID={ACDocuments=1, ContentCars=2},
  getFolder=function() return 'Documents' end,
  getSim=function() return {trackLengthM=1000, raceFlagType=0} end,
  getCar=function() return nil end,
  getTrackFullID=function() return 'test' end,
  getTrackName=function() return 'Test' end,
  getCarID=function() return 'test_car' end,
  iterateCars=function() return ipairs({}) end,
  broadcastSharedEvent=noop, log=noop,
  error=function(message) errors[#errors+1]=message end
}
io.load=function(path)
  if files[path] then return files[path] end
  if path:match('classes.default.ini$') then return '[EXACT]\nfactory=GT3' end
  if path:match('classes.ini$') then return '[EXACT]\ncustom=GT4' end
end
io.save=function(path,contents) files[path]=contents; writes[#writes+1]=path; return true end
io.dirExists=function() return true end
io.exists=function(path) return files[path]~=nil end

local pending, items, drawing, alphaStack = {}, {}, {}, {}
local alpha, width = 1, 800
local function item(label) items[label]=alpha end
local function press(label)
  local value=pending[label]; pending[label]=nil; return value
end
local function primitive(kind,color,text)
  drawing[#drawing+1]={kind=kind,color=color,alpha=(color and color.mult or 1)*alpha,text=text}
end
ui = {
  ComboFlags={None=0}, ColorPickerFlags={PickerHueBar=0}, MouseButton={Left=0,Right=1},
  windowWidth=function() return width end, windowHeight=function() return 600 end,
  windowSize=function() return vec2(width,600) end, windowPos=function() return vec2() end,
  availableSpace=function() return vec2(640,600) end, availableSpaceX=function() return 640 end,
  getCursor=function() return vec2() end, time=function() return 10 end,
  getMainViewportSize=function() return vec2(1920,1080) end,
  mouseLocalPos=function() return vec2(-100,-100) end, mouseDown=function() return false end,
  mouseClicked=function() return false end,
  header=item, text=item, textWrapped=item, separator=noop, sameLine=noop,
  button=function(label) item(label); return press(label)==true end,
  checkbox=function(label) item(label); return press(label)==true end,
  slider=function(label,value)
    item(label); local nextValue=press(label); return nextValue or value,nextValue~=nil
  end,
  combo=function(label,value)
    item(label); local nextValue=press(label); return nextValue or value,nextValue~=nil
  end,
  colorButton=function(label) item(label) end,
  childWindow=function(_,_,draw) draw() end,
  setNextWindowSize=noop, setNextWindowPosition=noop,
  pushStyleVarAlpha=function(value) alphaStack[#alphaStack+1]=alpha; alpha=alpha*value end,
  popStyleVar=function(count) for _=1,count or 1 do alpha=table.remove(alphaStack) end end,
  pushDWriteFont=noop,popDWriteFont=noop,pushClipRect=noop,popClipRect=noop,
  measureDWriteText=function(value,size) return vec2(#tostring(value)*size*0.5,size) end,
  dwriteDrawText=function(text,_,_,color) primitive('text',color,text) end,
  drawLine=function(_,_,color) primitive('line',color) end,
  drawRect=function(_,_,color) primitive('outline',color) end,
  drawRectFilled=function(_,_,color) primitive('background',color) end,
  drawImage=function(_,_,_,color) primitive('image',color) end,
  drawCircle=function(_,_,color) primitive('outline',color) end,
  drawCircleFilled=function(_,_,color) primitive('background',color) end,
  drawTriangleFilled=function(_,_,_,color) primitive('triangle',color) end,
  drawRectFilledMultiColor=noop,pathClear=noop,pathLineTo=noop,pathArcTo=noop,
  pathFillConvex=function(color) primitive('background',color) end,
  pathStroke=function(color) primitive('outline',color) end
}

script={}
require('app')
local General=require('src/general_settings')
local Dial=require('src/settings')
local GT7=require('src/gt7_settings')
local Condition=require('src/condition_settings')
local Config=require('src/instrument_config')
local function near(a,b) return math.abs(a-b)<0.000001 end
local function frame(draw)
  items,drawing={},{}
  draw()
  assert(alpha==1 and #alphaStack==0,'all paths must balance opacity styles')
  assert(#errors==0,table.concat(errors,'\n'))
  return items,drawing
end

-- Migrate only once, preserving prior shared units and local personalization.
assert(General.values.theme=='light' and General.values.speedUnit=='mph' and General.values.temperatureUnit=='F')
assert(General.values.opacity==1 and General.values.backgroundOpacity==0.72)
assert(General.values.rpmWarningFraction==0.86 and General.values.rpmRedlineFraction==0.96)
assert(Dial.values.hudScale==0.65 and Dial.values.analogNeedleStyle=='c03' and GT7.values.hudScale==0.8)
assert(Dial.current().analogVariant=='original' and Dial.values.layoutVersion==10,
  'variant migration retains existing appearance and defaults to Original')
General.values.opacity=0.5
package.loaded['src/general_settings']=nil
local reloaded=require('src/general_settings')
reloaded.initialize({theme='dark',speedUnit='km/h',temperatureUnit='C'})
assert(reloaded.values.opacity==0.5 and reloaded.values.theme=='light','reload must retain migrated settings')
General.values.opacity=1
General.values.version=0
General.initialize({theme='light',speedUnit='km/h',temperatureUnit='C',sharedUnitsVersion=0},'mph','F','C')
assert(General.values.speedUnit=='mph' and General.values.temperatureUnit=='F','legacy separate units must migrate')

-- All twelve settings pages start with only Basics expanded.
local pages={
  {'general',General.draw},{'dial',Dial.draw},{'gt7',GT7.draw},{'condition',Condition.draw},
  {'relative',require('modules/relative/main').windowSettings},
  {'delta',require('modules/delta/src/settings').draw},
  {'timer',require('modules/timer/src/settings').draw},
  {'laps',require('modules/laps/src/settings').draw},
  {'leaderboard',require('modules/leaderboard/src/settings').draw},
  {'telemetry',require('modules/telemetry/src/settings').draw},
  {'map',require('modules/map/src/settings').draw},
  {'notices',require('modules/notices/main').windowSettings}
}
for _,page in ipairs(pages) do
  local visible=frame(page[2])
  assert(visible['v  Basics##'..page[1]..'.basics'],'Basics must start open: '..page[1])
  assert(visible['>  Personalization##'..page[1]..'.personalization'],'Personalization must start closed')
  if page[1]~='general' then
    assert(not visible['Content opacity'] and (page[1]=='timer' or not visible['Background opacity']),
      'global controls must appear once; Timer retains its authored local plate opacity')
    assert(not visible['Blink redline alert'] and not visible['RPM warning threshold'])
  end
end

-- Variants are local analog selections and remain stored while digital is shown.
Dial.values.instrumentMode='analog'
pending['##dial.variant']=4
local variantItems=frame(Dial.draw)
assert(variantItems['##dial.variant'] and Dial.current().analogVariant=='spoke')
Dial.values.instrumentMode='digital'
variantItems=frame(Dial.draw)
assert(not variantItems['##dial.variant'] and Dial.current().analogVariant=='spoke')
pending['##dial.digitalVariant']=5
variantItems=frame(Dial.draw)
assert(variantItems['##dial.digitalVariant'] and Dial.current().digitalVariant=='orbit')
Dial.values.instrumentMode='analog'
frame(Dial.draw)
assert(Dial.current().digitalVariant=='orbit' and Dial.current().analogVariant=='spoke')
pending['Reset appearance##dial']=true
frame(Dial.draw)
assert(Dial.current().analogVariant=='original')

-- Slider paths preserve selection while hidden and clamp/round to real catalog entries.
pending['>  Personalization##dial.personalization']=true
Dial.values.instrumentMode='analog'
pending['##dial.needleStyle']=24
frame(Dial.draw)
assert(Dial.values.analogNeedleStyle=='d06')
Dial.values.instrumentMode='digital'
pending['##dial.needleStyle']=1
local visible=frame(Dial.draw)
assert(not visible['##dial.needleStyle'] and Dial.values.analogNeedleStyle=='d06')
Dial.values.instrumentMode='analog'
frame(Dial.draw)
assert(Dial.values.analogNeedleStyle=='a01')
pending['##dial.needleStyle']=7.6
frame(Dial.draw)
assert(Dial.values.analogNeedleStyle==Config.needleOrder[8])
pending['##dial.needleStyle']=-10
frame(Dial.draw)
assert(Dial.values.analogNeedleStyle=='a01')
pending['##dial.needleStyle']=100
frame(Dial.draw)
assert(Dial.values.analogNeedleStyle=='d06')

pending['>  Personalization##gt7.personalization']=true
GT7.values.gt7SpeedNeedleMode,GT7.values.gt7RpmNeedleMode='analog','digital'
pending['##gt7.speedNeedleStyle']=4
visible=frame(GT7.draw)
assert(GT7.values.gt7SpeedNeedleStyle=='a04' and GT7.values.gt7RpmNeedleStyle=='a02')
assert(not visible['##gt7.rpmNeedleStyle'])
GT7.values.gt7RpmNeedleMode='analog'
pending['##gt7.rpmNeedleStyle']=23
frame(GT7.draw)
assert(GT7.values.gt7RpmNeedleStyle=='d05' and Dial.values.analogNeedleStyle=='d06')
local previousScale=GT7.values.hudScale
pending['Modern##gt7.preset.modern']=true
frame(GT7.draw)
assert(GT7.currentPreset()=='modern' and GT7.values.hudScale==previousScale)
assert(GT7.values.gt7SpeedNeedleStyle=='a04' and GT7.values.gt7RpmNeedleMode=='analog')
GT7.values.gt7GearStyle='classic'
assert(GT7.currentPreset()=='custom' and GT7.values.gt7Layout=='modern')
pending['Modern##gt7.preset.modern']=true
visible=frame(GT7.draw)
assert(GT7.currentPreset()=='modern' and visible['Composition: Modern'])

General.values.opacity,General.values.backgroundOpacity=0.5,0.36
General.values.rpmWarningFraction,General.values.rpmRedlineFraction=0.75,0.9
General.values.animateShiftAlert=false
for _,resolved in ipairs({Dial.current(),GT7.current(),Condition.current()}) do
  assert(resolved.opacity==0.5 and resolved.backgroundOpacity==0.36)
end
assert(GT7.current().rpmWarningFraction==0.75 and Dial.current().animateShiftAlert==false)
for _,page in ipairs(pages) do
  if page[1]~='general' and page[1]~='relative' and page[1]~='leaderboard' then
    pending['Reset appearance##'..page[1]]=true
    frame(page[2])
    assert(General.values.opacity==0.5 and General.values.rpmWarningFraction==0.75,
      'local appearance resets must retain globals')
    pending['Reset all##'..page[1]]=true
    frame(page[2])
    pending['Confirm reset##'..page[1]]=true
    frame(page[2])
    assert(General.values.opacity==0.5 and General.values.rpmWarningFraction==0.75,'local resets must retain globals')
  end
end
for _,id in ipairs({'relative','leaderboard'}) do
  local draw= id=='relative' and pages[5][2] or pages[9][2]
  local count=#writes
  pending['Reset all##'..id]=true;frame(draw)
  assert(#writes==count,'class reset requires confirmation')
  pending['Confirm reset##'..id]=true;frame(draw)
  assert(#writes==count+2 and writes[count+1]:find('Class Backups'),'class reset must save backup first')
  assert(General.values.opacity==0.5)
end

-- Draw actual window callbacks: a 50% global opacity must halve every foreground
-- primitive once, even when obsolete local opacity fields hold other values.
-- Prime the shared app runtime with timing telemetry before testing Timer's
-- real window callback. The app's update also seeds the current Laps row.
local savedGetCar, savedIterateCars = ac.getCar, ac.iterateCars
local timingCar = { index=0, lapCount=0, currentSector=0, splinePosition=0.1,
  lapTimeMs=12345, isLapValid=true, isActive=true, isConnected=true, wheels={} }
ac.getCar=function(index) return index==0 and timingCar or nil end
ac.iterateCars=function() return ipairs({timingCar}) end
script.update(0)
ac.getCar, ac.iterateCars = savedGetCar, savedIterateCars
pending['>  Personalization##notices.personalization']=true
frame(pages[12][2])
pending['Preview Blue flag##notices.blue']=true
frame(pages[12][2])
local callbacks={'windowMain','gt7Main','conditionMain','relativeMain','deltaMain','timerMain','lapsMain','leaderboardMain','telemetryMain','mapMain','noticesMain'}
local function assertGlobalOpacity(callback)
  General.values.opacity=1
  local _,full=frame(script[callback])
  General.values.opacity=0.5
  local _,half=frame(script[callback])
  assert(#full>0 and #full==#half,'window must draw stable geometry: '..callback)
  for i,call in ipairs(full) do assert(near(half[i].alpha,call.alpha*0.5),'opacity applied twice: '..callback) end
end
for _,callback in ipairs(callbacks) do assertGlobalOpacity(callback) end
Dial.values.instrumentMode='analog'
assertGlobalOpacity('windowMain')
for id in pairs(require('src/dial_variants').layouts) do
  Dial.values.analogVariant=id
  assertGlobalOpacity('windowMain')
end
Dial.values.analogVariant='original'
for _,speedMode in ipairs({'analog','digital'}) do
  for _,rpmMode in ipairs({'analog','digital'}) do
    GT7.values.gt7SpeedNeedleMode,GT7.values.gt7RpmNeedleMode=speedMode,rpmMode
    assertGlobalOpacity('gt7Main')
  end
end
General.values.opacity=0
local visible=frame(script.settingsMain)
assert(visible['Content opacity']==1,'settings must remain usable when HUD is invisible')

-- Material intensities remain distinct; the global background control reaches zero.
local palette=require('src/theme').get('dark')
local original=palette.panel.mult
local faded=General.palette(palette,0.36)
assert(near(faded.panel.mult,original*0.5) and faded.primary==palette.primary)
assert(near(General.color(faded.panel,0.9).mult,0.45) and palette.panel.mult==original)
assert(General.palette(palette,0.36)==faded,'settled colors should reuse their palette')
assert(General.color(General.palette(palette,0).panel,0.9).mult==0)
assert(near(General.background(0.12,0.72),0.12) and near(General.background(0.45,0.72),0.45))
General.values.opacity=1
General.values.backgroundOpacity=0
for _,callback in ipairs(callbacks) do
  local _,drawn=frame(script[callback])
  local foreground=0
  for _,call in ipairs(drawn) do
    if call.kind~='background' and call.alpha>0 then foreground=foreground+1 end
    if call.kind=='background' and call.color then
      for _,role in ipairs({'void','surface','panel','panelRaised','debug'}) do
        local base=palette[role]
        if base and near(call.color.r,base.r) and near(call.color.g,base.g) and near(call.color.b,base.b) then
          assert(call.alpha==0,'background floor persists: '..callback..'/'..role)
        end
      end
    end
  end
  assert(foreground>0,'transparent backgrounds must retain readings: '..callback)
end
pending['Reset all##general']=true;frame(General.draw)
assert(General.values.backgroundOpacity==0,'global reset requires confirmation')
pending['Confirm reset##general']=true;frame(General.draw)
assert(General.values.opacity==1 and General.values.backgroundOpacity==0.72 and General.values.theme=='dark')
assert(General.values.rpmWarningFraction==0.86 and General.values.animateShiftAlert)

pending['  GT7##nav-gt7']=true
frame(script.settingsMain)
assert(stores['retro-ui.settings-ui.'].selectedPage=='gt7')
General.values.opacity=0.65
package.loaded.app=nil
require('app')
assert(General.values.opacity==0.65 and stores['retro-ui.settings-ui.'].selectedPage=='gt7',
  'app reload must preserve globals and navigation')

-- Every local option remains reachable through the new hierarchy.
for _,page in ipairs(pages) do
  local function expand()
    for _=1,6 do
      local visible=frame(page[2])
      for label in pairs(visible) do if label:sub(1,3)=='>  ' then pending[label]=true end end
    end
  end
  expand()
  local visible=frame(page[2])
  assert(not visible['Instrument preview (temporary)'],'sample telemetry must be removed')
  assert(visible['Reset all##'..page[1]],'reset must remain reachable')
end

print('Settings: twelve pages, migration, sliders, presets, resets and shared opacity consumers passed')
