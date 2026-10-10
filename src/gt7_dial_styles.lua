-- Visual profiles for the compact speed and RPM dials in GT7.
-- They only describe face geometry; telemetry and dial composition stay shared.
local M = {}

M.analog = {
  {value='original', label='Original'},
  {value='shelf', label='Classic Shelf'},
  {value='fan', label='Fan'},
  {value='concentric', label='Concentric'},
  {value='spoke', label='Spoke'}
}

M.digital = {
  {value='original', label='Original'},
  {value='bridge', label='Bridge'},
  {value='column', label='Column'},
  {value='radial', label='Radial'},
  {value='offset', label='Offset'},
  {value='orbit', label='Orbit'}
}

local profiles = {
  analog = {
    original = {first=140, last=400},
    shelf = {first=180, last=360},
    fan = {first=190, last=350, fan=true},
    concentric = {first=140, last=400},
    spoke = {first=180, last=360}
  },
  digital = {
    original = {first=140, last=400},
    bridge = {first=190, last=350, bridge=true},
    column = {first=140, last=400, columns=true},
    radial = {first=190, last=350},
    offset = {first=180, last=360},
    orbit = {first=180, last=360}
  }
}

function M.normalize(value, mode)
  local allowed = mode == 'analog' and M.analog or M.digital
  for _, choice in ipairs(allowed) do
    if choice.value == value then return value end
  end
  return 'original'
end

function M.get(value, mode)
  mode = mode == 'analog' and 'analog' or 'digital'
  return profiles[mode][M.normalize(value, mode)]
end

return M
