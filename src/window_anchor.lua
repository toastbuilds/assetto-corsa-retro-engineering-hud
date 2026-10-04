local M = {}

local states = {}
local lastPositions = {}
local rightClickConsumed = false
local clock = 0
local feedback = {}
local windows = {}
local anchoredSizes = {}
local windowTitles = {
  dial = 'Retro UI Dial', gt7 = 'Retro UI GT7', condition = 'Retro UI Car Condition',
  relative = 'Retro UI Multiclass Relative', delta = 'Retro UI Delta Bar',
  timer = 'Retro UI Timer', laps = 'Retro UI Laps', leaderboard = 'Retro UI Leaderboard',
  telemetry = 'Retro UI Telemetry', map = 'Retro UI Map'
}

-- CSP exposes some native API calls as LuaJIT cdata, not Lua functions.
local function callable(value)
  return type(value) == 'function' or type(value) == 'cdata'
end

local function appWindow(id)
  local cached = windows[id]
  if cached and clock - cached.checkedAt < 1 then return cached.window end
  local window
  if callable(ac.getAppWindows) and callable(ac.accessAppWindow) then
    pcall(function()
      local available = ac.getAppWindows()
      for i = 0, #available - 1 do
        local item = available[i]
        if item and (item.title == windowTitles[id] or item.name == windowTitles[id]) then
          window = ac.accessAppWindow(item.name)
          break
        end
      end
    end)
  end
  windows[id] = { window = window, checkedAt = clock }
  return window
end

local function finite(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
  return value
end

local function stateFor(id)
  local state = states[id]
  if state then return state end

  local defaults = { anchored = false, x = -1, y = -1, initialized = false }
  local ok, stored = pcall(ac.storage, defaults, 'retro-ui.window-anchor.v1.' .. id)
  state = ok and type(stored) == 'table' and stored or defaults
  state.anchored = state.anchored == true
  state.x, state.y = finite(state.x) or -1, finite(state.y) or -1
  state.initialized = state.initialized == true
  states[id] = state
  return state
end

local function currentPosition(window)
  if window then
    local ok, position = pcall(function() return window:position() end)
    if ok and position and finite(position.x) and finite(position.y) then
      return vec2(position.x, position.y)
    end
  end
  if not callable(ui.windowPos) then return nil end
  local ok, position = pcall(ui.windowPos)
  if not ok or not position then return nil end
  local x, y = finite(position.x), finite(position.y)
  if not x or not y then return nil end
  return vec2(x, y)
end

local function currentSize()
  if callable(ui.windowSize) then
    local ok, size = pcall(ui.windowSize)
    if ok and size then return size end
  end
  if callable(ui.windowWidth) and callable(ui.windowHeight) then
    local ok, width, height = pcall(function() return ui.windowWidth(), ui.windowHeight() end)
    if ok then return vec2(width, height) end
  end
  return nil
end

local function mouseIsInside(position, size)
  if not size then return false end
  if callable(ui.mouseLocalPos) then
    local ok, mouse = pcall(ui.mouseLocalPos)
    if ok and mouse then
      return mouse.x >= 0 and mouse.y >= 0 and mouse.x < size.x and mouse.y < size.y
    end
  end
  if not position or not callable(ui.mousePos) then return false end
  local ok, mouse = pcall(ui.mousePos)
  return ok and mouse ~= nil and mouse.x >= position.x and mouse.y >= position.y
    and mouse.x <= position.x + size.x and mouse.y <= position.y + size.y
end

local function rightClicked()
  if not callable(ui.mouseClicked) or not ui.MouseButton then return false end
  local ok, clicked = pcall(ui.mouseClicked, ui.MouseButton.Right)
  return ok and clicked == true
end

local function storePosition(state, position)
  if not position then return false end
  state.x, state.y = position.x, position.y
  return true
end

function M.initialize(id, legacy)
  local state = stateFor(id)
  if state.initialized then return state end

  if legacy and legacy.anchored == true then
    state.anchored = true
    local x, y = finite(legacy.x), finite(legacy.y)
    if x and y and x >= 0 and y >= 0 then state.x, state.y = x, y end
  end
  state.initialized = true
  return state
end

function M.beginFrame(dt)
  rightClickConsumed = false
  -- Use UI time so feedback also completes while the simulation is paused.
  if callable(ac.getUI) then
    local ok, info = pcall(ac.getUI)
    if ok and info then dt = finite(info.dt) or dt end
  end
  clock = clock + math.max(0, finite(dt) or 0)
end

function M.isAnchored(id)
  return M.initialize(id).anchored
end

function M.setAnchored(id, anchored)
  local state = M.initialize(id)
  local wasAnchored = state.anchored
  if anchored == true then
    local position = lastPositions[id]
    if not position then
      local x, y = finite(state.x), finite(state.y)
      if x and y and x >= 0 and y >= 0 then position = vec2(x, y) end
    end
    if not position then return false end
    storePosition(state, position)
    state.anchored = true
  else
    state.anchored = false
  end
  if wasAnchored ~= state.anchored then
    anchoredSizes[id] = nil
    feedback[id] = { startedAt = clock, anchored = state.anchored }
  end
  return true
end

local function enforcePosition(id, state, position)
  if not state.anchored or state.x < 0 or state.y < 0 then return end
  local window = appWindow(id)
  if window then
    -- Window resize grips are handled outside the content item. Restore any
    -- left-button resize too, using accessor units for both reading and writing.
    local okSize, size = pcall(function() return window:size() end)
    if okSize and size then
      local saved = anchoredSizes[id]
      if not saved then
        anchoredSizes[id] = vec2(size.x, size.y)
      elseif math.abs(size.x - saved.x) > 0.1 or math.abs(size.y - saved.y) > 0.1 then
        pcall(function() window:resize(saved) end)
      end
    end
    if not position or math.abs(position.x - state.x) > 0.1 or math.abs(position.y - state.y) > 0.1 then
      local ok = pcall(function() window:move(vec2(state.x, state.y)) end)
      if not ok then windows[id] = nil end
    end
  end
end

function M.begin(id)
  local state = M.initialize(id)
  local position = currentPosition(appWindow(id))
  local size = currentSize()
  if position then lastPositions[id] = position end

  if not rightClickConsumed and rightClicked() and mouseIsInside(position, size) then
    rightClickConsumed = true
    M.setAnchored(id, not state.anchored)
  end

  if state.anchored then
    if state.x < 0 or state.y < 0 then
      if storePosition(state, position) then lastPositions[id] = position end
    end
    enforcePosition(id, state, position)
  end
  return state.anchored
end

function M.finish(id)
  local state = M.initialize(id)
  -- Panel drawing can also perform automatic placement; enforce after it too.
  enforcePosition(id, state, currentPosition(appWindow(id)))
  local event = feedback[id]
  if not event then return end
  local age = clock - event.startedAt
  if age >= 1.15 then feedback[id] = nil; return end
  require('ui/anchor_feedback').draw(currentSize(), event.anchored, age)
end

function M.draw(id, callback)
  local anchored = M.begin(id)
  if anchored and callable(ui.invisibleButton) and callable(ui.backupCursor)
      and callable(ui.restoreCursor) and callable(ui.setCursor) then
    local size = currentSize()
    if size then
      -- Consume left-button presses as an active IMGUI item, preventing the
      -- empty-window drag gesture. Right-click was handled before this item.
      ui.backupCursor()
      ui.setCursor(vec2(0, 0))
      ui.invisibleButton('##retro-ui-fixed-' .. id, size)
      ui.restoreCursor()
    end
  end
  -- Do not use pushDisabled around the painted HUD: it also changes its
  -- appearance. The input item above and custom control guards block clicks.
  local ok, err = pcall(callback)
  M.finish(id)
  if not ok then error(err, 0) end
end

return M
