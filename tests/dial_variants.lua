local h=dofile('tests/gt7_layouts.lua')
local Layouts=require('src/dial_variants')
local Settings=require('src/settings')
local Renderer=require('ui/analog_variants')
local state=h.state
local function contains(calls,value)
  for _,call in ipairs(calls) do if call.kind=='text' and call.text==value then return true end end
  return false
end
assert(Settings.current().analogVariant=='original','upgrades retain the Original dial')
for _,retired in ipairs({'stack','twin'}) do
  Settings.values.analogVariant=retired
  assert(Settings.current().analogVariant=='original','retired selection falls back to Original')
  assert(Layouts.get(retired)==nil,'retired variants are not renderable')
end
Settings.values.analogVariant='unknown'
assert(Settings.current().analogVariant=='original','unknown variants normalize safely')
for _,choice in ipairs(Layouts.choices) do
  Settings.values.analogVariant=choice.value
  assert(Settings.current().analogVariant==choice.value,'variant must persist')
end
Settings.values.analogVariant='original'
state.available=true
state.rpmDisplayLimiter,state.rpmGaugeLimiter=8000,8000
state.speedText,state.speedUnit,state.gearText,state.rpmText='139','km/h','R','5200'
state.analogNeedleNormalized,state.rpmGaugeNormalized=0.65,0.65
state.turboAvailable,state.turboBoost,state.turboDisplayMax=true,0.7,1.5
state.tcLevel,state.absLevel,state.tcSupported,state.absSupported=0,3,true,true
state.lightsAvailable,state.headlights=true,true
state.throttle,state.brake,state.clutch=0.7,0.3,0.2
state.steeringAngle,state.steeringInput=18,0.2
state.clock,state.raceFlagType,state.handbrake=0.05,2,1
state.rpmWarning,state.rpmRedline=true,true
state.tcActive,state.absActive=true,true
state.hazardLights,state.indicatorPhase=true,true
local scenarios=0
for id,layout in pairs(Layouts.layouts) do
  for _,theme in ipairs({'dark','light'}) do
    for _,window in ipairs({{340,340},{460,460},{900,650}}) do
      for _,limiter in ipairs({6000,8000,16000}) do
        state.rpmDisplayLimiter,state.rpmGaugeLimiter=limiter-250,limiter
        for _,mode in ipairs({'auto','turbo','fuel','electric','off'}) do
          local calls=h.drawDial({analogVariant=id,theme=theme,analogAuxiliaryMode=mode,
            hudScale=window[1]==340 and 0.55 or 1.15},state,window)
          assert(contains(calls,'139') and contains(calls,'R'))
          assert(contains(calls,'5200') == (not layout.hideRpmValue))
          if layout.iconStatuses then
            assert(not contains(calls,'TC') and not contains(calls,'ABS'),'symbol-only states omit captions')
          else assert(contains(calls,'0') and contains(calls,'3'),'independent TC/ABS levels include zero') end
          local images=0
          for _,call in ipairs(calls) do
            if call.kind=='image' then
              images=images+1
              local file=assert(io.open(call.image,'rb'),'missing shell: '..call.image)
              file:close()
              assert(call.image:find('_'..theme..'_',1,true),'shell theme must match palette')
            end
          end
          assert(images==(layout.nativeFace and 0 or layout.frontLayer==false and 1 or 2),'native faces and shell layers must match the selected variant')
          scenarios=scenarios+1
        end
      end
    end
  end
  local calls=h.drawDial({analogVariant=id,analogAuxiliaryMode='off',showSteering=false,
    showClutch=false,showLights=false,showTcAbsLevels=false,backgroundOpacity=0},state)
  assert(not contains(calls,'CL') and not contains(calls,'+18°'),'visibility switches apply')
  for _,call in ipairs(calls) do
    if call.kind=='image' then assert(call.color.mult==0,'background opacity can hide shell completely') end
  end
  calls=h.drawDial({analogVariant=id,analogAuxiliaryMode='turbo'},state)
  assert(not contains(calls,'TURBO'))
  if id=='concentric' then assert(not contains(calls,'0.70'))
  else assert(contains(calls,layout.haloRpm and '0.70' or '0.70 BAR')) end
  local flagDrawn,rpmAlert=false,false
  local palette=require('src/theme').get('dark')
  for _,call in ipairs(calls) do
    flagDrawn=flagDrawn or (call.kind=='rect_fill' and call.color==palette.flagYellow)
    rpmAlert=rpmAlert or (call.kind=='text' and call.text=='5200' and call.color==palette.red)
  end
  assert(flagDrawn and (rpmAlert or layout.hideRpmValue) and contains(calls,'!'),'flag, RPM and handbrake coexist')
  for _,style in ipairs(require('src/instrument_config').needleOrder) do
    h.drawDial({analogVariant=id,analogNeedleStyle=style},state)
  end
  state.hybrid={charge=0.84,powerKw=-38,needle=-0.55,maximumKw=150,recoveryKw=100}
  calls=h.drawDial({analogVariant=id,analogAuxiliaryMode='auto'},state)
  assert(not contains(calls,'ERS') and (id=='concentric' or contains(calls,layout.haloRpm and '-38' or '-38 kW')),'hybrid auto mode includes recovery')
  state.hybrid={charge=nil,delivery=0.4,needle=0.4}
  calls=h.drawDial({analogVariant=id,analogAuxiliaryMode='electric'},state)
  assert(id=='concentric' or contains(calls,layout.haloRpm and '40' or '40%'),'delivery fallback must not fabricate kW')
  state.hybrid={charge=0.4,batteryRecovery=true,chargeRecoveryRate=0.3,needle=-0.2}
  calls=h.drawDial({analogVariant=id,analogAuxiliaryMode='electric'},state)
  assert(id=='concentric' or contains(calls,layout.haloRpm and '-0.3' or '-0.3%/s'),'battery recovery retains its units')
  state.hybrid=nil
  state.turboAvailable=false
  calls=h.drawDial({analogVariant=id,analogAuxiliaryMode='turbo'},state)
  assert(not contains(calls,'AERO') and Renderer.auxiliary(state,'turbo').label=='AERO','atmospheric cars retain the AERO channel without its caption')
  state.turboAvailable=true
  state.available=false
  calls=h.drawDial({analogVariant=id,analogAuxiliaryMode='turbo'},state)
  assert(contains(calls,'N/A') == (id~='concentric'),'disconnected telemetry must not show measured boost')
  state.available=true
end
assert(Renderer.auxiliary(state,'off')==nil)
state.fuel,state.maxFuel,state.fuelNormalized=2,50,0.04
assert(Renderer.auxiliary(state,'fuel').fraction==0.04)
state.fuel=nil
assert(Renderer.auxiliary(state,'fuel').value=='N/A')
local calls=h.drawDial({instrumentMode='digital',analogVariant='spoke'},state)
for _,call in ipairs(calls) do assert(call.kind~='image','analog selection does not change digital') end
calls=h.drawDial({analogVariant='unknown'},state)
for _,call in ipairs(calls) do assert(call.kind~='image','unknown variant renders Original') end
print('Analog variants: '..scenarios..' layout scenarios, themes, channels, visibility, migration and auxiliary fallbacks passed')

-- Reproduce CSP's app-root __dirname (which the old mock omitted), as well as
-- a module-directory context. Both must resolve real shell files on disk.
local previousDir,previousExists=__dirname,io.fileExists
for _,directory in ipairs({'.','./ui'}) do
  __dirname=directory
  io.fileExists=function(path)
    local f=io.open(path,'rb'); if not f then return false end; f:close(); return true
  end
  package.loaded['ui/analog_variants']=nil
  package.loaded['ui/dial']=nil
  local resolved=h.drawDial({analogVariant='shelf'},state)
  local images=0
  for _,call in ipairs(resolved) do
    if call.kind=='image' then
      assert(io.fileExists(call.image),'CSP directory context must resolve shell: '..call.image)
      images=images+1
    end
  end
  assert(images==2)
end
__dirname,io.fileExists=previousDir,previousExists
print('Analog shell lookup: app-root and module-root CSP contexts resolve existing assets')
