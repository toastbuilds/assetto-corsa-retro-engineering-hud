-- Visual profiles for the compact speed and RPM dials in GT7.
-- They only describe face geometry; telemetry and dial composition stay shared.
local M = {}
local MiniProfiles = require('src/mini_dial_profiles')

M.auxiliary = {
  {value='original',label='Original'}, {value='match',label='Match main dial'},
  {value='halo',label='Halo'}, {value='jewel',label='Jewel'}, {value='spectrum',label='Spectrum'}
}
for _, choice in ipairs(MiniProfiles.choices) do M.auxiliary[#M.auxiliary+1] = choice end

local digitalAuxiliary
function M.auxiliaryChoices(mode)
  if mode~='digital' then return M.auxiliary end
  if not digitalAuxiliary then
    digitalAuxiliary={}
    for _,choice in ipairs(M.auxiliary) do
      local profile=MiniProfiles.get(choice.value)
      if not profile or profile.digital~=false then digitalAuxiliary[#digitalAuxiliary+1]=choice end
    end
  end
  return digitalAuxiliary
end

function M.normalizeAuxiliary(value,mode)
  for _,choice in ipairs(M.auxiliaryChoices(mode)) do
    if choice.value==value then return value end
  end
  return 'original'
end

function M.auxiliaryStyle(settings,rpm)
  if not M.canCustomizeAuxiliary(settings,rpm) then return 'original' end
  local selected=M.normalizeAuxiliary(settings[rpm and 'gt7RpmAuxiliaryStyle' or 'gt7SpeedAuxiliaryStyle'],
    settings[rpm and 'gt7RpmNeedleMode' or 'gt7SpeedNeedleMode'])
  if selected~='match' then return selected end
  local main=settings[rpm and 'gt7RpmDialStyle' or 'gt7SpeedDialStyle']
  for _,motif in ipairs({'halo','jewel','spectrum'}) do
    if main==motif..'_analog' or main==motif..'_digital' then return motif end
  end
  return 'original'
end

function M.canCustomizeAuxiliary(settings,rpm)
  local role=rpm and 'rpm' or 'speed'
  local face=M.get(settings[rpm and 'gt7RpmDialStyle' or 'gt7SpeedDialStyle'],
    settings[rpm and 'gt7RpmNeedleMode' or 'gt7SpeedNeedleMode'],role)
  return face.lowerArc~=true and face.lowerArc~=role
end

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
  {value='snap_digital', label='Snap Selector'}
}

local profiles = {
  analog = {
    original = {first=140, last=400},
    shelf = {first=180, last=360},
    fan = {first=190, last=350, fan=true, lowerArc=true},
    concentric = {first=140, last=400},
    spoke = {first=180, last=360},
    track_analog = {first=190, last=350, lowerArc=true},
    halo_analog = {first=140, last=400},
    jewel_analog = {first=140, last=400},
    spectrum_analog = {first=130, last=410},
    snap_analog = {first=190, last=350, lowerArc=true}
  },
  digital = {
    original = {first=140, last=400},
    bridge = {first=190, last=350, bridge=true, lowerArc=true},
    column = {first=140, last=400, columns=true},
    radial = {first=190, last=350, lowerArc=true},
    offset = {first=180, last=360},
    orbit = {first=180, last=360, lowerArc=true},
    halo_digital = {first=140, last=400},
    jewel_digital = {first=140, last=400},
    spectrum_digital = {first=130, last=410},
    snap_digital = {first=190, last=350, lowerArc=true}
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
