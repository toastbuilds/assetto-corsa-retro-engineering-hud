local Presentation = require('src/instrument_state')
local Config = require('src/instrument_config')
local U = require('src/utils')
local M = {}
local vacuumSettings = { gt7SimulateVacuum = true, gt7VacuumMinimum = Config.vacuumMinimum }

function M.pressureText(valueBar, unit)
  local value = unit == 'psi' and valueBar * 14.5037738
    or unit == 'kPa' and valueBar * 100 or valueBar
  if math.abs(value) < 0.05 then value = 0 end
  return string.format(unit == 'kPa' and '%.0f' or '%.1f', value)
end

-- Same estimated vacuum branch as GT7. Positive boost stays measured in BAR;
-- conversion happens only for labels, leaving the bipolar scale unit independent.
function M.boost(state, unit)
  unit = unit or 'bar'
  local value, minimum, maximum, simulated = Presentation.boost(state, vacuumSettings)
  local available = state.available == true and state.turboAvailable == true
  return {
    available = available, value = value, minimum = minimum, maximum = maximum,
    simulated = available and simulated,
    zero = -minimum / (maximum - minimum),
    fraction = U.clamp((value - minimum) / (maximum - minimum), 0, 1),
    minimumText = M.pressureText(minimum, unit), maximumText = M.pressureText(maximum, unit),
    valueText = available and ((simulated and '~' or '') .. M.pressureText(value, unit) .. ' ' .. unit) or '—',
    unit = unit,
  }
end

function M.rpmMaximum(state)
  return math.max((state.rpmGaugeLimiter or state.rpmDisplayLimiter or 8000) / 1000, 1)
end

function M.rpmMarks(state)
  local maximum = M.rpmMaximum(state)
  local step = maximum <= 9 and 1 or maximum <= 18 and 2 or math.ceil(maximum / 8)
  local marks = {}
  for value = 0, maximum, step do marks[#marks + 1] = value end
  if marks[#marks] < maximum then marks[#marks + 1] = maximum end
  return marks
end

function M.rpmWarning(state)
  local maximum = M.rpmMaximum(state) * 1000
  return U.clamp((state.rpmDisplayLimiter or maximum) * (state.rpmWarningFraction or 0.86) / maximum, 0, 1)
end

return M
