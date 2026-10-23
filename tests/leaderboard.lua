package.path = './?.lua;' .. package.path
ac = { SessionType = {Race=1} }
local Session = require('modules/leaderboard/src/session')
local session = {type=1,isTimedRace=true,hasAdditionalLap=false}
local sim = {sessionTimeLeft=90000}
local leader = {lapCount=3,bestLapTimeMs=90000}
local localRow = {lapCount=2}
assert(Session.lapHeader(session,sim,leader,60000,true)=='LAPS: ~4')
leader.bestLapTimeMs=45000
assert(Session.lapHeader(session,sim,leader,60000,true)=='LAPS: ~5')
leader.bestLapTimeMs=0
assert(Session.lapHeader(session,sim,leader,60000,true)=='LAPS: --')
assert(Session.lapsRemaining(session,sim,localRow,leader,60000)==nil)
leader.bestLapTimeMs=90000
for _,ms in ipairs({90000,1000,0,-1000,7200000}) do
  assert(Session.timeLeftSeconds({sessionTimeLeft=ms},nil)==ms/1000)
end
session.hasAdditionalLap=true
assert(Session.lapsRemaining(session,sim,localRow,leader,60000)==2)
session.isTimedRace=false; session.laps=10
assert(Session.lapsRemaining(session,sim,localRow,leader,60000)==8)
assert(Session.lapHeader(session,sim,leader,nil,true)=='LAPS: 10')
local cleanHeader = Session.snapshotHeader({sessionTimeLeft=90000,ambientTemperature=24,trackTemperature=32},
  session,localRow,leader,nil,{showLapEstimate=true})
assert(cleanHeader.ambientText==nil and cleanHeader.trackText==nil, 'weather data is removed from leaderboard snapshots')
local Fuel = require('modules/leaderboard/src/fuel')
ui = {time=function() return 1 end}
local car = {fuel=30,maxFuel=100,lapCount=0,isLastLapValid=true,previousLapTimeMs=90000}
ac.getCar=function() return car end
local state = Fuel.new()
local snap = {sim={currentSessionIndex=0},lapsRemaining=2}
Fuel.update(state,snap,{fuelReserve=1})
car.fuel=27; Fuel.update(state,snap,{fuelReserve=1})
car.lapCount=1; Fuel.update(state,snap,{fuelReserve=1})
assert(state.average==3 and state.fuelNeeded==7)
snap.lapsRemaining=nil; Fuel.update(state,snap,{fuelReserve=1})
assert(not state.finishAvailable and state.finishText=='--')
car.lapCount=0; Fuel.update(state,snap,{fuelReserve=1})
assert(state.average==nil, "same-session rewind must clear fuel samples")
snap.sim.currentSessionIndex=1; Fuel.update(state,snap,{fuelReserve=1})
assert(state.average==nil)
-- Reuse the instrument drawing doubles for the real leaderboard header.
dofile('tests/runtime_smoke.lua')
local Display = require('modules/leaderboard/ui/leaderboard')
local Theme = require('modules/leaderboard/src/theme')
ui.pushClipRect=function() end
ui.popClipRect=function() end
local texts={}
ui.dwriteDrawText=function(value,size,pos) texts[#texts+1]={value=value,size=size,pos=pos} end
ui.measureDWriteText=function(value,size) return vec2(#value*size*0.6,size*1.35) end
for _,theme in ipairs({'dark','light'}) do
 for _,scale in ipairs({0.55,1.25}) do
  ui.windowWidth=function() return 1040*scale end
  ui.windowHeight=function() return 470*scale end
  for _,fuelVisible in ipairs({false,true}) do
   for _,flags in ipairs({false,true}) do
    texts={}
    Display.draw({header={typeLabel='RACE',lapsText='LAPS: ~123',currentLapText='9',
      timeText='12:34',isTimed=true,ambientText='18 C',trackText='25 C'},shownRows={},enteredAt=0,
      fuel={available=true,fuelText='123.4 L',averageText='12.3 L/LAP',estimatedLapsText='123 LAPS'}},
      {hudScale=scale,showFlags=flags,showFuel=fuelVisible},
      {palette=Theme.get(theme),instrumentOpacity=0.7})
    local seen={}
    for _,t in ipairs(texts) do
     seen[t.value]=t
     assert(not t.value:find('AIR') and not t.value:find('TARMAC'))
     assert(t.value~='18 C' and t.value~='25 C', 'retired temperatures must never render')
     local m=ui.measureDWriteText(t.value,t.size)
     assert(t.pos.x>=0 and t.pos.x+m.x<=1040*scale+0.01)
    end
    for _,caption in ipairs({'SESSION','TIME','TIME LEFT','LAP / TOTAL','LAP / ESTIMATE','CURRENT LAP','RACE','FLAG'}) do
      assert(not seen[caption], 'the header should render values without redundant captions')
    end
    assert(seen['12:34'] and seen['9 / ~123'])
    assert(seen['12:34'].size >= 39*scale and seen['9 / ~123'].size >= 39*scale,
      'the two main header values should use the freed space')
    assert(ui.measureDWriteText('12:34',seen['12:34'].size).y
      < (81-25)*scale,
      'countdown must stay clear of the flag strip')
    assert(math.abs(seen['12:34'].pos.x/scale-36)<0.001)
    assert(math.abs(seen['9 / ~123'].pos.x/scale-(fuelVisible and 330 or 530))<0.001)
    assert((seen.CLEAR~=nil)==flags)
    assert((seen['FUEL 123.4 L']~=nil)==fuelVisible)
    assert((seen['USE 12.3 L/LAP']~=nil)==fuelVisible)
    assert((seen['RANGE 123 LAPS']~=nil)==fuelVisible)
   end
  end
 end
end
print('Leaderboard: leader references, missing times, countdown, fuel, reset and 16 header drawings passed')

-- Preserve all header regressions above and exercise actual row content at
-- every supported count, in shared palettes and window sizes.
local General = require('src/general_settings')
General.values.theme = 'dark'
General.values.monochrome = false
local Settings = require('modules/leaderboard/src/settings')
assert(Settings.values.maxRows == 5 and Settings.values.sectorReference == 'General')
Settings.values.maxRows = 8
Settings.normalize()
assert(Settings.values.maxRows == 8, 'normalization must preserve a stored row preference')
Settings.values.maxRows = 20; Settings.normalize(); assert(Settings.values.maxRows == 10)
Settings.values.maxRows = 1; Settings.normalize(); assert(Settings.values.maxRows == 3)
local SharedTheme = require('src/theme')
local palettes = {Theme, SharedTheme}
local drawCases = 0
local clips, circles = {}, {}
local windowW, windowH
ui.pushClipRect = function(tl, br) clips[#clips + 1] = {tl = tl, br = br} end
ui.popClipRect = function() assert(#clips > 0); clips[#clips] = nil end
ui.drawCircleFilled = function(pos, radius, color)
  if radius < 3 then circles[#circles + 1] = {pos = pos, color = color} end
end
ui.time = function() return 100 end
ui.windowWidth = function() return windowW end
ui.windowHeight = function() return windowH end
ui.dwriteDrawText = function(value, size, pos, color)
  local measured = ui.measureDWriteText(value, size)
  local x1, y1, x2, y2 = pos.x, pos.y, pos.x + measured.x, pos.y + measured.y
  for _, clip in ipairs(clips) do
    x1, y1 = math.max(x1, clip.tl.x), math.max(y1, clip.tl.y)
    x2, y2 = math.min(x2, clip.br.x), math.min(y2, clip.br.y)
  end
  if x1 < x2 and y1 < y2 then
    texts[#texts + 1] = {value = value, size = size, pos = pos, color = color, rect = {x1, y1, x2, y2}}
  end
end
local function has(label)
  for _, t in ipairs(texts) do if t.value == label then return true end end
  return false
end
local function luminance(color)
  local function linear(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
  return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
end
local function contrast(a, b)
  a, b = luminance(a), luminance(b)
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end
local function sampleRows(count, mode, sectorCount)
  local rows = {}
  for i = 1, count do
    rows[i] = {index = i - 1, isLocal = i == count, position = i,
      driver = string.format('DRIVER_%02d A VERY LONG NAME TO FIT THE NAME COLUMN', i),
      classID = i == count and 'UNKNOWN' or 'GT3', tyreCompound = 'MEDIUM COMPOUND',
      status = i == 2 and 'PIT' or i == 3 and 'FIN' or 'LIVE', bestLapTimeMs = 90000 + (i - 1) * 250,
      lastLapTimeMs = 89999, interval = '+0.5s', sectorCount = sectorCount,
      sectors = {}, sectorReferenceLabel = i == count and 'GENERAL (UNKNOWN CLASS)' or 'GT3',
      balanceLabel = i == count and 'CONNECTION' or 'START', lapPositionDelta = i - 1,
      positionChangeDelta = -1, positionChangeUntil = 110}
    for s = 1, sectorCount do
      rows[i].sectors[s] = {timeMs = 30000, role = ({'PURPLE', 'GREEN', 'AMBER'})[s], active = s == 1}
    end
  end
  return rows
end
for _, source in ipairs(palettes) do
  for _, name in ipairs({'dark', 'light'}) do
    local palette = source.get(name)
    for _, color in ipairs({'secondary', 'flagPurple', 'green', 'amber', 'red', 'cyan', 'blue'}) do
      local readable = Theme.textColor(palette, color)
      assert(contrast(readable, palette.panelRaised) >= 4.5, 'internal text needs contrast: ' .. color)
      if name == 'dark' and palette[color] then
        assert(luminance(readable) > luminance(palette[color]), 'dark-theme text should be lighter: ' .. color)
      end
    end
    assert(contrast(Theme.textColor(palette, rgbm(0.92, 0.92, 0.92, 1)), palette.panelRaised) >= 4.5,
      'pale custom class colors also need readable light-theme text')
    local purple = palette.flagPurple
    assert(purple and purple.r == (name == 'dark' and 0.68 or 0.51)
      and purple.g == (name == 'dark' and 0.35 or 0.18) and purple.b == (name == 'dark' and 0.90 or 0.72))
    for _, size in ipairs({{572, 259}, {1040, 470}, {1300, 930}}) do
      windowW, windowH = size[1], size[2]
      for count = 3, 10 do
        for _, mode in ipairs({'PRAC', 'RACE'}) do
          local rows = sampleRows(count, mode, 3)
          texts, circles = {}, {}
          Display.draw({header = {typeLabel = mode, timeText = '12:34', lapsText = 'LAPS: 10'},
            shownRows = rows, localRow = rows[count], sessionBest = 90000, enteredAt = 0,
            fuel = {available = true, fuelText = '30.0 L', averageText = '3.0 L/LAP', estimatedLapsText = '9 LAPS'}},
            {hudScale = 1.20, maxRows = count, showClass = true, showCompound = true, sectorReference = 'Class'},
            {palette = palette, instrumentOpacity = 0.7})
          assert(#clips == 0)
          local drivers = 0
          for _, t in ipairs(texts) do
            if t.value:find('^DRIVER_') then drivers = drivers + 1 end
            local rect = t.rect
            assert(rect[1] >= -0.01 and rect[2] >= -0.01 and rect[3] <= windowW + 0.01 and rect[4] <= windowH + 0.01)
          end
          assert(drivers == count, 'must render every selected row including 6 through 10')
          assert(has('FUEL 30.0 L') and has('USE 3.0 L/LAP') and has('RANGE 9 LAPS'))
          for _,label in ipairs({'INTERVAL','LAST LAP','GAP','BEST LAP','SB','0'}) do
            assert(not has(label), 'compact rows must not contain redundant subtext: '..label)
          end
          if mode == 'PRAC' then
            assert(not has('+0.000') and has('+0.250'), 'hide the leader zero and retain meaningful subsecond gaps')
            assert(not has('REF GENERAL (UNKNOWN CLASS)') and has('S1') and has('S2') and has('S3'))
            assert(not has('30.000'), 'sector indicators must not display numerical sector times')
            for _, t in ipairs(texts) do
              assert(not t.value:match('^%d+%.%d%d%d$'), 'numerical sector readouts are not part of this UI')
            end
            local purpleText, lastDriver, lastSector = false, nil, nil
            for _, t in ipairs(texts) do
              if t.value:find('^DRIVER_') then lastDriver, lastSector = t, nil end
              if t.value:match('^S[123]$') then
                assert(lastDriver and t.rect[1] > lastDriver.rect[3], 'sectors must sit to the right of the name')
                assert(not lastSector or t.rect[1] > lastSector.rect[3], 'sector labels must not overlap')
                assert(math.abs(t.size / lastDriver.size - 16 / 24) < 0.0001, 'sector text must use the larger 16px size')
                assert(contrast(t.color, palette.panelRaised) >= 4.5, 'sector labels need readable contrast in both themes')
                if t.value == 'S1' then
                  assert(t.color.b > t.color.r and t.color.r > t.color.g, 'best-sector text retains its purple hue')
                  purpleText = true
                end
                lastSector = t
              end
            end
            assert(purpleText, 'reference best must display the brighter purple text')
            local purpleDot = false
            for _, circle in ipairs(circles) do
              if math.abs(circle.color.r - purple.r) < 0.0001 then purpleDot = true end
            end
            assert(purpleDot, 'active sector dots retain the authored semantic purple')
          else
            assert(not has('BALANCE CONNECTION') and not has('BALANCE START') and not has('NOW'))
          end
          drawCases = drawCases + 1
        end
      end
    end
  end
end
windowW, windowH = 1040, 470
local personalRows = sampleRows(5, 'PRAC', 1)
local personal = personalRows[5]
texts, circles = {}, {}
Display.draw({header = {typeLabel = 'HOTLAP'}, personal = true, localRow = personal, shownRows = personalRows,
  fuel = {available = true, fuelText = '30.0 L', averageText = '3.0 L/LAP', estimatedLapsText = '9 LAPS'}},
  {hudScale = 0.84, maxRows = 10}, {palette = Theme.get('dark')})
local drivers = 0
for _, t in ipairs(texts) do if t.value:find('^DRIVER_') then drivers = drivers + 1 end end
assert(drivers == 1 and not has('HOTLAP') and has('PERSONAL') and has('FUEL 30.0 L') and has('S1') and not has('S2') and not has('S3'))
assert(#circles == 1, 'one-sector track must have exactly one active sector indicator')
personal.status = 'FIN'
texts, circles = {}, {}
Display.draw({header = {typeLabel = 'TA'}, personal = true, localRow = personal, shownRows = personalRows},
  {hudScale = 0.84, maxRows = 10, showFuel = false, showClass = false}, {palette = SharedTheme.get('light')})
assert(not has('TA') and has('PERSONAL') and has('FIN') and #circles == 0)
print('Leaderboard: stored settings, ' .. drawCases .. ' row drawings, shared palettes and personal one-sector cases passed')

-- Compact race rows retain one meaningful gain/loss beside the position.
windowW,windowH=1040,470
local compact={index=0,isLocal=true,position=1,driver='COMPACT PLAYER',classID='GT3',status='LIVE',
  interval='0.0s',lastLapTimeMs=90000,lapPositionDelta=0,positionChangeDelta=0,positionChangeUntil=110}
local snap={header={typeLabel='RACE'},shownRows={compact}}
local settings={hudScale=1,maxRows=5,showFuel=false}
texts,circles={},{}
Display.draw(snap,settings,{palette=Theme.get('dark')})
assert(not has('0') and not has('0.0s') and has('01:30.000'), 'hide unchanged balance and player reference interval')
compact.lapPositionDelta=3
texts,circles={},{}
Display.draw(snap,settings,{palette=Theme.get('dark')})
assert(has('+3'), 'nonzero cumulative balance stays beside the position')
compact.positionChangeDelta=-1
texts,circles={},{}
Display.draw(snap,settings,{palette=Theme.get('dark')})
assert(has('-1') and not has('+3'), 'recent change temporarily takes priority in the same slot')
compact.positionChangeUntil=99
texts,circles={},{}
Display.draw(snap,settings,{palette=Theme.get('dark')})
assert(has('+3') and not has('-1'), 'expired notification restores the cumulative balance')
print('Compact leaderboard: no subtexts, zero suppression and one signed position value passed')

-- A flag strip uses reserved space: rows and header stay still throughout
-- flag transitions, including windows small enough to constrain the scale.
for _, size in ipairs({{572, 259}, {1040, 470}}) do
  windowW, windowH = size[1], size[2]
  for _, count in ipairs({5, 10}) do
    local rows = sampleRows(count, 'PRAC', 3)
    local reference = {}
    for _, flag in ipairs({'CLEAR', 'YELLOW', 'BLUE', 'RED', 'CLEAR'}) do
      texts, circles = {}, {}
      Display.draw({header = {typeLabel = 'PRAC', flagLabel = flag, flagRole = flag:lower()}, shownRows = rows},
        {hudScale = 0.84, maxRows = count, showFlags = true}, {palette = Theme.get('dark')})
      local found = 0
      for _, t in ipairs(texts) do
        if t.value == '--:--' or t.value:find('^DRIVER_') then
          found = found + 1
          local previous = reference[t.value]
          if previous then
            assert(t.pos.x == previous.pos.x and t.pos.y == previous.pos.y and t.size == previous.size,
              'flag strip must not move or rescale the leaderboard')
          else reference[t.value] = t end
        end
      end
      assert(found == count + 1)
    end
  end
end
print('Leaderboard flag transitions: reserved strip, stable header and rows passed')

-- FINISH uses the background color for its lettering, rather than drawing
-- the flag's own white on white (or charcoal on charcoal in the light theme).
windowW, windowH = 1040, 470
for _, theme in ipairs({'dark', 'light'}) do
  local palette = Theme.get(theme)
  texts, circles = {}, {}
  Display.draw({header = {typeLabel = 'RACE', flagLabel = 'FINISH', flagRole = 'white'}, shownRows = {compact}},
    {hudScale = 0.84, maxRows = 5, showFlags = true}, {palette = palette})
  local found = false
  for _, t in ipairs(texts) do
    if t.value:find('FINISH FLAG', 1, true) then
      found = true
      assert(t.color.r == palette.void.r and t.color.g == palette.void.g and t.color.b == palette.void.b,
        'FINISH lettering must use the background color')
      assert(contrast(t.color, palette.white) >= 4.5, 'FINISH lettering must contrast with the flag strip')
    end
  end
  assert(found, 'FINISH flag strip must be drawn')
end
print('Leaderboard FINISH flag: contrasting background-colored lettering passed in both themes')
