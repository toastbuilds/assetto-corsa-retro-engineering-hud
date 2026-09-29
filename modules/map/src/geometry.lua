local M = {}

local state = {
  trackID = nil,
  points = nil,
  markers = nil,
  bounds = nil,
  nextRetry = 0
}

local function finite(value)
  return type(value) == 'number' and value == value and math.abs(value) < 10000000
end

local function trackID()
  local ok, value = pcall(ac.getTrackFullID, '/')
  if ok and value and value ~= '' then return value end
  ok, value = pcall(ac.getTrackName)
  return ok and value or ''
end

local function sample(spline)
  local ok, world = pcall(ac.trackCoordinateToWorld, vec3(0, 0, spline))
  if not ok or not world or not finite(world.x) or not finite(world.z) then return nil end
  return { x = world.x, z = world.z, spline = spline }
end

local function splitCount(splits)
  if not splits then return 0 end
  local ok, length = pcall(function() return #splits end)
  if ok and type(length) == 'number' then return math.max(0, math.min(20, math.floor(length))) end
  return 0
end

local function build(sim)
  local length = tonumber(sim and sim.trackLengthM) or 0
  local count = math.max(240, math.min(1800, math.floor(length / 12)))
  local points = {}
  for i = 0, count do
    local point = sample(i / count)
    if point then points[#points + 1] = point end
  end
  if #points < 20 then return false end

  local first, second = points[1], points[2]
  local headingX, headingZ = second.x - first.x, second.z - first.z
  local magnitude = math.sqrt(headingX * headingX + headingZ * headingZ)
  if magnitude < 0.001 then headingX, headingZ, magnitude = 0, 1, 1 end
  -- The starting tangent points upward in the full view; the rotation stays fixed.
  local cos = -headingZ / magnitude
  local sin = -headingX / magnitude
  local originX, originZ = first.x, first.z
  local bounds = { minX = math.huge, maxX = -math.huge, minY = math.huge, maxY = -math.huge }
  local function project(world)
    local dx, dz = world.x - originX, world.z - originZ
    return dx * cos - dz * sin, dx * sin + dz * cos
  end
  for _, point in ipairs(points) do
    point.u, point.v = project(point)
    bounds.minX = math.min(bounds.minX, point.u)
    bounds.maxX = math.max(bounds.maxX, point.u)
    bounds.minY = math.min(bounds.minY, point.v)
    bounds.maxY = math.max(bounds.maxY, point.v)
  end
  if bounds.maxX - bounds.minX < 1 or bounds.maxY - bounds.minY < 1 then return false end

  local markers = {}
  local splits = sim and sim.lapSplits
  local countSplits = splitCount(splits)
  if countSplits > 0 then
    for i = 0, countSplits - 1 do
      local ok, spline = pcall(function() return tonumber(splits[i]) end)
      if ok and spline and spline >= 0 and spline <= 1 then
        local marker = sample(spline)
        if marker then
          marker.u, marker.v = project(marker)
          marker.finish = i == 0
          marker.before = sample(math.max(0, spline - 0.001)) or points[1]
          marker.after = sample(math.min(1, spline + 0.001)) or points[2]
          markers[#markers + 1] = marker
        end
      end
    end
  end
  if #markers == 0 then
    -- Spline zero is the only reliable marker if the circuit has no split data.
    markers[1] = {
      x = first.x, z = first.z, u = first.u, v = first.v, finish = true,
      before = first, after = second
    }
  end

  local expectedStep = length > 0 and length / count or 20
  state.points = points
  state.markers = markers
  state.bounds = bounds
  state.gapLimit = math.max(60, expectedStep * 8)
  state.project = project
  return true
end

function M.ensure(sim)
  local id = trackID()
  if id ~= state.trackID then
    state.trackID = id
    state.points, state.markers, state.bounds, state.project = nil, nil, nil, nil
    state.nextRetry = 0
  end
  if state.points then return state end
  local now = ui.time()
  if now < state.nextRetry then return nil end
  state.nextRetry = now + 2
  local ok, ready = pcall(build, sim)
  return ok and ready and state or nil
end

function M.project(world)
  if not state.project or not world then return nil end
  if world.u and world.v then return world.u, world.v end
  local ok, x, y = pcall(state.project, world)
  if not ok or not finite(x) or not finite(y) then return nil end
  return x, y
end

function M.atSpline(spline)
  if not state.points or #state.points == 0 then return nil end
  spline = tonumber(spline)
  if not spline or spline ~= spline then return nil end
  spline = math.max(0, math.min(1, spline))
  local cursor = spline * (#state.points - 1) + 1
  local firstIndex = math.max(1, math.min(#state.points, math.floor(cursor)))
  local secondIndex = math.min(#state.points, firstIndex + 1)
  local first, second = state.points[firstIndex], state.points[secondIndex]
  local blend = cursor - firstIndex
  return {
    x = first.x + (second.x - first.x) * blend,
    z = first.z + (second.z - first.z) * blend,
    u = first.u + (second.u - first.u) * blend,
    v = first.v + (second.v - first.v) * blend
  }
end

function M.carPosition(car)
  if not car then return nil end
  local ok, spline = pcall(function() return car.splinePosition end)
  local onTrack = ok and M.atSpline(spline) or nil
  if onTrack then return onTrack end
  ok, spline = pcall(function() return car.position end)
  return ok and spline or nil
end

return M
