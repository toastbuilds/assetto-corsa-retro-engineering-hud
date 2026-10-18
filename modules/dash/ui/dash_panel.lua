local Drawing = require('modules/dash/ui/drawing')
local Model = require('modules/dash/src/instruments')
local Icons = require('ui/instrument_icons')
local Config = require('src/instrument_config')
local PedalHistory = require('src/pedal_history')
local U = require('src/utils')
local M = {}

local function shell(c, topStyle)
  if topStyle then
    local fill = c:ink('panel', 0.78)
    c:frame(5, 25, 1270, 180, 17, fill)
    c:polygon({{334,25},{354,7},{926,7},{946,25}}, fill)
    c:polygon({{371,205},{389,216},{891,216},{909,205}}, fill)
    c:polygon({{5,42},{22,25},{334,25},{354,7},{926,7},{946,25},{1258,25},
      {1275,42},{1275,188},{1258,205},{909,205},{891,216},{389,216},{371,205},{22,205},{5,188}},
      nil, c:ink('outline', 0.9))
    c:line(69, 29, 327, 29, 'outlineSoft', 1)
    c:line(953, 29, 1211, 29, 'outlineSoft', 1)
    c:polygon({{69,37},{296,37},{284,44},{81,44}}, c:ink('metalDim', 0.45))
    c:polygon({{984,37},{1211,37},{1199,44},{996,44}}, c:ink('metalDim', 0.45))
  else
    c:frame(4, 8, 1272, 204, 22, c:ink('panel', 0.78), c:ink('outline', 0.85))
    c:line(302, 21, 302, 201, 'outlineDim')
    c:line(921, 21, 921, 201, 'outlineDim')
  end
end

local function verticalPedal(c, x, top, height, value, role, label, available)
  c:text(label, 10, x + 10, top - 15, role, 'center', 'label')
  c:frame(x, top, 20, height, 3, c:ink('void', 0.72), c:ink('outlineSoft', 0.8))
  local count, gap = 12, 2
  local blockHeight = (height - 6 - (count - 1) * gap) / count
  local filled = available and math.floor(U.clamp(value or 0, 0, 1) * count + 0.5) or 0
  for i = 1, count do
    c:rect(x + 3, top + height - 3 - i * blockHeight - (i - 1) * gap,
      14, blockHeight, i <= filled and role or 'inactive', 1, i <= filled)
  end
end

local function fuel(c, state, x, y, width, cyanFuel)
  local available = state.available and state.fuel ~= nil and state.maxFuel and state.maxFuel > 0
  local fraction = available and U.clamp(state.fuelNormalized or 0, 0, 1) or 0
  c:symbol(Icons.fuelIcon, x + 13, y + 31, 0.82, available and 'primary' or 'outlineDim', available)
  local left, barWidth = x + 42, width - 46
  c:text('E', 11, left, y + 4, 'secondary', nil, 'label')
  c:text('F', 11, left + barWidth, y + 4, 'secondary', 'right', 'label')
  c:frame(left - 4, y + 22, barWidth + 8, 20, 4, c:ink('void', 0.72), c:ink('outlineSoft'))
  for i = 1, 24 do
    local part = (i - 0.5) / 24
    local lit = available and part <= fraction
    local role = not lit and 'inactive' or fraction <= Config.fuelWarning and 'red'
      or (cyanFuel or part > 0.75) and 'cyan' or 'primary'
    c:rect(left + (i - 1) * barWidth / 24, y + 25, barWidth / 24 - 1.4, 14, role, 1, lit)
  end
  c:text('FUEL', 10, left + barWidth * 0.5, y + 46, 'secondary', 'center', 'label')
  c:text(available and string.format('%.1f L', state.fuel) or '—', 9, left + barWidth,
    y + 46, available and 'primary' or 'outlineDim', 'right')
end

local function boostBar(c, boost, x, y, width)
  c:symbol(Icons.boostIcon, x + 13, y + 31, 0.82,
    boost.available and 'primary' or 'outlineDim', boost.available)
  local left, barWidth = x + 42, width - 46
  c:text(boost.minimumText, 9, left, y + 4, 'secondary', nil, 'label')
  c:text('0', 9, left + barWidth * boost.zero, y + 4, 'primary', 'center', 'label')
  c:text(boost.maximumText, 9, left + barWidth, y + 4, 'secondary', 'right', 'label')
  c:frame(left - 4, y + 22, barWidth + 8, 20, 4, c:ink('void', 0.72), c:ink('outlineSoft'))
  for i = 1, 28 do
    local part = (i - 0.5) / 28
    local lit = boost.available and part >= math.min(boost.zero, boost.fraction)
      and part <= math.max(boost.zero, boost.fraction)
    local role = lit and (part < boost.zero and 'cyan' or 'primary')
      or part < boost.zero and 'cyanDim' or 'inactive'
    c:rect(left + (i - 1) * barWidth / 28, y + 25, barWidth / 28 - 1.3, 14, role, 1, lit)
  end
  c:line(left + barWidth * boost.zero, y + 20, left + barWidth * boost.zero, y + 43, 'primary', 1)
  c:text('BOOST / VAC', 10, left + barWidth * 0.38, y + 46, 'secondary', 'center', 'label')
  c:text(boost.valueText, 9, left + barWidth, y + 46,
    boost.available and 'primary' or 'outlineDim', 'right')
end

local function tcIcon(center, scale, color) Icons.statusIcon(center, scale, 1, color) end
local function absIcon(center, scale, color) Icons.statusIcon(center, scale, 2, color) end
local function limiterIcon(center, scale, color) Icons.statusIcon(center, scale, 4, color) end

local function statuses(state)
  local live, battery = state.available == true, state.hybrid and state.hybrid.charge
  return {
    {icon=Icons.fuelIcon, available=live and state.fuel~=nil,
      active=live and state.fuel~=nil and (state.fuelNormalized or 1)<=Config.fuelWarning, role='red'},
    {icon=tcIcon, available=live and state.tcSupported, active=live and state.tcActive, role='amber'},
    {glyph='PIT', available=live and (state.pitLaneAvailable or state.pitLimiter~=nil),
      active=live and (state.pitLane or state.pitLimiter), role='amber'},
    {icon=limiterIcon, available=live and state.pitLimiter~=nil, active=live and state.pitLimiter, role='amber'},
    {icon=Icons.lightIcon, available=live and state.lightsAvailable, active=live and state.headlights,
      role=state.highBeams and 'amber' or 'cyan'},
    {icon=absIcon, available=live and state.absSupported,
      active=live and (state.absActive or state.absLevel==0), role='amber'},
    {icon=Icons.engineIcon, available=live and state.engineLifeLeft~=nil, active=live and state.engineWarning, role='red'},
    {icon=Icons.batteryIcon, available=live and battery~=nil, active=live and battery~=nil and battery<=0.15,
      role='red', charge=battery},
  }
end

local function indicators(c, items, x, y, width, first, last)
  local spacing = width / (last - first + 1)
  local radius = math.min(19, spacing * 0.41)
  for i = first, last do
    local item = items[i]
    local centerX = x + (i - first + 0.5) * spacing
    local center = c:p(centerX, y)
    local role = not item.available and 'outlineDim' or item.active and item.role or 'secondary'
    if item.active then
      ui.drawCircleFilled(center, (radius + 4) * c.scale, c:ink(item.role, 0.05), 32)
      ui.drawCircleFilled(center, radius * c.scale, c:ink(item.role, 0.12), 32)
      ui.drawCircle(center, (radius - 2) * c.scale, c:ink(item.role, 0.18), 32, 3 * c.scale)
    else
      ui.drawCircleFilled(center, radius * c.scale, c:ink('panelRaised', 0.40), 32)
    end
    ui.drawCircle(center, radius * c.scale,
      c:ink(item.active and item.role or item.available and 'outlineSoft' or 'outlineDim'), 32,
      (item.active and 1.6 or 0.9) * c.scale)
    if item.icon then
      c:symbol(item.icon, centerX, y, radius / 23, role, item.available)
    else
      c:text(item.glyph, radius * 0.63, centerX, y - radius * 0.38, role, 'center', 'icon')
    end
    if item.charge ~= nil and item.available then
      c:text(string.format('%d%%', U.round(item.charge * 100)), 8, centerX, y - radius - 13,
        'secondary', 'center', 'label')
    end
  end
end

local function turnSignal(c, state, visual, x, y, left)
  local phase = true
  if visual.animateIndicators ~= false then
    if type(state.indicatorPhase) == 'boolean' then phase = state.indicatorPhase
    elseif type(state.indicatorPhase) == 'number' then phase = state.indicatorPhase > 0.5
    else phase = math.floor((state.clock or 0) / 0.4) % 2 == 0 end
  end
  local requested = state.hazardLights or (left and state.leftIndicator or not left and state.rightIndicator)
  local active = state.available and requested and phase
  local direction = left and -1 or 1
  if active then
    c:polygon({{x+direction*10,y},{x-direction*5,y-11},{x-direction*5,y+11}}, c:ink('amber',0.12))
  end
  c:polygon({{x+direction*7,y},{x-direction*4,y-8},{x-direction*4,y+8}},
    c:ink(active and 'amber' or 'outlineDim', 1, active and 'icon' or nil))
end

local function pedalGraph(c, state, x, y, width, height)
  c:frame(x, y, width, height, 4, c:ink('void', 0.55), c:ink('outlineDim'))
  c:text('PEDALS', 9, x + 7, y + 3, 'secondary', nil, 'label')
  c:line(x + width - 76, y + 8, x + width - 65, y + 8, 'red', 1.5)
  c:text('BRK', 7, x + width - 61, y + 4, 'red')
  c:line(x + width - 38, y + 8, x + width - 27, y + 8, 'cyan', 1.5)
  c:text('THR', 7, x + width - 23, y + 4, 'cyan')
  local left, top, plotWidth, plotHeight = x + 8, y + 15, width - 16, height - 19
  for i = 1, 7 do c:line(left + plotWidth * i / 8, top, left + plotWidth * i / 8,
    top + plotHeight, 'outlineDim', 0.6, 0.6) end
  c:line(left, top + plotHeight, left + plotWidth, top + plotHeight, 'outlineSoft', 0.8)
  local history = state.pedalHistory
  if not state.available or not history or history.count < 2 then return end
  for _, trace in ipairs({{key='brake',role='red'},{key='throttle',role='cyan'}}) do
    ui.pathClear()
    local first = math.max(0, history.count - 90)
    for ordinal = first, history.count - 1 do
      local sample = PedalHistory.sampleAt(history, ordinal)
      ui.pathLineTo(c:p(left + (ordinal-first) / (history.count-first-1) * plotWidth,
        top + (1-U.clamp(sample[trace.key] or 0,0,1)) * plotHeight))
    end
    ui.pathStroke(c:ink(trace.role, 1, 'segment'), false, 1.5 * c.scale)
  end
end

local function rpmBar(c, state)
  local x, y, width, count = 402, 32, 476, 58
  local maximum = Model.rpmMaximum(state)
  for _, value in ipairs(Model.rpmMarks(state)) do
    local progress = value / maximum
    local label = math.abs(value-math.floor(value)) < 0.01 and tostring(math.floor(value)) or string.format('%.1f',value)
    c:text(label, 11, x + width*progress, 11, 'primary', 'center', 'number')
    c:line(x+width*progress, 25, x+width*progress, 29, 'secondary', 1)
  end
  c:text('RPM', 8, 930, 13, 'secondary', 'center', 'label')
  local fraction = state.available and U.clamp(state.rpmGaugeNormalized or 0,0,1) or 0
  local warning = Model.rpmWarning(state)
  for i = 1, count do
    local t = (i-0.5)/count
    local active = state.available and t <= fraction
    local role = active and (t >= warning and 'red' or 'primary') or t >= warning and 'redDim' or 'inactive'
    c:rect(x+(i-1)*width/count, y, width/count-1.5, 22, role, 1, active)
  end
  c:line(x, 57, x+width, 57, 'outlineSoft')
  for _, side in ipairs({-1,1}) do
    local endX = side < 0 and x-7 or x+width+7
    c:polygon({{endX+side*9,31},{endX,43},{endX+side*7,43},{endX+side*16,31}}, c:ink('amberDim',0.9))
    c:polygon({{endX,43},{endX+side*9,55},{endX+side*16,55},{endX+side*7,43}}, c:ink('amberDim',0.9))
    c:line(endX+side*20, 43, endX+side*35, 43, 'outlineSoft', 1.2)
  end
end

local function rpmTop(c, state, settings, visual, boost, items)
  shell(c, true)
  verticalPedal(c, 18, 29, 171, state.brake, 'red', 'BRK', state.available)
  verticalPedal(c, 1242, 29, 171, state.throttle, 'cyan', 'THR', state.available)
  rpmBar(c, state)
  fuel(c, state, 67, 72, 248)
  boostBar(c, boost, 964, 72, 248)
  c:line(57, 141, 327, 141, 'outlineSoft')
  c:line(953, 141, 1223, 141, 'outlineSoft')
  c:frame(411, 65, 458, 91, 23, c:ink('panelRaised',0.38), c:ink('outline'))
  c:line(658, 76, 658, 145, 'outlineSoft')
  c:text(state.available and state.speedText or '—', 71, 536, 60, 'primary', 'center', 'value')
  c:text(state.speedUnit or visual.speedUnit or 'km/h', 12, 536, 133, 'secondary', 'center', 'label')
  c:text(state.available and state.gearText or '—', 71, 762, 60, 'primary', 'center', 'value')
  c:text('GEAR', 11, 762, 134, 'secondary', 'center', 'label')
  turnSignal(c,state,visual,393,111,true)
  turnSignal(c,state,visual,887,111,false)
  c:line(327, 68, 388, 157, 'outlineSoft')
  c:line(892, 157, 953, 68, 'outlineSoft')
  if settings.rpmTopShowPedals then pedalGraph(c,state,467,166,346,43) end
  if settings.rpmTopShowIndicators then
    indicators(c,items,64,178,260,1,4)
    indicators(c,items,956,178,260,5,8)
  end
end

local function tachometer(c, state, boost)
  local cx, cy, rx, ry = 1094, 190, 166, 163
  local first, last = math.rad(190), math.rad(350)
  c:ellipse(cx,cy,rx+4,ry+4,first,last,'outline',1.2)
  c:ellipse(cx,cy,rx-13,ry-13,first,last,'outlineDim',0.8)
  local fraction = state.available and U.clamp(state.rpmGaugeNormalized or 0,0,1) or 0
  local count = 64
  local warning = Model.rpmWarning(state)
  for i = 1, count do
    local t = (i-0.5)/count
    local a, b = first+(last-first)*(i-1+0.13)/count, first+(last-first)*(i-0.13)/count
    local active = state.available and t <= fraction
    local role = active and (t>=warning and 'red' or 'primary') or t>=warning and 'redDim' or 'inactive'
    c:arcBlock(cx,cy,rx,ry,9,a,b,role,active)
  end
  local maximum = Model.rpmMaximum(state)
  for _, value in ipairs(Model.rpmMarks(state)) do
    local t = value / maximum
    local a = first+(last-first)*t
    c:line(cx+math.cos(a)*(rx-3),cy+math.sin(a)*(ry-3),
      cx+math.cos(a)*(rx-20),cy+math.sin(a)*(ry-20),'primary',1.4)
    c:text(math.abs(value-math.floor(value))<0.01 and tostring(math.floor(value)) or string.format('%.1f',value),
      15,cx+math.cos(a)*(rx-34),cy+math.sin(a)*(ry-34)-8,'primary','center','number')
  end
  c:text('x1000 RPM', 10, cx, 100, 'secondary', 'center', 'label')
  local bx, by, brx, bry = cx, 210, 84, 69
  c:ellipse(bx,by,brx+5,bry+5,first,last,'outlineSoft',1)
  for i=1,30 do
    local t=(i-0.5)/30
    local active=boost.available and t>=math.min(boost.zero,boost.fraction) and t<=math.max(boost.zero,boost.fraction)
    local role=active and (t<boost.zero and 'cyan' or 'primary') or t<boost.zero and 'cyanDim' or 'inactive'
    c:arcBlock(bx,by,brx,bry,6,first+(last-first)*(i-1+0.13)/30,
      first+(last-first)*(i-0.13)/30,role,active)
  end
  local zeroAngle=first+(last-first)*boost.zero
  c:line(bx+math.cos(zeroAngle)*(brx-4),by+math.sin(zeroAngle)*(bry-4),
    bx+math.cos(zeroAngle)*(brx-14),by+math.sin(zeroAngle)*(bry-14),'primary',1.2)
  c:text(boost.minimumText,9,bx-65,194,'secondary','center','label')
  c:text('0',9,bx+math.cos(zeroAngle)*(brx-18),by+math.sin(zeroAngle)*(bry-18)-7,'primary','center','label')
  c:text(boost.maximumText,9,bx+65,194,'secondary','center','label')
  c:text(boost.valueText,10,bx,164,boost.available and 'cyan' or 'outlineDim','center','label')
  c:symbol(Icons.boostIcon,bx,190,0.50,boost.available and 'primary' or 'outlineDim',boost.available)
  c:text('BOOST / VAC',9,bx,204,'secondary','center','label')
end

local function sideTach(c, state, settings, visual, boost, items)
  shell(c,false)
  fuel(c,state,25,38,256,true)
  c:line(25,126,286,126,'outlineSoft')
  verticalPedal(c,313,28,176,state.brake,'red','BRK',state.available)
  verticalPedal(c,888,28,176,state.throttle,'cyan','THR',state.available)
  c:line(353,22,864,22,'outlineSoft',1.2)
  c:polygon({{354,20},{365,20},{372,23},{361,23}},c:ink('amber'))
  c:polygon({{845,20},{864,20},{857,23},{838,23}},c:ink('amber'))
  c:text(state.available and state.speedText or '—',87,484,20,'primary','center','value')
  c:text(state.speedUnit or visual.speedUnit or 'km/h',18,581,77,'secondary',nil,'label')
  c:frame(674,29,174,80,17,c:ink('panelRaised',0.32),c:ink('outlineSoft'))
  c:text(state.available and state.gearText or '—',82,733,18,'primary','center','value')
  c:text('GEAR',11,811,79,'secondary','center','label')
  c:line(354,108,366,120,'outlineSoft',1.2)
  c:line(366,120,477,120,'outlineSoft',1.2)
  c:line(785,120,855,120,'outlineSoft',1.2)
  c:line(855,120,866,108,'outlineSoft',1.2)
  if settings.sideShowSteering then
    local available=state.available and state.steeringAvailable
    local steer=available and U.clamp(state.steeringInput or 0,-1,1) or 0
    c:line(560,124,652,124,'outlineSoft',2)
    c:line(606,120,606,128,'secondary',1)
    if available then ui.drawCircleFilled(c:p(606+steer*43,124),3.5*c.scale,c:ink('cyan',1,'icon'),20)
    else c:text('—',10,606,116,'outlineDim','center') end
    c:text('STEER',9,606,131,'secondary','center','label')
  end
  turnSignal(c,state,visual,534,124,true)
  turnSignal(c,state,visual,678,124,false)
  if settings.sideShowPedals then
    local y=settings.sideShowSteering and 153 or 137
    pedalGraph(c,state,356,y,509,205-y)
  end
  if settings.sideShowIndicators then indicators(c,items,27,176,260,1,8) end
  tachometer(c,state,boost)
end

function M.draw(state, settings, visual)
  state=state or {}
  local c=Drawing.new(ui.windowWidth(),ui.windowHeight(),visual)
  local boost=Model.boost(state,visual.pressureUnit)
  local items=statuses(state)
  ui.pushStyleVarAlpha(visual.contentOpacity or 1)
  ui.pushDWriteFont('Consolas;Weight=Regular')
  if settings.style=='side-tach' then sideTach(c,state,settings,visual,boost,items)
  else rpmTop(c,state,settings,visual,boost,items) end
  ui.popDWriteFont()
  ui.popStyleVar(1)
end

return M
