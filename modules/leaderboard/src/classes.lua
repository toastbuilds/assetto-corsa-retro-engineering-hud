local Classes = {}
local ClassReset = require('src/class_reset')

Classes.colors = {
  GT4 = rgbm(0.28, 0.82, 0.52, 1), GT3 = rgbm(0.20, 0.64, 1.00, 1),
  TCR = rgbm(0.22, 0.83, 0.82, 1), CUP = rgbm(0.92, 0.92, 0.92, 1),
  UNKNOWN = rgbm(0.58, 0.60, 0.64, 1)
}

local known = {
  { 'hypercar', 'HY' }, { 'lmdh', 'HY' }, { 'lmh', 'HY' },
  { 'lmp1', 'LMP1' }, { 'lmp2', 'LMP2' }, { 'lmp3', 'LMP3' },
  { 'gt3', 'GT3' }, { 'gt4', 'GT4' }, { 'gte', 'GTE' },
  { 'tcr', 'TCR' }, { 'touring', 'TC' }, { ' cup', 'CUP' }
}

local mapping = nil
pcall(function() mapping = ac.INIConfig.load(__dirname .. '/../classes.ini') end)
local epochKey = 'retro-ui.leaderboard.classEpoch'

local function epoch()
  return tonumber(ac.storage[epochKey]) or 0
end

local function storageKey(id)
  local value = epoch()
  return value == 0 and ('retro-engineering-leaderboard.class.' .. tostring(id or ''))
    or ('retro-ui.leaderboard.class.' .. value .. '.' .. tostring(id or ''))
end

function Classes.resetAll()
  local ok, err = ClassReset.restore(__dirname .. '/..', 'Leaderboard', function()
    mapping = ac.INIConfig.load(__dirname .. '/../classes.ini')
    if not mapping then error('CSP did not load classes.ini') end
  end)
  if not ok then return false, err end
  ac.storage[epochKey] = epoch() + 1
  return true
end

function Classes.setOverride(id, classID)
  if id and id ~= '' then ac.storage[storageKey(id)] = classID end
end

function Classes.getOverride(id)
  if not id or id == '' then return nil end
  local value = ac.storage[storageKey(id)]
  return value and value ~= '' and value or nil
end

function Classes.detect(id, name, automatic)
  id, name = tostring(id or ''), tostring(name or '')
  local override = Classes.getOverride(id)
  if override then return override, 'OVERRIDE' end
  local exact = mapping and mapping:get('EXACT', id, '') or ''
  if exact ~= '' then return exact, 'MAPPING' end
  if automatic ~= true then return 'UNKNOWN', 'UNKNOWN' end
  local value = (id .. ' ' .. name):lower()
  for i = 1, #known do
    if value:find(known[i][1], 1, true) then return known[i][2], 'INFERRED' end
  end
  return 'UNKNOWN', 'UNKNOWN'
end

function Classes.display(classID)
  return classID and classID ~= 'UNKNOWN' and classID or '—'
end

return Classes
