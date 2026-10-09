local h=dofile('tests/gt7_layouts.lua')
local Layouts=require('src/digital_dial_variants')
local Settings=require('src/settings')
local state=h.state
local function has(calls,value)
  for _,c in ipairs(calls) do if c.kind=='text' and c.text==value then return true end end
  return false
end
assert(#Layouts.choices==6 and Layouts.get('5')==nil)
Settings.values.analogVariant='fan'
Settings.values.digitalVariant='unknown'
assert(Settings.current().digitalVariant=='original')
state.available=true
state.speedText,state.gearText,state.rpmText='139','R','5200'
state.tcLevel,state.absLevel,state.tcActive,state.absActive=0,3,true,true
state.tcSupported,state.absSupported=true,true
state.turboAvailable,state.turboBoost,state.turboDisplayMax=true,0.7,1.5
state.lightsAvailable,state.headlights=true,true
state.hazardLights,state.indicatorPhase=true,true
state.raceFlagType,state.handbrake,state.clock=2,1,0.05
local count=0
for id in pairs(Layouts.layouts) do
  Settings.values.digitalVariant=id
  assert(Settings.current().digitalVariant==id and Settings.current().analogVariant=='fan')
  for _,theme in ipairs({'dark','light'}) do
    for _,size in ipairs({340,620,900}) do
      for _,limiter in ipairs({6000,8000,16000}) do
        state.rpmGaugeLimiter,state.rpmDisplayLimiter=limiter,limiter-200
        for _,fraction in ipairs({0,0.65,1}) do
          state.rpmGaugeNormalized=fraction
          state.rpmWarning,state.rpmRedline=fraction==1,fraction==1
          local calls=h.drawDial({instrumentMode='digital',digitalVariant=id,theme=theme},state,{size,size})
          assert(has(calls,'139') and has(calls,'R') and has(calls,'5200'))
          assert(has(calls,'0') and has(calls,'3') and has(calls,'!'))
          assert(has(calls,'TURBO  0.70 BAR'))
          count=count+1
        end
      end
    end
  end
  local calls=h.drawDial({instrumentMode='digital',digitalVariant=id,
    showClutch=false,showLights=false,showSteering=false,analogAuxiliaryMode='off'},state)
  assert(not has(calls,'CLUTCH') and not has(calls,'LIGHTS') and not has(calls,'TURBO  0.70 BAR'))
  state.hybrid={charge=0.84,powerKw=-38,needle=-0.55,recoveryKw=100,maximumKw=150}
  calls=h.drawDial({instrumentMode='digital',digitalVariant=id,analogAuxiliaryMode='electric'},state)
  assert(has(calls,'ERS  -38 kW  BAT 84%'))
  state.hybrid=nil
  state.available=false
  calls=h.drawDial({instrumentMode='digital',digitalVariant=id,analogAuxiliaryMode='turbo'},state)
  assert(has(calls,'TURBO  N/A'))
  state.available=true
end
print('Digital variants: '..count..' theme/size/limiter/RPM scenarios, saved selections, controls and auxiliary fallbacks passed')
