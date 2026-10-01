-- Presentation only: the central layout and telemetry calibration stay intact.
local U = require('src/utils')
local M = {}
local cachedBase, cachedScale, cachedSpacing, cachedIndicators, cached

function M.resolve(base, settings)
  local factor = U.clamp(settings.gt7DialScale or 1, 0.75, 1.25)
  local spacing = U.clamp(settings.gt7DialSpacing or 0, 0, 160)
  local indicators = U.clamp(settings.gt7IndicatorScale or 1, 0.65, 1.5)
  if cachedBase == base and cachedScale == factor and cachedSpacing == spacing
      and cachedIndicators == indicators then return cached end
  local result = {}
  for key, value in pairs(base) do result[key] = value end
  local growth = base.dialRadius * (factor - 1)
  local offset = growth + spacing
  result.leftCenterX, result.rightCenterX = base.leftCenterX - offset, base.rightCenterX + offset
  result.instrumentScale = factor
  result.indicatorScale = indicators
  -- Keep the existing status pods clear of the enlarged instrument faces.
  result.statusY = math.max(443, base.dialCenterY + base.dialRadius * factor + 10) + 23 * (indicators - 1)
  if indicators > 1 then
    result.statusY = math.max(result.statusY, base.pedalTop + base.pedalHeight + 23 * indicators + 6)
  end
  if base.pedalPosition == 'outer' then
    result.brakeX, result.throttleX = base.brakeX - offset - growth, base.throttleX + offset + growth
  end
  local radius = base.dialRadius * factor + 7
  result.fitLeft = math.min(0, result.leftCenterX - radius, result.leftCenterX - 165 * indicators,
    result.brakeX - (base.pedalUpperExtraWidth or 0) - 7)
  result.fitRight = math.max(base.width, result.rightCenterX + radius, result.rightCenterX + 165 * indicators,
    result.throttleX + base.pedalWidth + (base.pedalUpperExtraWidth or 0) + 7)
  result.fitTop = math.min(0, base.dialCenterY - radius)
  result.fitBottom = math.max(base.height, result.statusY + 24 * indicators)
  -- Neutral settings retain the exact established fit.
  if factor == 1 and spacing == 0 and indicators == 1 then
    result.fitLeft, result.fitRight, result.fitTop, result.fitBottom = 0, base.width, 0, base.height
  end
  cachedBase, cachedScale, cachedSpacing, cachedIndicators, cached = base, factor, spacing, indicators, result
  return result
end

return M
