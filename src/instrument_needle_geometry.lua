-- Built once when the catalog loads. All holes are tessellated empty space;
-- no surface-colored masks or concave CSP fills are needed.
local M = {}

-- Clip against each inward-offset edge. The resulting luminous core stays
-- inside the original convex material, including tessellated slotted blades.
function M.inset(points, margin)
  local result = points
  for i, a in ipairs(points) do
    local b = points[i % #points + 1]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0.000001 then
      local clipped = {}
      local function distance(p) return (dx * (p[2] - a[2]) - dy * (p[1] - a[1])) / length - margin end
      for j, p in ipairs(result) do
        local q = result[j % #result + 1]
        local dp, dq = distance(p), distance(q)
        if dp >= 0 then clipped[#clipped + 1] = p end
        if (dp >= 0) ~= (dq >= 0) then
          local t = dp / (dp - dq)
          clipped[#clipped + 1] = {p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t}
        end
      end
      result = clipped
      if #result < 3 then return nil end
    end
  end
  local area = 0
  for i, p in ipairs(result) do
    local q = result[i % #result + 1]
    area = area + p[1] * q[2] - q[1] * p[2]
  end
  return area > 0.000001 and result or nil
end
local function half(profile, x)
  for i = 2, #profile do
    local a, b = profile[i - 1], profile[i]
    if x <= b[1] then return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1]) end
  end
  return profile[#profile][2]
end

local function contour(profile)
  local points = {}
  for _, v in ipairs(profile) do points[#points + 1] = {v[1], -v[2]} end
  for i = #profile, 1, -1 do points[#points + 1] = {profile[i][1], profile[i][2]} end
  return points
end

local function polygon(g, points, role)
  local clean = {}
  for _, p in ipairs(points) do
    local last = clean[#clean]
    if not last or math.abs(p[1] - last[1]) + math.abs(p[2] - last[2]) > 0.000001 then
      clean[#clean + 1] = p
    end
  end
  local first, last = clean[1], clean[#clean]
  if #clean > 1 and math.abs(first[1] - last[1]) + math.abs(first[2] - last[2]) < 0.000001 then
    table.remove(clean)
  end
  local area = 0
  for i, p in ipairs(clean) do
    local q = clean[i % #clean + 1]
    area = area + p[1] * q[2] - q[1] * p[2]
  end
  if math.abs(area) < 0.000001 then return end
  if area < 0 then
    local reversed = {}
    for i = #clean, 1, -1 do reversed[#reversed + 1] = clean[i] end
    clean = reversed
  end
  g.polygons[#g.polygons + 1] = {points = clean, role = role}
end

local function outline(g, points, width, role, closed)
  g.outlines[#g.outlines + 1] = {points = points, width = width, role = role, closed = closed ~= false}
end

local function shape(g, profile, holes, border)
  if not holes or #holes == 0 then
    polygon(g, contour(profile))
    outline(g, contour(profile), border, 'edge')
    return
  end
  local xs = {}
  for _, p in ipairs(profile) do xs[#xs + 1] = p[1] end
  for _, hole in ipairs(holes or {}) do
    for _, p in ipairs(hole) do xs[#xs + 1] = p[1] end
  end
  table.sort(xs)
  for i = 2, #xs do
    local a, b = xs[i - 1], xs[i]
    if b - a > 0.000001 then
      local ha, hb = 0, 0
      for _, hole in ipairs(holes or {}) do
        if (a + b) / 2 > hole[1][1] and (a + b) / 2 < hole[#hole][1] then
          ha, hb = half(hole, a), half(hole, b)
        end
      end
      local wa, wb = half(profile, a), half(profile, b)
      if ha == 0 and hb == 0 then
        polygon(g, {{a, -wa}, {b, -wb}, {b, wb}, {a, wa}})
      else
        polygon(g, {{a, -wa}, {b, -wb}, {b, -hb}, {a, -ha}})
        polygon(g, {{a, ha}, {b, hb}, {b, wb}, {a, wa}})
      end
    end
  end
  outline(g, contour(profile), border, 'edge')
  for _, hole in ipairs(holes or {}) do
    outline(g, contour(hole), border, 'edge')
    g.outlines[#g.outlines].hole = true
  end
end

local function slot(a, b, w, tip)
  tip = tip or w
  return {{a, 0}, {a + w * 0.3, w * 0.72}, {a + w, w},
    {b - tip, tip}, {b - tip * 0.3, tip * 0.72}, {b, 0}}
end

local function roundHole(x, r)
  local points = {}
  for i = 0, 12 do
    local angle = math.pi * i / 12
    points[#points + 1] = {x - r * math.cos(angle), r * math.sin(angle)}
  end
  points[1][2], points[#points][2] = 0, 0
  return points
end

local function circle(g, x, radius, fill, role, width)
  g.circles[#g.circles + 1] = {x = x, radius = radius, fill = fill, role = role, width = width}
end

function M.build(p)
  local g = {polygons = {}, outlines = {}, circles = {}}
  local r, length, w, border = p.hubRadius, p.length, p.width / 2, p.borderWidth
  local start = r - 0.5
  local finish = length
  if p.tip == 'ring' then finish = length - p.tipRadius * 2 end
  if p.tip == 'arrow' or p.tip == 'diamond' then finish = length - p.tipLength end
  if p.body == 'outline' then
    outline(g, {{start, -w}, {finish, -p.tipWidth}, {finish, p.tipWidth}, {start, w}}, p.outlineWidth)
  elseif p.body == 'line' then
    outline(g, {{start, 0}, {finish, 0}}, p.width, nil, false)
  elseif p.body == 'lancet' then
    -- Concave shoulders are split into a convex blade and two small ears.
    polygon(g, contour({{start + 7, w}, {length, p.tipWidth}}))
    polygon(g, {{start, -w - 2}, {start + 7, -w}, {start + 7, 0}})
    polygon(g, {{start + 7, 0}, {start + 7, w}, {start, w + 2}})
    outline(g, {{start, -w - 2}, {start + 7, -w}, {length, -p.tipWidth},
      {length, p.tipWidth}, {start + 7, w}, {start, w + 2}}, border, 'edge', false)
  else
    local holes = {}
    if p.body == 'slot' or p.body == 'twin' then
      holes[1] = slot(start + 5, p.slotEnd or length * 0.78, p.slotWidth or w * 0.48, 0.55)
      if p.body == 'twin' then
        -- Separate short root window and long blade window, with a bridge.
        holes = {slot(start + 3, start + 14, 1.3),
          slot(start + 18, length * 0.80, w * 0.48, 0.55)}
      end
    end
    shape(g, {{start, w}, {finish, p.tipWidth}}, holes, border)
  end
  if p.tip == 'ring' then
    circle(g, length - p.tipRadius, p.tipRadius, false, nil, 1.6)
  elseif p.tip == 'arrow' then
    polygon(g, {{length - p.tipLength, -p.tipRadius}, {length, 0}, {length - p.tipLength, p.tipRadius}})
    outline(g, {{length - p.tipLength, -p.tipRadius}, {length, 0}, {length - p.tipLength, p.tipRadius}}, border, 'edge')
  elseif p.tip == 'diamond' then
    outline(g, {{length - p.tipLength, 0}, {length - p.tipLength / 2, -p.tipRadius},
      {length, 0}, {length - p.tipLength / 2, p.tipRadius}}, 1.5)
  end

  local tail, tw = p.counterweightLength, p.counterweightWidth / 2
  local stop = -r + 0.5
  local rear = p.counterweight
  if rear == 'block' then
    shape(g, {{-tail, tw}, {-tail + p.weightLength, tw}}, nil, border)
    shape(g, {{-tail + p.weightLength, 1}, {stop, 1}}, nil, border)
  elseif rear == 'paddle' then
    local profile = {}
    for i = 0, 6 do
      local a = math.pi * i / 12
      profile[#profile + 1] = {-tail + tw * (1 - math.cos(a)), tw * math.sin(a)}
    end
    profile[#profile + 1] = {stop, 1.5}
    shape(g, profile, nil, border)
  elseif rear == 'disc' then
    shape(g, {{-tail + tw, 1.2}, {stop, 1.2}}, nil, border)
    circle(g, -tail + tw, tw, true)
    circle(g, -tail + tw, tw, false, 'edge', border)
  elseif rear == 'polygon' then
    shape(g, {{-tail, tw * 0.45}, {-tail + 4, tw}, {-tail + 15, tw}, {stop, 2}}, nil, border)
  elseif rear == 'outline' then
    outline(g, {{-tail, -tw}, {stop, -tw * 0.4}, {stop, tw * 0.4}, {-tail, tw}}, p.outlineWidth)
  elseif rear == 'perforated' then
    local holes = {roundHole(-tail + 5, 2.6), roundHole(-tail + 14, 2.4), roundHole(-tail + 23, 2.2)}
    shape(g, {{-tail, tw}, {stop, tw * 0.65}}, holes, border)
  elseif rear == 'slot' then
    local holes = {slot(-tail + 2, stop - 3, tw * 0.52)}
    shape(g, {{-tail, tw}, {stop, tw * (p.tailTaper or 0.6)}}, holes, border)
  else
    shape(g, {{-tail, tw}, {stop, tw}}, nil, border)
  end
  if p.hubShape == 'faceted' then
    p.hubGeometry = {}
    for i = 0, 7 do
      local a = math.pi / 8 + i * math.pi / 4
      p.hubGeometry[#p.hubGeometry + 1] = {math.cos(a) * r, math.sin(a) * r}
    end
    p.hubMarker = {{-r * 0.95, -2.8}, {-r * 0.15, -2.8}, {-r * 0.15, 2.8}, {-r * 0.95, 2.8}}
  elseif p.hubShape == 'weight' then
    p.hubGeometry = {{-9, -6}, {8, -6}, {10, -4}, {10, 4}, {8, 6}, {-9, 6}, {-11, 4}, {-11, -4}}
  elseif p.hubShape == 'riveted' then
    p.hubRivets = {}
    for i = 0, 2 do
      local a = i * math.pi * 2 / 3
      p.hubRivets[#p.hubRivets + 1] = {math.cos(a) * r * 0.77, math.sin(a) * r * 0.77}
    end
  end
  g.cores = {}
  for _, part in ipairs(g.polygons) do
    local points = M.inset(part.points, p.coreInset)
    if points then g.cores[#g.cores + 1] = points end
  end
  p.geometry = g
  return p
end

return M
