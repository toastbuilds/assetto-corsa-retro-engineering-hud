local harness = dofile('tests/gt7_layouts.lua')
local Settings = require('src/gt7_settings')
local DialStyles = require('src/gt7_dial_styles')
local state, values = harness.state, Settings.values

assert(DialStyles.normalize('shelf', 'analog') == 'shelf')
assert(DialStyles.normalize('shelf', 'digital') == 'original')
assert(DialStyles.normalize('bridge', 'digital') == 'bridge')
assert(DialStyles.normalize('bridge', 'analog') == 'original')
assert(#DialStyles.analog == 10 and #DialStyles.digital == 10)
assert(#DialStyles.choices('analog','speed') == 9 and #DialStyles.choices('digital','speed') == 9)
assert(DialStyles.normalize('floating_capsule','digital')=='original',
  'removed Floating Capsule settings must migrate to Original')
assert(DialStyles.normalize('snap_analog','analog','rpm') == 'snap_analog')
assert(DialStyles.normalize('snap_digital','digital','speed') == 'original',
  'Snap Selector must not be available on the speed dial')
assert(DialStyles.normalize('snap_digital','digital','rpm') == 'snap_digital')

local originalSpeed, originalRpm = values.gt7SpeedDialStyle, values.gt7RpmDialStyle
values.gt7SpeedNeedleMode, values.gt7RpmNeedleMode = 'analog', 'digital'
values.gt7SpeedDialStyle, values.gt7RpmDialStyle = 'shelf', 'orbit'
local current = Settings.current()
assert(current.gt7SpeedDialStyle == 'shelf' and current.gt7RpmDialStyle == 'orbit',
  'speed and RPM styles must persist independently')
values.gt7SpeedNeedleMode = 'digital'
assert(Settings.current().gt7SpeedDialStyle == 'original', 'mode switches must fallback to Original')
values.gt7RpmDialStyle, values.gt7SpeedDialStyle = 'snap_digital', 'snap_digital'
assert(Settings.current().gt7RpmDialStyle == 'snap_digital' and values.gt7SpeedDialStyle == 'original',
  'Snap Selector must remain available only for the RPM dial')
values.gt7SpeedNeedleMode, values.gt7SpeedDialStyle = 'analog', 'fan'
values.gt7RpmDialStyle = 'orbit'
package.loaded['src.gt7_settings'] = nil
Settings = require('src.gt7_settings')
assert(Settings.current().gt7SpeedDialStyle == 'fan' and Settings.current().gt7RpmDialStyle == 'orbit',
  'style choices must survive settings proxy reload')
values.gt7SpeedDialStyle, values.gt7RpmDialStyle = 'spoke', 'radial'
harness.pendingButtons['Reset appearance##gt7'] = true
Settings.draw()
assert(values.gt7SpeedDialStyle == 'original' and values.gt7RpmDialStyle == 'original',
  'appearance reset must restore both style selectors to Original')

state.rpmRedline, state.rpmWarning = false, false
state.rpmText, state.rpm, state.rpmGaugeNormalized = '5200', 5200, 0.65
state.speedText, state.speedValue = '139', 139
local function signature(calls)
  local result, hasSpeed, hasRpm = {}, false, false
  for _, call in ipairs(calls) do
    if call.kind == 'arc' and call.a and math.abs(call.a.y - 258) < 8
        and (math.abs(call.a.x - 175) < 0.001 or math.abs(call.a.x - 1265) < 0.001) then
      result[#result + 1] = string.format('%.2f:%.4f:%.4f', call.radius, call.startAngle, call.endAngle)
    elseif (call.kind == 'circle' or call.kind == 'circle_fill') and call.a
        and (math.abs(call.a.x - 175) < 0.001 or math.abs(call.a.x - 1265) < 0.001)
        and math.abs(call.a.y - 258) < 8 then
      result[#result + 1] = string.format('c%.2f', call.radius)
    elseif call.kind == 'polygon' and call.points and call.points[1] then
      local point = call.points[1]
      if (math.abs(point.x - 175) < 160 or math.abs(point.x - 1265) < 160)
          and math.abs(point.y - 258) < 160 then
        result[#result + 1] = string.format('p%.1f:%.1f', point.x, point.y)
      end
    elseif call.kind == 'text' then
      if call.text == '139' and call.a and call.a.x < 350 then hasSpeed = true end
      if call.text == '5200' and call.a and call.a.x > 1090 then hasRpm = true end
    end
  end
  table.sort(result)
  return table.concat(result, '|') .. '#' .. #calls, hasSpeed, hasRpm
end
local analogSpeedReadouts={shelf=true,fan=true,concentric=true,spoke=true,track_analog=true}

for _, mode in ipairs({'analog', 'digital'}) do
  for _, dial in ipairs({'speed', 'rpm'}) do
    local choices = DialStyles.choices(mode,dial)
    local signatures = {}
    for _, choice in ipairs(choices) do
      local options = {theme='dark', gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
        gt7SpeedDialStyle='original', gt7RpmDialStyle='original'}
      options[dial == 'speed' and 'gt7SpeedDialStyle' or 'gt7RpmDialStyle'] = choice.value
      local calls = harness.draw('classic', options, state)
      local geometry, speedPresent, rpmPresent = signature(calls)
      local expectSpeed=mode=='digital' or (mode=='analog' and dial=='speed' and analogSpeedReadouts[choice.value])
      assert(speedPresent == not not expectSpeed and (mode == 'analog' or rpmPresent or dial=='rpm'),
        'only selected analog speed faces show the live reading; digital faces retain speed and RPM values')
      assert(#geometry > 0, 'each dial style must draw its scale bezel')
      signatures[#signatures + 1] = dial .. ':' .. choice.value .. ':' .. geometry
    end
    for _, choice in ipairs(choices) do
      for _, theme in ipairs({'dark', 'light'}) do
        local options = {theme=theme, gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
          gt7SpeedDialStyle='original', gt7RpmDialStyle='original'}
        options[dial == 'speed' and 'gt7SpeedDialStyle' or 'gt7RpmDialStyle'] = choice.value
        local calls = harness.draw('classic', options, state)
        local geometry, speedPresent, rpmPresent = signature(calls)
        local expectSpeed=mode=='digital' or (mode=='analog' and dial=='speed' and analogSpeedReadouts[choice.value])
        assert(#geometry > 0 and speedPresent == not not expectSpeed
          and (mode == 'analog' or rpmPresent or dial=='rpm'),
          'styles must follow their analog speed readout rule in both themes: ' .. choice.value)
      end
      -- Every selected variation must change recognizable geometry.
      if choice.value ~= 'original' then
        local options = {gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
          gt7SpeedDialStyle='original',gt7RpmDialStyle='original'}
        options[dial == 'speed' and 'gt7SpeedDialStyle' or 'gt7RpmDialStyle'] = choice.value
        assert(signature(harness.draw('classic',options,state)) ~= signature(harness.draw('classic', {
          gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
          gt7SpeedDialStyle='original',gt7RpmDialStyle='original'},state)),
          'each variation must have recognizable dial geometry: ' .. choice.value)
      end
    end
  end
end

-- These families must change the placement of the primary reading, rather
-- than merely add decorative rings to an otherwise identical face.
local function primaryPosition(style, mode)
  local calls = harness.draw('classic', {gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
    gt7SpeedDialStyle=style, gt7RpmDialStyle='original'}, state)
  for _,call in ipairs(calls) do
    if call.kind=='text' and call.text=='139' and call.size>25 and call.a.x<350 then return call.a end
  end
  error('styled dial must preserve a legible primary reading: ' .. style)
end
local radial, offset, orbit = primaryPosition('radial','digital'),
  primaryPosition('offset','digital'), primaryPosition('orbit','digital')
for _, pair in ipairs({{radial,offset},{radial,orbit},{offset,orbit}}) do
  local a,b=pair[1],pair[2]
  assert(math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)>25,
    'Radial, Offset and Orbit must use visibly different primary reading positions')
end
state.available=true
local snapCalls=harness.draw('classic',{gt7SpeedNeedleMode='digital',gt7RpmNeedleMode='digital',
  gt7SpeedDialStyle='original',gt7RpmDialStyle='snap_digital'},state)
local centerGear,rpmReadout=false,false
for _,call in ipairs(snapCalls) do
  if call.kind=='text' and call.text=='2' and call.a
      and math.abs(call.a.x-1265)<20 and call.a.y>230 and call.a.y<260 then centerGear=true end
  if call.kind=='text' and call.text=='5200' and call.a
      and math.abs(call.a.x-1265)<40 and call.a.y>300 then rpmReadout=true end
end
assert(centerGear and rpmReadout,
  'the RPM Snap Selector must keep the gear in the center and RPM below it')

local outwardPointer=false
for _,call in ipairs(snapCalls) do
  if call.kind=='polygon' and #call.points==3 then
    local a,b=call.points[1],call.points[2]
    local tip=math.sqrt((a.x-1265)^2+(a.y-258)^2)
    local base=math.sqrt((b.x-1265)^2+(b.y-258)^2)
    if tip>49 and tip<60 and base<46 and tip>base+5 then outwardPointer=true end
  end
end
assert(outwardPointer,'Snap must point outward toward the gear captions')

local analogSnap=harness.draw('classic',{gt7SpeedNeedleMode='analog',gt7RpmNeedleMode='analog',
  gt7SpeedDialStyle='original',gt7RpmDialStyle='snap_analog',gt7RpmNeedleStyle='b01'},state)
local lastSector,hand,gearCap=0,nil,nil
for index,call in ipairs(analogSnap) do
  if call.kind=='arc' and math.abs(call.a.x-1265)<0.01 and call.radius==79 then lastSector=index end
  if call.kind=='circle_fill' and math.abs(call.a.x-1265)<0.01 and call.radius==45 then gearCap=index end
  if call.kind=='polygon' then
    local nearest,farthest=math.huge,0
    for _,point in ipairs(call.points) do
      local distance=math.sqrt((point.x-1265)^2+(point.y-258)^2)
      nearest,farthest=math.min(nearest,distance),math.max(farthest,distance)
    end
    if nearest<30 and farthest>100 and farthest<130 then hand=hand or index end
  end
end
assert(hand and gearCap and lastSector>0 and lastSector<hand and hand<gearCap,
  'the Snap hand must sit above the gear sectors while its central cap keeps the gear legible')

local function lowerArcBlocks(calls,cx)
  local count=0
  for _,call in ipairs(calls) do
    if call.kind=='polygon' then
      for _,point in ipairs(call.points) do
        local distance=math.sqrt((point.x-cx)^2+(point.y-258)^2)
        if math.abs(distance-148)<0.1 and point.y>258 then count=count+1; break end
      end
    end
  end
  return count
end

for _,case in ipairs({
  {'analog','rpm','track_analog',true},{'analog','rpm','snap_analog',true},
  {'analog','speed','track_analog',true},{'analog','speed','fan',true},
  {'digital','rpm','snap_digital',true},{'digital','rpm','bridge',true},
  {'analog','rpm','fan',false},{'digital','speed','bridge',false}
}) do
  local mode,role,style,wantArc=case[1],case[2],case[3],case[4]
  local options={gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
    gt7SpeedDialStyle='original',gt7RpmDialStyle='original'}
  options[role=='speed' and 'gt7SpeedDialStyle' or 'gt7RpmDialStyle']=style
  local calls=harness.draw('classic',options,state)
  local cx=role=='speed' and 175 or 1265
  assert((lowerArcBlocks(calls,cx)>=32)==wantArc,
    'lower arc must follow the selected mode and dial role: '..style..' '..role)
  if wantArc then
    for _,call in ipairs(calls) do
      assert(not (call.kind=='arc' and math.abs(call.a.x-cx)<0.1
        and call.a.y>320 and call.radius<80),
        'the lower rim arc must replace the auxiliary mini dial')
    end
    if role=='rpm' then
      local previousHybrid=state.hybrid
      state.hybrid={powerKw=120,needle=0.8,charge=0.84}
      local labels={}
      for _,call in ipairs(harness.draw('classic',options,state)) do
        if call.kind=='text' then labels[call.text]=true end
      end
      state.hybrid=previousHybrid
      assert(labels['CHG'] and labels['PWR'] and labels['120 kW'] and labels['84%'],
        'new lower arcs must retain independent electric power and battery readings: '..style)
    end
  end
end

for _,mode in ipairs({'analog','digital'}) do
  for _,role in ipairs({'speed','rpm'}) do
    for _,motif in ipairs({'halo','jewel','spectrum','snap','track'}) do
      if not (motif=='track' and mode=='digital') and not (motif=='snap' and role=='speed') then
        local style=motif..'_'..mode
        local options={gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
          gt7SpeedDialStyle='original',gt7RpmDialStyle='original'}
        options[role=='speed' and 'gt7SpeedDialStyle' or 'gt7RpmDialStyle']=style
        local cx=role=='speed' and 175 or 1265
        local largeAux,dots,band,limiterLines,spacedLimiterLines=false,0,{},0,false
        for _,call in ipairs(harness.draw('classic',options,state)) do
          if call.kind=='arc' and math.abs(call.a.x-cx)<0.01 then
            if call.a.y>325 and call.radius>60 then largeAux=true end
            if math.abs(call.a.y-258)<8 and call.radius>100 then
              if motif=='halo' or motif=='jewel' then
                if motif=='jewel' and role=='rpm' and call.thickness==4.5 then
                  limiterLines=limiterLines+1
                  local profile=DialStyles.get(style,mode,role)
                  local first,last=math.deg(call.startAngle),math.deg(call.endAngle)
                  local function nearestCrownGap(angle)
                    local gap=math.huge
                    for index=0,24 do
                      local crown=profile.first+(profile.last-profile.first)*index/24
                      gap=math.min(gap,math.abs(angle-crown))
                    end
                    return gap
                  end
                  spacedLimiterLines=nearestCrownGap(first)>=3.99
                    and nearestCrownGap(last)>=3.99
                else
                  assert(call.thickness<=1,'dot crowns must not draw an underlying track or scale: '..style)
                end
              elseif motif=='spectrum' and call.thickness==22 then band[#band+1]=call end
            end
          elseif call.kind=='circle_fill' then
            local distance=math.sqrt((call.a.x-cx)^2+(call.a.y-258)^2)
            local crownDot=(motif=='halo' and math.abs(call.radius-6)<0.01)
              or (motif=='jewel' and (math.abs(call.radius-5)<0.01 or math.abs(call.radius-3.3)<0.01))
            if crownDot and distance>130 and distance<150 then
              dots=dots+1
              assert(call.a.y<365,'dot crowns must leave the lower alert area clear')
            end
          end
        end
        if motif=='track' or motif=='snap' then
          assert(lowerArcBlocks(harness.draw('classic',options,state),cx)>=32,
            'short upper sweeps must preserve the lower auxiliary rim: '..style)
        else
          assert(largeAux,'new dial styles must preserve an auxiliary gauge close to Original size: '..style)
        end
        if motif=='halo' or motif=='jewel' then assert(dots>=16,'dot crowns must remain visible') end
        if motif=='jewel' and role=='rpm' and mode=='analog' then
          assert(limiterLines>0 and spacedLimiterLines,
            'Jewel RPM limiter strokes must leave the same clear gap from crown dots as the individual dial')
        end
        if motif=='spectrum' then
          assert(#band>1 and band[1].color.g>band[1].color.r
            and band[#band].color.r>band[#band].color.g,'Spectrum must progress from green to red')
          assert(math.abs(band[#band].endAngle-band[1].startAngle-math.rad(280))<0.001,
            'Spectrum must use the extended 280-degree sweep')
          for i=2,#band do
            assert(band[i].startAngle<=band[i-1].endAngle,'Spectrum must have no gaps between color slices')
          end
        end
      end
    end
  end
end

local function redlineTone(calls,wantAmber)
  for _,call in ipairs(calls) do
    local color=call.color
    local circleDistance=call.a and math.sqrt((call.a.x-1265)^2+(call.a.y-258)^2) or 0
    local mainArc=call.kind=='arc' and call.a and math.abs(call.a.x-1265)<0.001
        and math.abs(call.a.y-258)<8 and call.radius>136 and call.radius<146
    local mainDot=call.kind=='circle_fill' and circleDistance>130 and circleDistance<150
    if color and (mainArc or mainDot) then
      if wantAmber and color.r>0.75 and color.g>0.5 and color.g<0.85 and color.b<0.55 then return true end
      if not wantAmber and color.r>0.75 and color.r-color.g>0.4 and color.b<0.35 then return true end
    end
  end
  return false
end
local oldRpm,oldRpmValue,oldFraction,oldWarning,oldRedline,oldClock=
  state.rpmText,state.rpm,state.rpmGaugeNormalized,state.rpmWarning,state.rpmRedline,state.clock
state.rpmText,state.rpm,state.rpmGaugeNormalized='7800',7800,0.98
state.rpmWarning,state.rpmRedline=true,true
for _,entry in ipairs({
  {'analog','halo_analog'},{'analog','jewel_analog'},{'analog','spectrum_analog'},
  {'analog','snap_analog'},{'digital','halo_digital'},{'digital','jewel_digital'},
  {'digital','spectrum_digital'},{'digital','snap_digital'}
}) do
  local mode,style=entry[1],entry[2]
  local options={gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
    gt7SpeedDialStyle='original',gt7RpmDialStyle=style}
  state.clock=0
  assert(redlineTone(harness.draw('classic',options,state),false),
    'redline segments must use red while the alert is on: '..style)
  state.clock=0.13
  assert(redlineTone(harness.draw('classic',options,state),true),
    'redline segments must blink to amber: '..style)
end
state.rpmText,state.rpm,state.rpmGaugeNormalized=oldRpm,oldRpmValue,oldFraction
state.rpmWarning,state.rpmRedline,state.clock=oldWarning,oldRedline,oldClock

state.available, state.fuel, state.maxFuel, state.fuelNormalized = true, 30, 50, 0.6
for _, style in ipairs({'radial','orbit'}) do
  local options={gt7SpeedNeedleMode='digital',gt7RpmNeedleMode='digital',
    gt7SpeedDialStyle=style,gt7RpmDialStyle=style}
  local calls=harness.draw('classic',options,state)
  local lowerBlocks=0
  for _, call in ipairs(calls) do
    if call.kind=='polygon' and call.points and call.points[1] then
      for _,p in ipairs(call.points) do
        local distance=math.sqrt((p.x-175)^2+(p.y-258)^2)
        if math.abs(distance-148)<0.1 and p.y>258 then lowerBlocks=lowerBlocks+1; break end
      end
    end
    assert(not (call.kind=='arc' and call.radius<80 and math.abs(call.a.x-175)<0.1
      and call.a.y>258 and call.a.y<430), 'fuel must use the lower bezel, without a mini dial')
  end
  assert(lowerBlocks>=32,'fuel must span the lower circular rim: '..style)
  state.hybrid={powerKw=120,needle=0.8,charge=0.84}
  local labels={}
  for _,call in ipairs(harness.draw('classic',options,state)) do
    if call.kind=='text' then labels[call.text]=true end
  end
  assert(labels['CHG'] and labels['PWR'] and labels['120 kW'] and labels['84%'],
    'the lower RPM arc must preserve independent hybrid readings')
  state.hybrid=nil
end

values.gt7SpeedDialStyle, values.gt7RpmDialStyle = originalSpeed, originalRpm
print('GT7 dial styles: mode/role fallback, independent persistence, inspired styles, themes and preserved readings passed')
