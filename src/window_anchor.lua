local M = {}

local states = {}
local lastPositions = {}
local rightClickConsumed = false

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

local function currentPosition()
  if type(ui.windowPos) ~= 'function' then return nil end
  local ok, position = pcall(ui.windowPos)
  if not ok or not position then return nil end
  local x, y = finite(position.x), finite(position.y)
  if not x or not y then return nil end
  return vec2(x, y)
end

local function currentSize()
  if type(ui.windowSize) == 'function' then
    local ok, size = pcall(ui.windowSize)
    if ok and size then return size end
  end
  if type(ui.windowWidth) == 'function' and type(ui.windowHeight) == 'function' then
    local ok, width, height = pcall(function() return ui.windowWidth(), ui.windowHeight() end)
    if ok then return vec2(width, height) end
  end
  return nil
end

local function mouseIsInside(position, size)
  if not size then return false end
  if type(ui.mouseLocalPos) == 'function' then
    local ok, mouse = pcall(ui.mouseLocalPos)
    if ok and mouse and mouse.x >= 0 and mouse.y >= 0
        and mouse.x <= size.x and mouse.y <= size.y then
      return true
    end
  end
  if not position or type(ui.mousePos) ~= 'function' then return false end
  local ok, mouse = pcall(ui.mousePos)
  return ok and mouse ~= nil and mouse.x >= position.x and mouse.y >= position.y
    and mouse.x <= position.x + size.x and mouse.y <= position.y + size.y
end

local function rightClicked()
  if type(ui.mouseClicked) ~= 'function' or not ui.MouseButton then return false end
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

function M.beginFrame()
  rightClickConsumed = false
end

function M.isAnchored(id)
  return M.initialize(id).anchored
end

function M.setAnchored(id, anchored)
  local state = M.initialize(id)
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
  return true
end

function M.begin(id)
  local state = M.initialize(id)
  local position = currentPosition()
  local size = currentSize()
  if position then lastPositions[id] = position end

  if not rightClickConsumed and rightClicked() and mouseIsInside(position, size) then
    rightClickConsumed = true
    if state.anchored then
      state.anchored = false
    elseif storePosition(state, position) then
      state.anchored = true
    end
  end

  if state.anchored then
    if state.x < 0 or state.y < 0 then
      if storePosition(state, position) then lastPositions[id] = position end
    end
    if state.x >= 0 and state.y >= 0 and type(ui.setNextWindowPosition) == 'function' then
      pcall(ui.setNextWindowPosition, vec2(state.x, state.y))
    end
    if type(ui.passthroughIMGUI) == 'function' then pcall(ui.passthroughIMGUI) end
  end
  return state.anchored
end

return M
