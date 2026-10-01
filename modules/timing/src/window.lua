local Window = {}
Window.__index = Window

local function numberOr(value, fallback)
  value = tonumber(value)
  return value or fallback
end

local function count0(values)
  if values == nil then return 0 end
  local ok, length = pcall(function() return #values end)
  if ok and type(length) == 'number' and length > 0 then return math.floor(length) end
  if type(values) ~= 'table' then return 0 end
  local count = 0
  for key, value in pairs(values) do
    if type(key) == 'number' and key >= 0 and value ~= nil then count = math.max(count, key + 1) end
  end
  return count
end

local function uiScale()
  local ok, info = pcall(ac.getUI)
  if ok and info then return math.max(0.1, numberOr(info.uiScale, 1)) end
  return 1
end

local function screenSize(fallback)
  local ok, sim = pcall(ac.getSim)
  if ok and sim then
    local width = numberOr(sim.windowWidth, 0)
    local height = numberOr(sim.windowHeight, 0)
    if width > 0 and height > 0 then return vec2(width, height) end
  end
  local okUI, info = pcall(ac.getUI)
  if okUI and info and info.windowSize then return info.windowSize end
  return fallback
end

function Window.new(title, sizeProvider, placement)
  return setmetatable({
    title = title,
    sizeProvider = sizeProvider,
    placement = placement,
    appWindow = nil,
    checkedAt = -10,
    lastScale = nil,
    lastRows = nil,
    lastAutoPlacement = false,
    lastLocked = nil,
    placementDirty = true
  }, Window)
end

function Window:find()
  local now = type(ui.time) == 'function' and ui.time() or 0
  if self.appWindow and now - self.checkedAt < 1 then return self.appWindow end
  self.checkedAt = now
  self.appWindow = nil
  local ok, windows = pcall(ac.getAppWindows)
  if not ok or windows == nil then return nil end
  for i = 0, count0(windows) - 1 do
    local item = windows[i]
    if item and (item.title == self.title or item.name == self.title) then
      local name = item.name
      if name then
        local accessOk, accessed = pcall(ac.accessAppWindow, name)
        if accessOk then self.appWindow = accessed end
      end
      break
    end
  end
  return self.appWindow
end

function Window:desiredSize(settings)
  local authored = self.sizeProvider(settings)
  local scale = settings.scale or 1
  return authored * (scale * uiScale())
end

function Window:position(size)
  local scale = uiScale()
  local screen = screenSize(size)
  local x, y
  if self.placement == 'top-right' then
    x = math.max(0, screen.x - size.x - 36)
    y = 62
  else
    x = math.max(0, (screen.x - size.x) / 2)
    y = 62
  end
  return vec2(x, math.max(0, y)) / scale
end

function Window:update(settings)
  local win = self:find()
  if not win then return end
  local scale = settings.scale or 1
  local rows = settings.rows
  local size = self:desiredSize(settings)
  if self.lastScale == nil or math.abs(self.lastScale - scale) > 0.001 or self.lastRows ~= rows then
    pcall(function() win:resize(size) end)
    self.lastScale, self.lastRows = scale, rows
    self.placementDirty = true
  end
  if settings.autoPlacement and (self.placementDirty or not self.lastAutoPlacement) then
    pcall(function() win:move(self:position(size)) end)
    self.placementDirty = false
  end
  self.lastAutoPlacement = settings.autoPlacement == true
  if self.lastLocked ~= settings.locked then
    pcall(function() win:setPinned(settings.locked == true) end)
    self.lastLocked = settings.locked == true
  end
end

function Window:invalidate()
  self.lastScale = nil
  self.lastRows = nil
  self.lastLocked = nil
  self.placementDirty = true
end

function Window:toggleLock(settings)
  settings.locked = not (settings.locked == true)
  self.lastLocked = nil
  self:update(settings)
end

return Window
