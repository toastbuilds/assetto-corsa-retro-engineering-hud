local harness=dofile('tests/gt7_layouts.lua')
local Settings=require('src/gt7_settings')
local Styles=require('src/gt7_dial_styles')
local Paint=require('ui/auxiliary_dial_styles')
local Theme=require('src/theme')
local Light=require('ui/instrument_illumination')
local state=harness.state

assert(Styles.normalizeAuxiliary('invalid')=='original')
assert(Styles.auxiliaryStyle({gt7SpeedAuxiliaryStyle='halo'},true)=='original',
  'an unset RPM style must not inherit the fuel style')
for _,mode in ipairs({'analog','digital'}) do
  for _,motif in ipairs({'halo','jewel','spectrum'}) do
    assert(Styles.auxiliaryStyle({gt7RpmAuxiliaryStyle='match',gt7RpmDialStyle=motif..'_'..mode},true)==motif)
  end
end
assert(Styles.auxiliaryStyle({gt7RpmAuxiliaryStyle='match',gt7RpmDialStyle='snap_digital'},true)=='original')
Settings.values.gt7SpeedAuxiliaryStyle,Settings.values.gt7RpmAuxiliaryStyle='halo','spectrum'
local current=Settings.current()
assert(current.gt7SpeedAuxiliaryStyle=='halo' and current.gt7RpmAuxiliaryStyle=='spectrum')
package.loaded['src/gt7_settings']=nil
Settings=require('src/gt7_settings')
assert(Settings.current().gt7RpmAuxiliaryStyle=='spectrum','auxiliary selections must survive reloads')
harness.pendingButtons['Reset appearance##gt7']=true
Settings.draw()
assert(Settings.current().gt7SpeedAuxiliaryStyle=='original' and Settings.current().gt7RpmAuxiliaryStyle=='original')

state.available,state.lightsAvailable,state.headlights=true,true,false
state.fuel,state.maxFuel,state.fuelNormalized,state.fuelNeedleNormalized=30,50,0.6,0.6
state.turboAvailable,state.turboBoost,state.turboDisplayMax,state.boostNeedleNormalized=true,0.7,1.5,0.7/1.5
state.aeroLoadNormalized=0.68
state.speedText,state.speedValue,state.rpmText,state.rpm='139',139,'5200',5200
state.rpmGaugeNormalized,state.rpmWarning,state.rpmRedline,state.clock=0.65,false,false,0
state.gt7Instruments=nil

local function signature(calls,cx)
  local result={}
  for _,call in ipairs(calls) do
    local point=call.a or call.points and call.points[1]
    if point and math.abs(point.x-cx)<170 and call.kind~='text' then
      result[#result+1]=string.format('%s:%.3f:%.3f:%.3f',call.kind,point.x,point.y,call.radius or 0)
    end
  end
  return table.concat(result,'|')
end
local function labels(calls)
  local result={}
  for _,call in ipairs(calls) do
    if call.kind=='text' then result[call.text]=true end
  end
  return result
end
local drawings=0
for _,mode in ipairs({'analog','digital'}) do
  for _,rim in ipairs({false,true}) do
    for _,theme in ipairs({'dark','light'}) do
      for _,channel in ipairs({'fuel','boost','aero','hybrid'}) do
        local rpm=channel~='fuel'
        local main=rim and (mode=='analog' and 'track_analog' or 'orbit') or 'original'
        local options={theme=theme,gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
          gt7SpeedDialStyle=main,gt7RpmDialStyle=main,gt7SpeedAuxiliaryStyle='original',gt7RpmAuxiliaryStyle='original'}
        state.turboAvailable=channel~='aero'
        state.hybrid=channel=='hybrid' and {powerKw=120,needle=0.8,charge=0.84} or nil
        local original=harness.draw('classic',options,state)
        local cx=rpm and 1265 or 175
        local baseline=signature(original,cx)
        for _,style in ipairs({'halo','jewel','spectrum'}) do
          options[rpm and 'gt7RpmAuxiliaryStyle' or 'gt7SpeedAuxiliaryStyle']=style
          local calls=harness.draw('classic',options,state)
          assert((signature(calls,cx)~=baseline)==not rim,
            'only compact gauges allow auxiliary customization')
          local text=labels(calls)
          assert(text['139'],'the primary speed must remain available')
          if channel=='hybrid' then
            assert(text['CHG'] and text['PWR'] and text['120 kW'] and text['84%'],
              'styled hybrid gauges must preserve separate power and battery readouts')
          end
          assert(signature(calls,rpm and 175 or 1265)==signature(original,rpm and 175 or 1265),
            'changing one auxiliary style must not change the opposite dial')
          drawings=drawings+1
        end
      end
    end
  end
end

state.hybrid=nil
state.turboAvailable=true
for _,motif in ipairs({'halo','jewel','spectrum'}) do
  local options={gt7SpeedNeedleMode='digital',gt7RpmNeedleMode='digital',
    gt7SpeedDialStyle=motif..'_digital',gt7RpmDialStyle=motif..'_digital',
    gt7SpeedAuxiliaryStyle='match',gt7RpmAuxiliaryStyle='match'}
  local automatic=harness.draw('classic',options,state)
  options.gt7SpeedAuxiliaryStyle,options.gt7RpmAuxiliaryStyle=motif,motif
  local explicit=harness.draw('classic',options,state)
  assert(signature(automatic,175)==signature(explicit,175) and signature(automatic,1265)==signature(explicit,1265),
    'Match main dial must render the same geometry as the explicit matching style')
end

local C=Theme.get('dark')
local L=Light.resolve(C,'dark',0)
local vacuum=Paint.channel({kind='boost',available=true,value=0.125,zero=0.25,warning=0.925},C,L)
assert(vacuum.active(0.2) and not vacuum.active(0.5) and vacuum.color(0.2,true)==C.cyan,
  'vacuum must fill from zero toward the negative side')
local recovery=Paint.channel({kind='power',available=true,value=0.2,zero=0.5},C,L)
assert(recovery.active(0.3) and not recovery.active(0.7) and recovery.color(0.3,true)==C.green)
local stopped=Paint.channel({kind='power',available=true,value=0.5,zero=0.5},C,L)
assert(not stopped.active(0.5),'zero electric power must not light a delivery dot')
local missing=Paint.channel({kind='battery',available=false,value=nil,warning=0.15},C,L)
assert(not missing.active(0.1) and missing.color(0.1,false)==C.outlineDim)
local battery=Paint.channel({kind='battery',available=true,value=0.08,warning=0.15,lowInk=C.red},C,L)
assert(battery.color(0.05,true)==C.red and battery.spectrum(0.7)==C.red)

local function fuelDotAlpha(style,clock,animate,rim)
  state.fuel,state.fuelNormalized,state.clock=4,0.08,clock
  local calls=harness.draw('classic',{gt7SpeedNeedleMode='digital',gt7RpmNeedleMode='digital',
    gt7SpeedDialStyle=rim and 'orbit' or 'original',gt7RpmDialStyle='original',gt7SpeedAuxiliaryStyle=style,
    gt7RpmAuxiliaryStyle='original',animateIndicators=animate},state)
  for _,call in ipairs(calls) do
    local a=call.a
    if a and a.x<350 then
      local radius,cy=rim and 143 or 59,rim and 258 or 364
      local distance=math.sqrt((a.x-175)^2+(a.y-cy)^2)
      if (style=='spectrum' and call.kind=='arc' and math.abs(call.radius-radius)<0.1
            and call.thickness==(rim and 10 or 8))
          or (style~='spectrum' and call.kind=='circle_fill' and math.abs(distance-radius)<0.1
            and call.color.r>0.7 and call.color.g<0.4) then
        return call.color.mult
      end
    end
  end
  error('the low fuel indicator must remain visible')
end
for _,style in ipairs({'halo','jewel','spectrum'}) do
  for _,rim in ipairs({false}) do
    assert(fuelDotAlpha(style,0,true,rim)>fuelDotAlpha(style,0.3,true,rim),
      'fuel below 10% must blink: '..style)
    assert(fuelDotAlpha(style,0.3,false,rim)>0.8,'disabled indicator animation must retain the steady warning')
  end
end
state.fuel,state.fuelNormalized,state.clock=30,0.6,0
state.hybrid=nil
for _,mode in ipairs({'analog','digital'}) do
  for _,style in ipairs({'halo','jewel'}) do
    local options={gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
      gt7SpeedDialStyle='original',gt7RpmDialStyle='original',
      gt7SpeedAuxiliaryStyle=style,gt7RpmAuxiliaryStyle=style}
    local housings=0
    for _,call in ipairs(harness.draw('classic',options,state)) do
      if call.kind=='arc' and math.abs(call.a.y-364)<0.01
          and (math.abs(call.radius-70)<0.01 or math.abs(call.radius-67)<0.01) then
        housings=housings+1
      end
    end
    assert((mode=='analog' and housings==0) or (mode=='digital' and housings==4),
      'dot subdials must omit the housing only in Analog: '..style)
  end
end

local function spectrumLength(mode,rim,hybrid,value)
  state.fuel,state.fuelNormalized,state.fuelNeedleNormalized=50*value,value,value
  state.hybrid=hybrid and {powerKw=120,needle=0.8,charge=value} or nil
  local main=rim and (mode=='analog' and 'track_analog' or 'orbit') or 'original'
  local options={gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
    gt7SpeedDialStyle=main,gt7RpmDialStyle=main,
    gt7SpeedAuxiliaryStyle='spectrum',gt7RpmAuxiliaryStyle='spectrum'}
  local radius=rim and (hybrid and 151 or 143) or (hybrid and 68 or mode=='analog' and 65 or 59)
  local width=rim and (hybrid and 5 or 10) or (hybrid and 4 or 8)
  local cx,cy=hybrid and 1265 or 175,rim and 258 or 364
  local length=0
  for _,call in ipairs(harness.draw('classic',options,state)) do
    if call.kind=='arc' and math.abs(call.a.x-cx)<0.01 and math.abs(call.a.y-cy)<0.01
        and math.abs(call.radius-radius)<0.01 and call.thickness==width
        and math.max(call.color.r,call.color.g,call.color.b)>0.4 then
      length=length+call.endAngle-call.startAngle
    end
  end
  return length
end
for _,rim in ipairs({false}) do
  for _,hybrid in ipairs({false,true}) do
    local low=spectrumLength('analog',rim,hybrid,0.2)
    local high=spectrumLength('analog',rim,hybrid,0.8)
    assert(low>0 and high>low*3.5,'Analog Spectrum must consume its colored band as fuel or battery drops')
    assert(math.abs(spectrumLength('digital',rim,hybrid,0.2)-spectrumLength('digital',rim,hybrid,0.8))<0.001,
      'Digital Spectrum must retain its complete band')
  end
end
state.hybrid=nil
state.fuel,state.fuelNormalized,state.fuelNeedleNormalized=30,0.6,0.6
print('GT7 auxiliary styles: persistence, reset, independent choices, matching, '..drawings..
  ' drawings, themes, signed power/vacuum, missing data, warnings, Analog housing/consumption and unchanged Digital passed')
