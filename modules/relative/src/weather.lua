local Weather = {}

local labels = {
  NoClouds = 'CLEAR', Clear = 'CLEAR', FewClouds = 'FEW CLOUDS',
  ScatteredClouds = 'SCATTERED', BrokenClouds = 'BROKEN CLOUDS',
  OvercastClouds = 'OVERCAST', Windy = 'WINDY', Cold = 'COLD', Hot = 'HOT',
  Fog = 'FOG', Mist = 'MIST', Haze = 'HAZE', Dust = 'DUST', Smoke = 'SMOKE',
  Sand = 'SAND', LightDrizzle = 'LIGHT DRIZZLE', Drizzle = 'DRIZZLE',
  HeavyDrizzle = 'HEAVY DRIZZLE', LightRain = 'LIGHT RAIN', Rain = 'RAIN',
  HeavyRain = 'HEAVY RAIN', LightThunderstorm = 'LIGHT STORM',
  Thunderstorm = 'STORM', HeavyThunderstorm = 'HEAVY STORM',
  LightSnow = 'LIGHT SNOW', Snow = 'SNOW', HeavySnow = 'HEAVY SNOW',
  LightSleet = 'LIGHT SLEET', Sleet = 'SLEET', HeavySleet = 'HEAVY SLEET',
  Squalls = 'SQUALLS', Tornado = 'TORNADO', Hurricane = 'HURRICANE', Hail = 'HAIL'
}

local function read(source, key)
  if source == nil then return nil end
  local ok, value = pcall(function() return source[key] end)
  return ok and value or nil
end

local function finite(value)
  value = tonumber(value)
  return value and value == value and value ~= math.huge and value ~= -math.huge and value or nil
end

local function temperature(value)
  value = finite(value)
  if value and value >= -100 and value <= 150 then return value end
  return nil
end

local function typeLabel(value, weatherTypes)
  if value == nil or weatherTypes == nil then return nil end
  for key, label in pairs(labels) do
    if read(weatherTypes, key) == value then return label end
  end
  return nil
end

function Weather.iconKind(label)
  if not label then return 'unknown' end
  if label == 'CLEAR' or label == 'HOT' then return 'sun' end
  if label == 'FEW CLOUDS' or label == 'SCATTERED' then return 'partly_cloudy' end
  if label:find('STORM', 1, true) or label == 'HAIL' or label == 'TORNADO'
      or label == 'HURRICANE' then return 'storm' end
  if label:find('RAIN', 1, true) or label:find('DRIZZLE', 1, true)
      or label == 'SQUALLS' then return 'rain' end
  if label:find('SNOW', 1, true) or label:find('SLEET', 1, true) then return 'snow' end
  if label == 'FOG' or label == 'MIST' or label == 'HAZE' or label == 'SMOKE'
      or label == 'DUST' or label == 'SAND' then return 'fog' end
  if label == 'WINDY' then return 'wind' end
  return 'cloud'
end

function Weather.snapshot(sim, conditions, weatherTypes)
  local currentType = read(conditions, 'currentType')
  local upcomingType = read(conditions, 'upcomingType')
  local rain = finite(read(conditions, 'rainIntensity') or read(sim, 'rainIntensity'))
  if rain then rain = math.max(0, math.min(1, rain)) end
  local current = typeLabel(currentType, weatherTypes)
  local upcoming = typeLabel(upcomingType, weatherTypes)
  return {
    current = current,
    upcoming = upcoming,
    currentIcon = Weather.iconKind(current),
    upcomingIcon = Weather.iconKind(upcoming),
    stable = current ~= nil and currentType == upcomingType,
    rain = rain,
    air = temperature(read(sim, 'ambientTemperature')),
    track = temperature(read(sim, 'roadTemperature') or read(sim, 'trackTemperature'))
  }
end

function Weather.temperatureText(value, unit)
  if value == nil then return '--' end
  if unit == 'F' then value = value * 9 / 5 + 32 end
  return string.format('%.0f', value) .. '\194\176' .. (unit == 'F' and 'F' or 'C')
end

function Weather.rainText(value)
  if value == nil then return '--' end
  return string.format('%.0f%%', value * 100)
end

return Weather
