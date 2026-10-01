local Geometry = require('modules/map/src/geometry')
local Settings = require('modules/map/src/settings')
local Theme = require('src/theme')
local GlobalSettings = require('src/general_settings')

local M = {}
local BOLD = 'Consolas;Weight=Bold'
local DOT_SPACING = 16
local DOT_RADIUS = 0.75
local SURFACE_STEPS = 48
local RIPPLE_DURATION = 2.2
local rippleFlag, rippleStartedAt

local function color(source, alpha)
  return Theme.withAlpha(source, alpha)
end

local function pointInRect(point, tl, br, margin)
  margin = margin or 0
  return point.x >= tl.x + margin and point.x <= br.x - margin
    and point.y >= tl.y + margin and point.y <= br.y - margin
end

local function markerPadding(values)
  return math.max(18, 16 * values.markerScale + 4,
    values.carDotSize + 4, 3.5 * values.pathWidth + 3)
end

local function keepMarkerInside(point, tl, br, padding)
  return vec2(
    math.max(tl.x + padding, math.min(br.x - padding, point.x)),
    math.max(tl.y + padding, math.min(br.y - padding, point.y)))
end

local function alertColor(sim, palette)
  local flag = tonumber(sim and sim.raceFlagType)
  if not flag then return nil, nil end
  local flags = ac.FlagType or {}
  if flag == 2 or flag == tonumber(flags.Caution) or flag == tonumber(flags.Yellow) then
    return flag, palette.flagYellow
  end
  if flag == 5 or flag == 8 or flag == tonumber(flags.Stop)
    or flag == tonumber(flags.ReturnToPits) or flag == tonumber(flags.Black)
    or flag == tonumber(flags.Penalty) then
    return flag, palette.red
  end
  if flag == 12 or flag == tonumber(flags.FasterCar) or flag == tonumber(flags.Blue) then
    return flag, palette.shiftBlue
  end
  return nil, nil
end

local function activeRipple(sim, palette)
  local flag, flagColor = alertColor(sim, palette)
  if not flag then
    rippleFlag, rippleStartedAt = nil, nil
    return nil, nil
  end
  local now = ui.time()
  if flag ~= rippleFlag or not rippleStartedAt or now < rippleStartedAt then
    rippleFlag, rippleStartedAt = flag, now
  end
  return flagColor, now - rippleStartedAt
end

local function smoothstep(value)
  value = math.max(0, math.min(1, value))
  return value * value * (3 - 2 * value)
end

local function drawRadialSurface(tl, br, palette, opacity)
  if opacity <= 0 then return end
  local side = br.x - tl.x
  local center = (tl + br) / 2
  local radius = side / 2
  local coveredOpacity = 0
  for step = SURFACE_STEPS - 1, 0, -1 do
    local targetOpacity = opacity * (1 - smoothstep(step / SURFACE_STEPS))
    -- Each circle overlaps the larger ones, so compensate for their accumulated alpha.
    local layerOpacity = (targetOpacity - coveredOpacity) / (1 - coveredOpacity)
    ui.drawCircleFilled(center, radius * (step + 1) / SURFACE_STEPS,
      color(palette.panel, layerOpacity), 96)
    coveredOpacity = targetOpacity
  end
end

local function drawDots(tl, br, palette, opacity, thickness, radialDotTaper, flagColor, rippleAge)
  if opacity <= 0 then return end
  local side = br.x - tl.x
  local fadeWidth = side * 0.2
  local centerX, centerY = (tl.x + br.x) / 2, (tl.y + br.y) / 2
  local radialExtent = side * math.sqrt(0.5)
  local rippleRadius = flagColor and ((rippleAge % RIPPLE_DURATION) / RIPPLE_DURATION)
    * side * (math.sqrt(0.5) + 0.08) or nil
  local bandWidth = side * 0.08
  local left = tl.x + DOT_SPACING / 2
  local top = tl.y + DOT_SPACING / 2
  for x = left, br.x - 6, DOT_SPACING do
    local edgeX = math.min(x - tl.x, br.x - x)
    for y = top, br.y - 6, DOT_SPACING do
      local edge = math.min(edgeX, y - tl.y, br.y - y)
      local edgeFade = smoothstep(edge / fadeWidth)
      if edgeFade > 0 then
        local wave = 0
        local dx, dy = x - centerX, y - centerY
        local distance
        if rippleRadius or radialDotTaper then
          distance = math.sqrt(dx * dx + dy * dy)
        end
        if rippleRadius then
          wave = smoothstep(1 - math.abs(distance - rippleRadius) / bandWidth)
        end
        local dotColor
        if wave > 0 then
          local base = palette.secondary
          dotColor = rgbm(
            base.r + (flagColor.r - base.r) * wave,
            base.g + (flagColor.g - base.g) * wave,
            base.b + (flagColor.b - base.b) * wave,
            math.min(1, opacity * (1 + 2 * wave)) * edgeFade)
        else
          dotColor = color(palette.secondary, opacity * edgeFade)
        end
        local radialScale = radialDotTaper and (1 - smoothstep(distance / radialExtent)) or 1
        local radius = DOT_RADIUS * thickness * radialScale
        if radius > 0.05 then
          ui.drawCircleFilled(vec2(x, y), radius, dotColor, 8)
        end
      end
    end
  end
end

local function viewFor(geometry, values, tl, br, player, padding)
  local width, height = br.x - tl.x, br.y - tl.y
  if values.mode == 'mini' and values.miniOrientation == 'fixed' and player then
    local playerPosition = Geometry.carPosition(player)
    local playerX, playerY = Geometry.project(playerPosition)
    if playerX then
      local scale = math.min(width, height) * 0.46 / values.miniRadius
      local center = vec2((tl.x + br.x) / 2, tl.y + height * 0.59)
      return function(world)
        local x, y = Geometry.project(world)
        if not x then return nil end
        return center + vec2(-(y - playerY) * scale, -(x - playerX) * scale)
      end
    end
  end
  if values.mode == 'mini' and values.miniOrientation ~= 'fixed'
    and player and player.position and player.look then
    local look = player.look
    local magnitude = math.sqrt(look.x * look.x + look.z * look.z)
    if magnitude > 0.001 then
      local hx, hz = look.x / magnitude, look.z / magnitude
      local scale = math.min(width, height) * 0.46 / values.miniRadius
      local center = vec2((tl.x + br.x) / 2, tl.y + height * 0.59)
      local playerPosition = Geometry.carPosition(player) or player.position
      return function(world)
        local dx, dz = world.x - playerPosition.x, world.z - playerPosition.z
        -- Reflect the car-centered view across its horizontal axis.
        return center + vec2((dz * hx - dx * hz) * scale, -(dx * hx + dz * hz) * scale)
      end
    end
  end
  local bounds = geometry.bounds
  local mapWidth, mapHeight = bounds.maxX - bounds.minX, bounds.maxY - bounds.minY
  -- Full map is rotated 90 degrees clockwise, so its fitted axes are swapped.
  local scale = math.min((width - 2 * padding) / mapHeight,
    (height - 2 * padding) / mapWidth)
  local middleX = (bounds.minX + bounds.maxX) / 2
  local middleY = (bounds.minY + bounds.maxY) / 2
  local center = (tl + br) / 2
  return function(world)
    local x, y = Geometry.project(world)
    if not x then return nil end
    local dx, dy = x - middleX, y - middleY
    return center + vec2(-dy * scale, dx * scale)
  end
end

local function strokeRoute(geometry, transform, strokeColor, width)
  local previous, count = nil, 0
  ui.pathClear()
  for _, world in ipairs(geometry.points) do
    local screen = transform(world)
    if previous then
      local dx, dz = world.x - previous.x, world.z - previous.z
      if dx * dx + dz * dz > geometry.gapLimit * geometry.gapLimit then
        if count > 1 then ui.pathStroke(strokeColor, false, width) end
        ui.pathClear()
        count = 0
      end
    end
    if screen then
      ui.pathLineTo(screen)
      count = count + 1
    end
    previous = world
  end
  if count > 1 then ui.pathStroke(strokeColor, false, width) end
end

local function drawRoute(geometry, transform, palette, pathWidth, flagColor)
  strokeRoute(geometry, transform, color(palette.void, 0.84), 7 * pathWidth)
  strokeRoute(geometry, transform, color(flagColor or palette.primary, 0.98), 3 * pathWidth)
end

local function drawSectors(geometry, transform, palette, tl, br)
  for _, marker in ipairs(geometry.markers) do
    local before = transform(marker.before)
    local after = transform(marker.after)
    local center = transform(marker)
    if before and after and center and pointInRect(center, tl, br, 8) then
      local tangent = after - before
      local length = math.sqrt(tangent.x * tangent.x + tangent.y * tangent.y)
      if length > 0.01 then
        local normal = vec2(-tangent.y / length, tangent.x / length)
        local halfLength = marker.finish and 8 or 5
        ui.drawLine(center - normal * halfLength, center + normal * halfLength,
          color(palette.void, 0.95), marker.finish and 5 or 4)
        ui.drawLine(center - normal * halfLength, center + normal * halfLength,
          color(marker.finish and palette.amber or palette.secondary, 1),
          marker.finish and 2.5 or 2)
      end
    end
  end
end

local function cars()
  local result = {}
  local seen = {}
  local function append(car)
    if not car then return end
    local ok, index = pcall(function() return tonumber(car.index) end)
    if not ok or not index or seen[index] then return end
    local connectedOk, connected = pcall(function() return car.isConnected end)
    local activeOk, active = pcall(function() return car.isActive end)
    if index == 0 or (connectedOk and connected ~= false) or (activeOk and active == true) then
      seen[index] = true
      result[#result + 1] = car
    end
  end
  local leaderboardOk = pcall(function()
    for _, car in ac.iterateCars.leaderboard() do append(car) end
  end)
  if not leaderboardOk or #result == 0 then
    pcall(function()
      for _, car in ac.iterateCars() do append(car) end
    end)
  end
  if not seen[0] then
    pcall(function() append(ac.getCar(0)) end)
  end
  return result
end

local function playerFrom(list)
  for _, car in ipairs(list) do
    if car.index == 0 then return car end
  end
  local ok, player = pcall(ac.getCar, 0)
  return ok and player or nil
end

local function isRace(sim)
  local ok, session = pcall(ac.getSession, sim.currentSessionIndex)
  return ok and session and session.type == ac.SessionType.Race
end

local function localCarIndex(car)
  if not car then return nil end
  local ok, index = pcall(function() return tonumber(car.index) end)
  return ok and index or nil
end

local function racePositions(list, race)
  local ordered = {}
  for i, car in ipairs(list) do ordered[i] = car end
  if race then
    table.sort(ordered, function(a, b)
      local aPos = tonumber(a.racePosition) or math.huge
      local bPos = tonumber(b.racePosition) or math.huge
      if aPos ~= bPos then return aPos < bPos end
      local aProgress = (tonumber(a.lapCount) or 0) + (tonumber(a.splinePosition) or 0)
      local bProgress = (tonumber(b.lapCount) or 0) + (tonumber(b.splinePosition) or 0)
      if aProgress ~= bProgress then return aProgress > bProgress end
      return (tonumber(a.index) or math.huge) < (tonumber(b.index) or math.huge)
    end)
  end
  local result = {}
  for rank, car in ipairs(ordered) do
    local index = localCarIndex(car)
    if index ~= nil then result[index] = rank end
  end
  return result, ordered
end

local function highlightedCars(list, player, race)
  local ranks, ordered = racePositions(list, race)
  local localIndex = localCarIndex(player)
  local localRank = localIndex and ranks[localIndex] or nil
  local selected = {}
  local function selectCar(car)
    local index = localCarIndex(car)
    if index ~= nil then selected[index] = ranks[index] end
  end
  if #ordered > 0 then
    selectCar(ordered[1])
    selectCar(ordered[#ordered])
  end
  if localIndex ~= nil then selected[localIndex] = ranks[localIndex] end
  if localRank then
    for rank = math.max(1, localRank - 2), math.min(#ordered, localRank + 2) do
      selectCar(ordered[rank])
    end
  end
  return selected
end

local function centeredText(value, size, center, textColor)
  value = tostring(value or '')
  ui.pushDWriteFont(BOLD)
  local measured = ui.measureDWriteText(value, size)
  ui.dwriteDrawText(value, size, center - measured / 2, textColor)
  ui.popDWriteFont()
end

local function drawPlayer(center, position, palette, markerScale)
  ui.drawCircleFilled(center, 16 * markerScale, color(palette.void, 0.92), 24)
  ui.drawCircleFilled(center, 12.5 * markerScale, color(palette.amber, 1), 24)
  centeredText(position, 13 * markerScale, center, color(palette.void, 1))
end

local function drawCars(list, player, transform, palette, tl, br, race,
    markerScale, carDotSize, padding)
  local selected = highlightedCars(list, player, race)
  local markers = {}
  local ownCenter, ownPosition
  for index, car in ipairs(list) do
    local world = Geometry.carPosition(car)
    if world and (car.index == 0 or car.isConnected ~= false or car.isActive == true) then
      local ok, screen = pcall(transform, world)
      local isLocal = car.index == 0
      local visible = ok and screen and pointInRect(screen, tl, br, 5)
      if visible then
        screen = keepMarkerInside(screen, tl, br, padding)
        local position = selected[localCarIndex(car)]
        if isLocal then
          ownCenter, ownPosition = screen, position
        else
          markers[#markers + 1] = {
            center = screen, position = position,
            highlighted = position ~= nil
          }
        end
      end
    end
  end
  if not ownCenter and player then
    local playerWorld = Geometry.carPosition(player)
    local ok, screen = pcall(transform, playerWorld)
    if ok and screen and pointInRect(screen, tl, br, 5) then
      ownCenter = keepMarkerInside(screen, tl, br, padding)
      ownPosition = selected[localCarIndex(player)]
    end
  end

  for _, marker in ipairs(markers) do
    local center = marker.center
    local highlighted = marker.highlighted
    if highlighted then
      ui.drawCircleFilled(center, 10.5 * markerScale, color(palette.void, 0.92), 20)
      ui.drawCircleFilled(center, 7.5 * markerScale, color(palette.cyan, 1), 20)
      centeredText(marker.position, 11 * markerScale, center, color(palette.void, 1))
    else
      ui.drawCircleFilled(center, carDotSize, color(palette.cyan, 1), 12)
    end
  end
  if ownCenter then drawPlayer(ownCenter, ownPosition, palette, markerScale) end
end

local function drawWindow()
  local values = Settings.current()
  local palette = Theme.get(GlobalSettings.values.theme)
  local origin = ui.getCursor()
  local size = ui.windowSize() - origin
  local side = math.min(size.x, size.y)
  if side < 80 then return end
  local tl = origin + (size - vec2(side, side)) / 2
  local br = tl + vec2(side, side)
  local sim = ac.getSim()
  local geometry = Geometry.ensure(sim)
  local flagColor, rippleAge = activeRipple(sim, palette)
  if values.backgroundMode == 'surface' then
    drawRadialSurface(tl, br, palette, GlobalSettings.background(0.45))
  else
    drawDots(tl, br, palette, GlobalSettings.background(0.12), values.dotThickness,
      values.radialDotTaper, flagColor, rippleAge)
  end
  if not geometry then
    ui.dwriteDrawText('MAP UNAVAILABLE', 12, tl + vec2(15, side / 2), color(palette.primary, 0.9))
    return
  end
  local list = cars()
  local player = playerFrom(list)
  local padding = markerPadding(values)
  local transform = viewFor(geometry, values, tl, br, player, padding)
  ui.pushClipRect(tl, br)
  local ok, err = pcall(function()
    drawRoute(geometry, transform, palette, values.pathWidth,
      values.backgroundMode == 'surface' and flagColor or nil)
    drawSectors(geometry, transform, palette, tl, br)
    drawCars(list, player, transform, palette, tl, br, isRace(sim),
      values.markerScale, values.carDotSize, padding)
  end)
  ui.popClipRect()
  if not ok then error(err) end
end

function M.windowMain()
  ui.pushStyleVarAlpha(GlobalSettings.values.opacity)
  local ok, err = pcall(drawWindow)
  ui.popStyleVar(1)
  if not ok then error(err) end
end

function M.windowSettings()
  Settings.draw()
end

return M
