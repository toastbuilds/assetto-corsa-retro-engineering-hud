local Constants = {}

Constants.Modes = {
  SESSION_LAP = 0,
  SESSION_OPTIMAL = 1,
  FASTEST_LAP = 2,
  FASTEST_OPTIMAL = 3,
  PREVIOUS_LAP = 4,
  MULTIPLAYER_LAP = 5
}

Constants.ModeOrder = { 0, 1, 2, 3, 4, 5 }

Constants.ModeLabels = {
  [0] = 'SESSION  LAP',
  [1] = 'SESSION  OPTIMAL',
  [2] = 'FASTEST  LAP',
  [3] = 'FASTEST  OPTIMAL',
  [4] = 'PREVIOUS  LAP',
  [5] = 'MULTIPLAYER  LAP'
}

Constants.ModeShortLabels = {
  [0] = 'SESSION_LAP',
  [1] = 'SESSION_OPTIMAL',
  [2] = 'FASTEST_LAP',
  [3] = 'FASTEST_OPTIMAL',
  [4] = 'PREVIOUS_LAP',
  [5] = 'MULTIPLAYER_LAP'
}

Constants.Position = { TOP = 0, CENTER = 1, BOTTOM = 2 }

function Constants.isMode(value)
  return type(value) == 'number' and value >= 0 and value <= 5 and value == math.floor(value)
end

function Constants.normalizeMode(value, fallback)
  value = tonumber(value)
  if not Constants.isMode(value) then return fallback or Constants.Modes.SESSION_LAP end
  return value
end

return Constants
