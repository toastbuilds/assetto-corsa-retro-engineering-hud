local harness=dofile('tests/gt7_layouts.lua')
local Profiles=require('src/mini_dial_profiles')
local Styles=require('src/gt7_dial_styles')
local Settings=require('src/gt7_settings')
local Theme=require('src/theme')
local Light=require('ui/instrument_illumination')
local Channels=require('ui/auxiliary_dial_styles')
local Mini=require('ui/mini_dial')
local state=harness.state
local function miniChoices(mode)
  local list={}
  for _,choice in ipairs(Styles.auxiliaryChoices(mode)) do
    if Profiles.get(choice.value) then list[#list+1]=choice end
  end
  return list
end
assert(#Profiles.choices==16 and #Styles.auxiliary==21)
assert(#Styles.auxiliaryChoices('digital')==20)
assert(Styles.normalizeAuxiliary('mini_f4c2','analog')=='mini_f4c2')
assert(Styles.normalizeAuxiliary('mini_f4c2','digital')=='original')
assert(Styles.auxiliaryStyle({gt7SpeedAuxiliaryStyle='mini_f4c2',gt7SpeedNeedleMode='digital'},false)=='original')
local offset=Profiles.get('mini_f1c4')
assert(math.abs(Profiles.angle(offset,0.8)-math.rad(310))<0.00001)
assert(math.abs(Profiles.angle(offset,0.9)-math.rad(355))<0.00001,
  'the wide final cell must represent the same value step as every narrow cell')

local function signature(calls,cx)
  local parts={}
  for _,call in ipairs(calls) do
    local p=call.a or call.points and call.points[1]
    if p and math.abs(p.x-cx)<170 then
      parts[#parts+1]=table.concat({call.kind,p.x,p.y,call.radius or 0,
        call.startAngle or 0,call.endAngle or 0,call.thickness or 0,
        call.b and call.b.x or 0,call.b and call.b.y or 0,call.text or ''},':')
    end
  end
  return table.concat(parts,'|')
end
local function labels(calls)
  local result={}
  for _,call in ipairs(calls) do if call.kind=='text' then result[call.text]=true end end
  return result
end
local function assertBounds(calls)
  local function point(p,pad)
    assert(p.x==p.x and p.y==p.y,'finite coordinates')
    assert(p.x-pad>=3 and p.x+pad<=217,'mini must fit the slot with side labels')
    assert(p.y-pad>=12 and p.y+pad<=155,'mini must clear the lower bezel')
  end
  for _,call in ipairs(calls) do
    if call.kind~='text' then
      if call.kind=='arc' then
        for i=0,40 do
          local a=call.startAngle+(call.endAngle-call.startAngle)*i/40
          point(vec2(call.a.x+call.radius*math.cos(a),call.a.y+call.radius*math.sin(a)),(call.thickness or 0)/2)
        end
      elseif call.radius then point(call.a,call.radius+(call.thickness or 0)/2)
      else
        if call.a then point(call.a,0) end
        if call.b then point(call.b,0) end
        for _,p in ipairs(call.points or {}) do point(p,0) end
      end
    end
  end
end

local drawings=0
for _,choice in ipairs(Profiles.choices) do
  local id=choice.value
  local profile=Profiles.get(id)
  local sizeScale=profile.sizeScale
  assert(Styles.normalizeAuxiliary(id)==id)
  Settings.values.gt7SpeedNeedleMode,Settings.values.gt7RpmNeedleMode='analog','analog'
  Settings.values.gt7SpeedAuxiliaryStyle,Settings.values.gt7RpmAuxiliaryStyle=id,id
  package.loaded['src/gt7_settings']=nil
  Settings=require('src/gt7_settings')
  assert(Settings.current().gt7SpeedAuxiliaryStyle==id and Settings.current().gt7RpmAuxiliaryStyle==id)
  for _,theme in ipairs({'dark','light'}) do
    local C=Theme.get(theme)
    for _,digital in ipairs({0,0.35,1}) do
      for _,kind in ipairs({'fuel','boost','aero','power'}) do
        for _,value in ipairs({0,0.08,0.6,1,false}) do
          local channel=Channels.channel({kind=kind,available=value~=false,
            value=value~=false and value or nil,zero=kind=='power' and 0.5 or kind=='boost' and 0.25 or 0,
            warning=kind=='fuel' and 0.15 or 0.9},C,Light.resolve(C,theme,0))
          local renderer={draw=function()
            Mini.draw(id,vec2(110,100),1,digital,channel,C,Light.resolve(C,theme,0),{
              left='E',right='F',label='FUEL',battery=kind=='power' and
                Channels.channel({kind='battery',available=value~=false,value=value~=false and value or nil,
                  warning=0.15},C,Light.resolve(C,theme,0)) or nil})
          end}
          local calls=harness.drawRenderer(renderer,state,{}, {220,180})
          assertBounds(calls)
          if kind=='fuel' and value==0.6 and digital==0 then
            for _,call in ipairs(calls) do
              assert(not (call.kind=='arc' and math.abs(call.thickness-2*sizeScale)<0.001
                and math.abs(call.radius-profile.segmentRadius*sizeScale)<0.001),
                'no printed reserve band in analog mini dials')
            end
          end
          if digital==1 and kind=='fuel' and Profiles.get(id).digital~=false then
            local profile,count=Profiles.get(id),0
            local expected={}
            local redStart=Profiles.angle(profile,0.85)
            for i=1,profile.segmentCount do
              local first,last=profile.edges[i],profile.edges[i+1]
              local gap=math.min(math.rad(2),(last-first)*0.12)
              local a,b=first+gap,last-gap
              if value~=false and a<redStart and b>redStart then
                expected[#expected+1]={a,redStart,false}
                expected[#expected+1]={redStart,b,true}
              else expected[#expected+1]={a,b,a>=redStart} end
            end
            for _,call in ipairs(calls) do
              if call.kind=='arc' and math.abs(call.radius-profile.segmentRadius*sizeScale)<0.001
                  and math.abs(call.thickness-profile.segmentWidth*sizeScale)<0.001 then
                count=count+1
                local interval=expected[count]
                assert(interval and math.abs(call.startAngle-interval[1])<0.00001)
                assert(math.abs(call.endAngle-interval[2])<0.00001)
                if interval[3] and value~=false then
                  local ink=value==1 and C.red or C.redDim
                  assert(call.color==ink,'terminal 15% uses the theme warning ink')
                end
              end
            end
            assert(count==#expected,'digital cells follow the divisions, splitting only at 85%')
          end
          for _,call in ipairs(calls) do
            if call.kind=='text' and (call.text=='E' or call.text=='F') then
              assert(math.abs(call.size-11*sizeScale)<0.001 and call.color==C.primary,'end labels use readable foreground ink')
              if not Profiles.get(id).half then
                local size=ui.measureDWriteText(call.text,call.size)
                local dx=math.max(call.a.x-110,110-call.a.x-size.x,0)
                local centerY=100+profile.offsetY+profile.y*sizeScale
                local dy=math.max(call.a.y-centerY,centerY-call.a.y-size.y,0)
                assert(math.sqrt(dx*dx+dy*dy)>(profile.radius+1.3)*sizeScale,
                  'E/F glyphs must be outside the full dial face and bezel')
              end
            end
          end
          drawings=drawings+1
        end
      end
    end
  end
end

state.available,state.lightsAvailable,state.headlights=true,true,true
state.fuel,state.maxFuel,state.fuelNormalized,state.fuelNeedleNormalized=30,50,0.6,0.6
state.turboBoost,state.turboDisplayMax,state.boostNeedleNormalized=0.7,1.5,0.7/1.5
state.aeroLoadNormalized,state.gt7Instruments=0.68,nil
state.speedText,state.speedValue,state.rpmText,state.rpm='139',139,'5200',5200
state.rpmWarning,state.rpmRedline=false,false
for _,mode in ipairs({'analog','digital'}) do
  for _,main in ipairs({'original',mode=='analog' and 'track_analog' or 'orbit',
      mode=='analog' and 'shelf' or 'offset'}) do
    for _,kind in ipairs({'fuel','boost','aero','hybrid'}) do
      local rpm=kind~='fuel'
      state.turboAvailable=kind~='aero'
      state.hybrid=kind=='hybrid' and {powerKw=-38,needle=-0.55,charge=0.08} or nil
      local options={theme='dark',gt7SimulateVacuum=true,gt7VacuumMinimum=-0.5,
        gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
        gt7SpeedDialStyle=main,gt7RpmDialStyle=main,
        gt7SpeedAuxiliaryStyle='original',gt7RpmAuxiliaryStyle='original'}
      local opposite=rpm and 175 or 1265
      local baseline=signature(harness.draw('classic',options,state),opposite)
      local ownBaseline=signature(harness.draw('classic',options,state),rpm and 1265 or 175)
      local unique={}
      for _,choice in ipairs(miniChoices(mode)) do
        options[rpm and 'gt7RpmAuxiliaryStyle' or 'gt7SpeedAuxiliaryStyle']=choice.value
        local calls=harness.draw('classic',options,state)
        assert(signature(calls,opposite)==baseline,'selection must not alter opposite dial')
        local own=signature(calls,rpm and 1265 or 175)
        local customizable=Styles.canCustomizeAuxiliary(options,rpm)
        if customizable then
          assert(not unique[own],table.concat({'duplicate family',mode,main,kind,choice.value,unique[own] or ''},':'))
          unique[own]=choice.value
        else assert(own==ownBaseline,'expanded lower gauges keep their fixed design') end
        local text=labels(calls)
        assert(text['139'],'primary speed remains visible')
        if kind=='hybrid' then
          assert(text['CHG'] and text['PWR'] and text['-38 kW'] and text['8%'],'hybrid keeps both readings')
        elseif customizable then
          assert(not text['BOOST'] and not text['FUEL'] and not text['AERO'],
            'fuel, boost and aero icons replace their captions')
          assert(text[kind=='fuel' and 'E' or kind=='aero' and '100' or '1.5'])
        end
        drawings=drawings+1
      end
    end
  end
end
state.hybrid=nil
-- Check glyph rectangles in the composed HUD against the primary bezel, not
-- just the isolated mini canvas. This catches the original lower clipping.
for _,mode in ipairs({'analog','digital'}) do
  for _,rpm in ipairs({false,true}) do
    for _,main in ipairs(Styles.choices(mode,rpm and 'rpm' or 'speed')) do
      local options={theme='dark',gt7SimulateVacuum=true,gt7VacuumMinimum=-0.5,
        gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
        gt7SpeedDialStyle=main.value,gt7RpmDialStyle=main.value}
      local customizable=Styles.canCustomizeAuxiliary(options,rpm)
      local baseline
      for _,choice in ipairs(Styles.auxiliaryChoices(mode)) do
        options[rpm and 'gt7RpmAuxiliaryStyle' or 'gt7SpeedAuxiliaryStyle']=choice.value
        local calls=harness.draw('classic',options,state)
        local cx=rpm and 1265 or 175
        local own=signature(calls,cx)
        if not customizable then
          baseline=baseline or own
          assert(own==baseline,'every expanded lower scale must ignore saved styles')
          assert(Styles.auxiliaryStyle(options,rpm)=='original')
        end
        for _,call in ipairs(calls) do
          if call.kind=='text' and math.abs(call.a.x-cx)<170 and
              (call.text=='E' or call.text=='F' or call.text=='-0.5' or call.text=='1.5'
                or call.text=='FUEL' or call.text=='AERO') then
            local size=ui.measureDWriteText(call.text,call.size)
            for _,dx in ipairs({0,size.x}) do
              for _,dy in ipairs({0,size.y}) do
                local x,y=call.a.x+dx-cx,call.a.y+dy-258
                assert(x*x+y*y<171*171,'scale labels must fit inside the main bezel: '..main.value..'/'..choice.value)
              end
            end
          end
        end
        drawings=drawings+1
      end
    end
  end
end
-- Hidden selectors cannot consume a pending selection, and returning to a
-- compact face exposes the selector again without losing the saved style.
Settings.values.gt7SpeedNeedleMode,Settings.values.gt7RpmNeedleMode='analog','digital'
Settings.values.gt7SpeedDialStyle,Settings.values.gt7RpmDialStyle='fan','bridge'
Settings.values.gt7SpeedAuxiliaryStyle,Settings.values.gt7RpmAuxiliaryStyle='mini_f1c1','mini_f2c1'
harness.pendingCombos['##gt7.speedAuxiliaryStyle']=2
harness.pendingCombos['##gt7.rpmAuxiliaryStyle']=2
Settings.draw()
assert(harness.pendingCombos['##gt7.speedAuxiliaryStyle']==2 and harness.pendingCombos['##gt7.rpmAuxiliaryStyle']==2)
assert(Settings.current().gt7SpeedAuxiliaryStyle=='mini_f1c1' and Settings.current().gt7RpmAuxiliaryStyle=='mini_f2c1')
Settings.values.gt7SpeedDialStyle,Settings.values.gt7RpmDialStyle='original','original'
Settings.draw()
assert(harness.pendingCombos['##gt7.speedAuxiliaryStyle']==nil and harness.pendingCombos['##gt7.rpmAuxiliaryStyle']==nil)
assert(Settings.current().gt7SpeedAuxiliaryStyle=='halo' and Settings.current().gt7RpmAuxiliaryStyle=='halo')
for _,frame in ipairs({'classic','modern','outer_pedals','steering_dial'}) do
  for _,mode in ipairs({'analog','digital'}) do
    for _,choice in ipairs(miniChoices(mode)) do
      local calls=harness.draw(frame,{theme='dark',gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
        gt7SpeedAuxiliaryStyle=choice.value,gt7RpmAuxiliaryStyle=choice.value},state)
      local text=labels(calls)
      assert(text['E'] and text['F'] and not text['FUEL'] and not text['BOOST'])
      drawings=drawings+1
    end
  end
end
harness.pendingButtons['Reset appearance##gt7']=true
Settings.draw()
assert(Settings.current().gt7SpeedAuxiliaryStyle=='original' and Settings.current().gt7RpmAuxiliaryStyle=='original')
for _,theme in ipairs({'dark','light'}) do
  local C=Theme.get(theme)
  local function fuelCalls(id,value,needle,digital)
    local renderer={draw=function()
      Mini.draw(id,vec2(110,100),1,digital or 0,Channels.channel({kind='fuel',
        available=value~=false,value=value~=false and value or nil,needleValue=needle,
        warning=0.15},C,{}),C,{},{left='E',right='F'})
    end}
    drawings=drawings+1
    return harness.drawRenderer(renderer,state,{}, {220,180})
  end
  local function span(calls,radius,width,ink)
    local total=0
    for _,call in ipairs(calls) do
      if call.kind=='arc' and math.abs(call.radius-radius)<0.001
          and math.abs(call.thickness-width)<0.001 and call.color==ink then
        total=total+call.endAngle-call.startAngle
      end
    end
    return total
  end
  for _,id in ipairs({'mini_f1c3','mini_f1c4','mini_f2c3','mini_f4c2','mini_f4c4'}) do
    local f=Profiles.get(id)
    local radius=(f.radius-(f.sweep and 5 or 9))*f.sizeScale
    local width=10*f.sizeScale
    local empty=fuelCalls(id,0,0)
    local partial=fuelCalls(id,0.3,0.3)
    local full=fuelCalls(id,1,1)
    assert(span(empty,radius,width,C.inactive)>0 and span(empty,radius,width,C.primary)==0,
      'empty analog fuel ornaments must remain visible in the off color')
    assert(span(full,radius,width,C.primary)>span(partial,radius,width,C.primary),
      'analog ornaments must show remaining fuel as well as the needle')
    assert(span(fuelCalls(id,0.2,0.2),radius,width,C.amber)>0,'low fuel approaches reserve in amber')
    assert(span(fuelCalls(id,0.08,0.08),radius,width,C.red)>0,'reserve uses the theme red')
    assert(span(fuelCalls(id,false,nil),radius,width,C.primary)==0,'missing fuel must not light a fill')
  end
  local f=Profiles.get('mini_f1c4')
  local wideFill=false
  for _,call in ipairs(fuelCalls(f.id,0.9,0.9)) do
    if call.kind=='arc' and call.color==C.primary and call.startAngle>f.edges[5] then
      assert(math.abs(call.endAngle-Profiles.angle(f,0.9))<0.00001,
        'the wide cell fill must end at the needle, including its longer travel per value unit')
      wideFill=true
    end
  end
  assert(wideFill,'the wide F1C4 cell must actively indicate fuel')
  for _,id in ipairs({'mini_f3c4','mini_f2c4'}) do
    local profile=Profiles.get(id)
    local start=id=='mini_f3c4' and profile.edges[profile.segmentCount] or Profiles.angle(profile,0.85)
    local found=false
    for _,call in ipairs(fuelCalls(id,0.6,0.6)) do
      if call.kind=='arc' and call.color==C.redDim then
        assert(call.startAngle>=start and call.endAngle<=profile.last,'red background stays in its requested cells')
        found=true
      end
    end
    assert(found,'the fuel background must show its warning color')
  end
  local function tickCount(value,needle,digital)
    local count=0
    for _,call in ipairs(fuelCalls('mini_f2c3',value,needle,digital)) do
      if call.kind=='line' and call.color==C.primary then count=count+1 end
    end
    return count
  end
  assert(tickCount(0.8,0.8,0)>tickCount(0.8,0.2,0),'analog ticks must follow the smoothed needle')
  assert(tickCount(0.8,0.8,1)==tickCount(0.8,0.2,1),'digital keeps its printed ticks')
end
local function accentAlpha(clock,animate)
  state.fuel,state.fuelNormalized,state.fuelNeedleNormalized,state.clock=6,0.12,0.12,clock
  local f=Profiles.get('mini_f2c1')
  for _,call in ipairs(harness.draw('classic',{theme='dark',animateIndicators=animate,
      gt7SpeedNeedleMode='analog',gt7SpeedAuxiliaryStyle=f.id},state)) do
    if call.kind=='arc' and math.abs(call.a.x-175)<0.01 and
        math.abs(call.radius-(f.radius-6)*f.sizeScale)<0.001 and
        math.abs(call.startAngle-math.rad(300))<0.00001 then return call.color.mult end
  end
  error('F2C1 warning accent must remain visible')
end
assert(accentAlpha(0,true)>accentAlpha(0.3,true),'F2C1 accent must flash red throughout low fuel')
assert(accentAlpha(0.3,false)>0.8,'disabled animations keep the F2C1 accent steadily red')
state.fuel,state.fuelNormalized,state.fuelNeedleNormalized,state.clock=30,0.6,0.6,0
print('GT7 mini dials: 16 families, persistence, independent selection, distinct geometry, bounds, transitions, missing data and '..drawings..' drawings passed')
