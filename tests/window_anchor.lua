package.path = './?.lua;./?/init.lua;' .. package.path

function vec2(x, y) return {x = x or 0, y = y or 0} end
local storage, positions, moves = {}, {}, {}
local sizes = {}
local clicked, mouse = false, vec2(20, 20)
local feedback = {}
local titles = {dial = 'Retro UI Dial', gt7 = 'Retro UI GT7'}
local available = {[0] = {name = 'dial-app', title = titles.dial},
  [1] = {name = 'gt7-app', title = titles.gt7}}
setmetatable(available, {__len = function() return 2 end})
if newproxy then
  local entries = available
  available = newproxy(true)
  getmetatable(available).__len = function() return 2 end
  getmetatable(available).__index = entries
end
local accessors = {}
for id in pairs(titles) do
  positions[id] = vec2(100, 200)
  sizes[id] = vec2(320, 100)
  accessors[id .. '-app'] = {
    position = function() return positions[id] end,
    size = function() return sizes[id] end,
    resize = function(_, size) sizes[id] = vec2(size.x, size.y) end,
    move = function(_, position)
      positions[id] = position
      moves[#moves + 1] = {id = id, position = position}
    end
  }
end
ac = {
  storage = function(defaults, key)
    if not storage[key] then storage[key] = defaults end
    return storage[key]
  end,
  getAppWindows = function() return available end,
  accessAppWindow = function(name) return accessors[name] end
}
ui = {
  MouseButton = {Right = 1},
  mouseClicked = function(button) return button == 1 and clicked end,
  mouseLocalPos = function() return mouse end,
  windowWidth = function() return 320 end,
  windowHeight = function() return 100 end,
  passthroughIMGUI = function() error('Locking must never enable mouse passthrough') end,
  setNextWindowPosition = function() error('Must move the actual app window') end
}
package.preload['ui/anchor_feedback'] = function()
  return {draw = function(_, anchored, age)
    feedback[#feedback + 1] = {anchored = anchored, age = age}
  end}
end

local Anchor = require('src/window_anchor')
local function frame(id, click, x, y)
  clicked, mouse = click, vec2(x or 20, y or 20)
  Anchor.beginFrame(0.016)
  Anchor.begin(id)
  Anchor.finish(id)
end

-- AppWindowAccessor works even when the IMGUI windowPos helper is unavailable.
frame('dial', true)
assert(Anchor.isAnchored('dial'), 'Right-click must lock without ui.windowPos')
assert(feedback[#feedback].anchored, 'Lock feedback should match the saved state')
positions.dial = vec2(400, 500)
sizes.dial = vec2(500, 300)
frame('dial', false)
assert(positions.dial.x == 100 and positions.dial.y == 200, 'Dragging must restore the saved position')
assert(sizes.dial.x == 320 and sizes.dial.y == 100, 'FIXED must prevent left-button resizing too')
positions.dial = vec2(700, 800)
Anchor.finish('dial')
assert(positions.dial.x == 100, 'Automatic placement during panel drawing must also be corrected')

assert(Anchor.acceptSize('dial', vec2(320, 264)))
sizes.dial = vec2(320, 264)
frame('dial', false)
assert(sizes.dial.y == 264 and positions.dial.y == 200,
  'A content-driven expansion preserves the locked position')
sizes.dial = vec2(500, 300)
frame('dial', false)
assert(sizes.dial.x == 320 and sizes.dial.y == 264,
  'Manual resizing remains blocked after an authorized content expansion')

frame('dial', true)
assert(not Anchor.isAnchored('dial'), 'A second right-click must unlock')
assert(not feedback[#feedback].anchored, 'Unlock must replace ongoing lock feedback immediately')
positions.dial = vec2(450, 550)
sizes.dial = vec2(400, 150)
frame('dial', false)
assert(positions.dial.x == 450, 'Unlocked windows must move freely')
assert(sizes.dial.x == 400, 'MOVE must allow resizing again')
frame('dial', true, -1, 20)
assert(not Anchor.isAnchored('dial'), 'Clicks outside the HUD must be ignored')

frame('dial', true)
Anchor.begin('gt7')
assert(not Anchor.isAnchored('gt7'), 'A click must only toggle one window per frame')
frame('gt7', true)
assert(Anchor.isAnchored('gt7') and Anchor.isAnchored('dial'), 'Each HUD has independent lock state')

-- Persisted coordinates survive a module reload.
package.loaded['src/window_anchor'] = nil
Anchor = require('src/window_anchor')
positions.dial = vec2(10, 10)
frame('dial', false)
assert(Anchor.isAnchored('dial') and positions.dial.x == 450 and positions.dial.y == 550,
  'Reload must restore the saved lock and its coordinates')

local count = #feedback
Anchor.beginFrame(2)
Anchor.finish('dial')
assert(#feedback == count, 'Expired feedback must stop drawing')
assert(Anchor.setAnchored('dial', false), 'Settings must also be able to unlock')
Anchor.finish('dial')
assert(not feedback[#feedback].anchored, 'Settings changes must get the same visual feedback')

local blocked = 0
ui.backupCursor = function() end
ui.restoreCursor = function() end
ui.setCursor = function() end
ui.invisibleButton = function() blocked = blocked + 1 end
ui.pushDisabled = function() error('Locking must not alter the HUD disabled style or opacity') end
ui.popDisabled = function() error('Locking must not alter the HUD disabled style or opacity') end
clicked = true
Anchor.beginFrame(0.016)
Anchor.draw('dial', function()
  assert(Anchor.isAnchored('dial'), 'FIXED must still be active while painting the HUD')
end)
assert(blocked == 1, 'FIXED must consume dragging without changing visual style')
clicked = false
local drew, message = pcall(Anchor.draw, 'dial', function() error('panel failure') end)
assert(not drew and tostring(message):find('panel failure'), 'Panel errors must still be reported')
clicked = true
Anchor.beginFrame(0.016)
Anchor.draw('dial', function()
  assert(not Anchor.isAnchored('dial'), 'Right-click must unlock before drawing controls')
end)
assert(blocked == 2 and not Anchor.isAnchored('dial'), 'MOVE must stop consuming left input')

-- Native CSP calls can be LuaJIT cdata; exercise the actual type when available.
local ok, ffi = pcall(require, 'ffi')
if ok then
  local nativeClick = ffi.cast('bool (*)(int)', function(button) return button == 1 and clicked end)
  ui.mouseClicked = nativeClick
  frame('dial', true)
  assert(Anchor.isAnchored('dial'), 'Native cdata mouseClicked must be accepted')
  nativeClick:free()
end

-- Exercise the real drawing code in both palettes at different HUD sizes.
local Vec = {}
Vec.__index = Vec
function Vec.__add(a, b) return vec2(a.x + b.x, a.y + b.y) end
function Vec.__sub(a, b) return vec2(a.x - b.x, a.y - b.y) end
function Vec.__mul(a, b) return vec2(a.x * b, a.y * b) end
function Vec.__div(a, b) return vec2(a.x / b, a.y / b) end
function vec2(x, y) return setmetatable({x = x or 0, y = y or 0}, Vec) end
local settings = {theme = 'dark', opacity = 1}
local palette = {amber = {}, cyan = {}, panel = {}}
package.loaded['src/theme'] = {
  get = function(name) assert(name == settings.theme); return palette end,
  withAlpha = function(_, alpha) assert(alpha >= 0 and alpha <= 1); return {alpha = alpha} end,
  fonts = {utility = 'Consolas'}
}
package.loaded['src/general_settings'] = {
  values = settings,
  background = function(alpha) return alpha * (settings.backgroundOpacity or 0.72) / 0.72 end
}
package.loaded['ui/anchor_feedback'] = nil
package.preload['ui/anchor_feedback'] = nil
local labels, fontDepth, feedbackBackgroundAlpha = {}, 0, nil
local function checkPoint(p)
  assert(p.x == p.x and p.y == p.y, 'Feedback geometry must remain finite')
end
ui.drawRectFilled = function(a, b, color)
  checkPoint(a); checkPoint(b)
  feedbackBackgroundAlpha = color.alpha
end
ui.drawLine = function(a, b) checkPoint(a); checkPoint(b) end
ui.drawCircleFilled = function(p) checkPoint(p) end
ui.pushDWriteFont = function() fontDepth = fontDepth + 1 end
ui.popDWriteFont = function() fontDepth = fontDepth - 1 end
ui.dwriteDrawText = function(label, _, p)
  checkPoint(p)
  labels[#labels + 1] = label
end
local DrawFeedback = require('ui/anchor_feedback')
for _, theme in ipairs({'dark', 'light'}) do
  settings.theme = theme
  for _, size in ipairs({vec2(120, 61), vec2(720, 360)}) do
    for _, age in ipairs({0, 0.12, 0.24, 0.9, 1.14}) do
      DrawFeedback.draw(size, true, age)
      assert(labels[#labels] == 'FIXED')
      DrawFeedback.draw(size, false, age)
      assert(labels[#labels] == 'MOVE')
      assert(fontDepth == 0, 'Feedback must restore the drawing font')
    end
  end
end

settings.backgroundOpacity = 0
DrawFeedback.draw(vec2(720, 360), true, 0.24)
assert(feedbackBackgroundAlpha == 0, 'Lock feedback must respect a fully transparent background')
settings.backgroundOpacity = 0.72

package.loaded['modules/delta/src/theme'] = {
  fonts = {utility = 'Consolas'}, blend = function(a) return a end,
  withAlpha = function(a) return a end
}
package.loaded['modules/delta/src/lap_data'] = {
  timeDeltaToString = function() return '0.00' end,
  lapTimeToString = function() return '0:00.000' end
}
local function noop() end
for _, name in ipairs({'pathClear', 'pathFillConvex', 'pathLineTo', 'pathStroke',
    'pushClipRect', 'popClipRect', 'pushStyleVarAlpha', 'popStyleVar'}) do ui[name] = noop end
ui.measureDWriteText = function(text, size) return vec2(#text * size * 0.5, size) end
ui.MouseButton.Left = 0
ui.mouseClicked = function(button) return button == 0 end
ui.mouseDown = function(button) return button == 0 end
ui.windowWidth = function() return 720 end
ui.windowHeight = function() return 180 end
ui.time = function() return 0 end
local colors = setmetatable({}, {__index = function() return {} end})
local DeltaDisplay = require('modules/delta/src/display')
Anchor.initialize('delta', {anchored = true, x = 100, y = 200})
for _, barOnly in ipairs({true, false}) do
  local y = barOnly and 110 or 96
  for _, side in ipairs({-1, 1}) do
    mouse = vec2(side == -1 and 25 or 695, y)
    local deltaSettings = {barOnly = barOnly, showDetails = false, scale = 1}
    Anchor.setAnchored('delta', true)
    local event = DeltaDisplay.draw({}, deltaSettings, {palette = colors})
    assert(event.modeDelta == 0, 'FIXED must ignore Delta mode arrow clicks')
    Anchor.setAnchored('delta', false)
    event = DeltaDisplay.draw({}, deltaSettings, {palette = colors})
    assert(event.modeDelta == side, 'MOVE must restore Delta mode arrow clicks')
  end
end
print('Window anchor: click toggle, position enforcement, persistence and feedback passed')
