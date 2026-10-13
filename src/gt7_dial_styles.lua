-- Visual profiles for the compact speed and RPM dials in GT7.
-- They only describe face geometry; telemetry and dial composition stay shared.
local M = {}

M.analog = {
  {value='original', label='Original'},
  {value='shelf', label='Classic Shelf'},
  {value='fan', label='Fan'},
  {value='concentric', label='Concentric'},
  {value='spoke', label='Spoke'},
  {value='track_analog', label='Track'},
  {value='halo_analog', label='Halo'},
  {value='jewel_analog', label='Jewel'},
  {value='spectrum_analog', label='Spectrum'},
  {value='snap_analog', label='Snap Selector'}
}

M.digital = {
  {value='original', label='Original'},
  {value='bridge', label='Bridge'},
  {value='column', label='Column'},
  {value='radial', label='Radial'},
  {value='offset', label='Offset'},
  {value='orbit', label='Orbit'},
  {value='halo_digital', label='Halo'},
  {value='jewel_digital', label='Jewel'},
  {value='spectrum_digital', label='Spectrum'},
  {value='floating_capsule', label='Floating Capsule'},
  {value='snap_digital', label='Snap Selector'}
}

local profiles = {
  analog = {
    original = {first=140, last=400},
    shelf = {first=180, last=360},
    fan = {first=190, last=350, fan=true},
    concentric = {first=140, last=400},
    spoke = {first=180, last=360},
    track_analog = {first=190, last=350},
    halo_analog = {first=140, last=400},
    jewel_analog = {first=140, last=400},
    spectrum_analog = {first=160, last=380},
    snap_analog = {first=190, last=350}
  },
  digital = {
    original = {first=140, last=400},
    bridge = {first=190, last=350, bridge=true},
    column = {first=140, last=400, columns=true},
    radial = {first=190, last=350},
    offset = {first=180, last=360},
    orbit = {first=180, last=360},
    halo_digital = {first=140, last=400},
    jewel_digital = {first=140, last=400},
    spectrum_digital = {first=190, last=350},
    floating_capsule = {first=180, last=360},
    snap_digital = {first=190, last=350}
  }
}

local roleChoices = {}
local function allowed(value, mode, role)
  if not (role == 'speed' and value:match('^snap_')) then return true end
  return false
end

function M.choices(mode, role)
  mode = mode == 'analog' and 'analog' or 'digital'
  local list = mode == 'analog' and M.analog or M.digital
  if role ~= 'speed' then return list end
  local key = mode .. ':speed'
  if not roleChoices[key] then
    local filtered = {}
    for _, choice in ipairs(list) do
      if allowed(choice.value, mode, role) then filtered[#filtered + 1] = choice end
    end
    roleChoices[key] = filtered
  end
  return roleChoices[key]
end

function M.normalize(value, mode, role)
  for _, choice in ipairs(M.choices(mode, role)) do
    if choice.value == value then return value end
  end
  return 'original'
end

function M.get(value, mode, role)
  mode = mode == 'analog' and 'analog' or 'digital'
  value = M.normalize(value, mode, role)
  return profiles[mode][value]
end

return M
