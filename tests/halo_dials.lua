local h=dofile('tests/gt7_layouts.lua')
local Settings=require('src/settings')
local state=h.state
Settings.values.analogVariant,Settings.values.digitalVariant='halo','halo'
assert(Settings.current().analogVariant=='halo' and Settings.current().digitalVariant=='halo',
  'Halo selections must persist independently')
state.available=true
state.speedText,state.speedUnit,state.gearText='139','km/h','R'
state.turboAvailable,state.turboBoost,state.turboDisplayMax=true,0.7,1.5
state.fuel,state.maxFuel,state.fuelNormalized=30,50,0.6
state.headlights,state.gt7Instruments,state.hybrid=false,nil,nil
state.lightsAvailable,state.tcSupported,state.absSupported=true,true,true
state.brake,state.throttle,state.clutch=0.3,0.7,0.2
state.steeringInput,state.clock=0.2,0.05
state.rpmWarningFraction,state.rpmRedlineFraction=0.86,0.96
local function has(calls,value)
  for _,call in ipairs(calls) do if call.kind=='text' and call.text==value then return true end end
  return false
end
local function dots(calls,size)
  local result={}
  for _,call in ipairs(calls) do
    if call.kind=='circle_fill' and math.abs(call.radius-12*size/620)<0.00001 then result[#result+1]=call end
  end
  return result
end
local count=0
for _,mode in ipairs({'analog','digital'}) do
  for _,theme in ipairs({'dark','light'}) do
    for _,size in ipairs({320,620,900}) do
      for _,maximum in ipairs({6000,16000}) do
        for _,fraction in ipairs({0,0.65,1}) do
          state.rpmGaugeLimiter,state.rpmDisplayLimiter=maximum,maximum
          state.rpmGaugeNormalized,state.analogNeedleNormalized=fraction,fraction
          state.rpm,state.rpmText=maximum*fraction,tostring(maximum*fraction)
          state.rpmWarning,state.rpmRedline=fraction==1,fraction==1
          local calls=h.drawDial({instrumentMode=mode,analogVariant='halo',digitalVariant='halo',
            hudScale=1,theme=theme,analogAuxiliaryMode='turbo'},state,{size,size})
          assert(has(calls,'139') and has(calls,'R'),'speed and gear must remain legible')
          assert(not has(calls,'TC') and not has(calls,'ABS') and not has(calls,'PIT'),'states must use symbols')
          assert(has(calls,state.rpmText)==(mode=='digital' or fraction==0),
            'digital retains exact RPM; analog uses its numbered scale')
          local corona=dots(calls,size)
          assert(#corona==16,'the chevron must replace the central dot')
          local active=0
          for _,dot in ipairs(corona) do if dot.color.mult>0.8 then active=active+1 end end
          assert(active==(fraction==0 and 0 or fraction==1 and 16 or 10),'dot progression must follow RPM')
          count=count+1
        end
      end
    end
  end
end
state.rpmGaugeLimiter,state.rpmDisplayLimiter=8000,8000
state.rpmGaugeNormalized,state.analogNeedleNormalized=1,1
state.rpmWarning,state.rpmRedline=false,true
local options={instrumentMode='digital',digitalVariant='halo',analogVariant='halo',hudScale=1,analogAuxiliaryMode='turbo'}
state.clock=0.05
local on=dots(h.drawDial(options,state),620)[1].color
state.clock=0.18
local off=dots(h.drawDial(options,state),620)[1].color
assert(on.g~=off.g,'redline must pulse even when the separate shift warning is false')
local function fuelSegment(calls)
  for _,call in ipairs(calls) do
    if call.kind=='arc' and math.abs(call.radius-164)<0.00001 and call.thickness==8
      and call.startAngle>math.rad(40) and call.endAngle<math.rad(46) then return call.color end
  end
  error('fuel segment missing')
end
state.rpmWarning,state.rpmRedline=false,false
state.fuel,state.fuelNormalized=4,0.08
state.clock=0.05
local low=fuelSegment(h.drawDial(options,state))
state.clock=0.35
local dim=fuelSegment(h.drawDial(options,state))
assert(low.r>low.g and low.r~=dim.r,'critical fuel must retain its red blinking warning')
state.hybrid={charge=0.84,powerKw=-38,needle=-0.55,recoveryKw=100,maximumKw=150}
options.analogAuxiliaryMode='electric'
for _,mode in ipairs({'analog','digital'}) do
  options.instrumentMode=mode
  assert(has(h.drawDial(options,state),'-38'),'electric power must remain visible alongside the battery track')
  options.analogAuxiliaryMode='off'
  local calls=h.drawDial(options,state)
  assert(not has(calls,'-38') and has(calls,'4'),'auxiliary off hides its channel while preserving fuel')
  options.analogAuxiliaryMode='electric'
end
print('Halo: '..count..' drawing scenarios, persistence, RPM progression, redline/fuel pulses and electric readouts passed')
