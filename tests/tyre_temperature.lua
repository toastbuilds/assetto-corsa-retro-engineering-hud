package.path = './?.lua;./?/init.lua;' .. package.path

local function lut(points)
  return {
    getPointInput = function(_, index) return points[index + 1] and points[index + 1][1] or 0 / 0 end,
    getPointOutput = function(_, index) return points[index + 1] and points[index + 1][2] or 0 / 0 end
  }
end
local loads = 0
local carId = 'generic_test'
local curves = {
  THERMAL_FRONT = lut({ {60, 0.9}, {80, 1}, {100, 1}, {120, 0.9} }),
  THERMAL_REAR = lut({ {60, 0.9}, {75, 1}, {95, 1}, {110, 0.9} }),
  THERMAL_FRONT_1 = lut({ {70, 0.8}, {90, 1}, {110, 1}, {130, 0.8} })
}
ac = {
  getCarID = function() return carId end,
  INIConfig = { carData = function(index, filename)
    assert(index == 0 and filename == 'tyres.ini')
    loads = loads + 1
    return { tryGetLut = function(_, section, key)
      assert(key == 'PERFORMANCE_CURVE')
      return curves[section]
    end }
  end }
}
local Temperatures = require('src/tyre_temperature')
local loadConfig = ac.INIConfig.carData
local car = { index = 0, compoundIndex = 0 }
local windows = Temperatures.windows(car)
assert(math.abs(windows.front.minimum - 78) < 0.001
  and math.abs(windows.front.maximum - 102) < 0.001,
  'working window must include the interpolated 99% thermal grip region')
assert(windows.rear.minimum < 75 and windows.rear.maximum > 95,
  'rear axle must use its own performance curve')
Temperatures.windows(car)
assert(loads == 1, 'thermal data must be cached between frames')
car.compoundIndex = 1
windows = Temperatures.windows(car)
assert(loads == 2 and windows.front.minimum > 80 and windows.rear == nil,
  'compound changes must select the correct curve without borrowing from another axle')
carId = 'another_car'
Temperatures.windows(car)
assert(loads == 3, 'car changes must invalidate cached thermal data')
carId = 'missing_curve'
curves.THERMAL_FRONT_1 = nil
windows = Temperatures.windows(car)
assert(windows.front == nil and windows.rear == nil, 'missing curves must allow the telemetry fallback')
carId = 'broken_curve'
curves.THERMAL_FRONT_1 = lut({ {80, 1} })
assert(Temperatures.windows(car).front == nil, 'single-point curves cannot define a working window')
carId = 'blocked_data'
ac.INIConfig.carData = function() error('unavailable car physics data') end
assert(Temperatures.windows(car) == nil, 'unavailable packed car data must not break telemetry')
-- Exercise the complete telemetry path, including clearing stale compound data.
ac.INIConfig.carData = loadConfig
ac.getSim = function() return {} end
ac.getCar = function() return car end
carId, car.compoundIndex = 'telemetry_integration', 0
car.wheels = {}
for i = 0, 3 do
  car.wheels[i] = { tyreCoreTemperature = 80, tyreOptimumTemperature = 100, tyreWear = 0.1,
    tyreInsideTemperature = 90, tyreMiddleTemperature = 80, tyreOutsideTemperature = 65 }
end
local Telemetry = require('src/telemetry')
local state = Telemetry.new()
local settings = { speedUnit = 'km/h', fallbackRpm = 8000,
  rpmWarningFraction = 0.8, rpmRedlineFraction = 0.95, instrumentMode = 'digital' }
Telemetry.update(state, 1 / 60, settings)
assert(state.condition.wheels[1].temperature == 80
  and state.condition.wheels[1].temperatureCore == 80
  and state.condition.wheels[1].temperatureInside == 90
  and state.condition.wheels[1].temperatureMiddle == 80
  and state.condition.wheels[1].temperatureOutside == 65,
  'telemetry must preserve core and three surface temperatures separately')
assert(state.condition.wheels[1].optimumTemperatureMin == 78
  and state.condition.wheels[1].optimumTemperatureMax == 102,
  'compound working window must reach the UI wheel state')
assert(state.condition.wheels[3].optimumTemperatureMin < 75,
  'rear wheel telemetry must use the rear compound window')
car.compoundIndex = 1
car.wheels[0].tyreInsideTemperature = 0 / 0
car.wheels[0].tyreOutsideTemperature = math.huge
Telemetry.update(state, 1 / 60, settings)
assert(state.condition.wheels[1].temperatureInside == nil
  and state.condition.wheels[1].temperatureOutside == nil,
  'invalid surface readings must be cleared to allow a uniform fallback')
car.wheels[1] = nil
Telemetry.update(state, 1 / 60, settings)
assert(state.condition.wheels[2].temperatureMiddle == nil,
  'an unavailable wheel must clear its previous surface readings')
assert(state.condition.wheels[3].optimumTemperatureMin == nil,
  'changing compound must clear an unavailable rear window')
ac.getCar = function() return nil end
Telemetry.update(state, 1 / 60, settings)
assert(state.condition.wheels[1].optimumTemperatureMin == nil,
  'disconnecting must clear the previous working window')
assert(state.condition.wheels[1].temperatureMiddle == nil,
  'disconnecting must clear previous surface readings')
assert(state.condition.wheels[1].temperatureCore == nil, 'disconnecting must clear the previous core reading')
-- GT3 uses the requested 75-85 C profile even if the compound curve is wider.
carId, car.compoundIndex = 'cf_bentley_continental_gt3_2018', 0
local previousLoads = loads
windows = Temperatures.windows(car)
assert(windows.front.minimum == 75 and windows.front.maximum == 85
  and windows.rear.minimum == 75 and windows.rear.maximum == 85,
  'GT3 working window must be 75-85 C on both axles')
assert(loads == previousLoads, 'GT3 profile must override the broad physics curve')
ac.getCar = function() return car end
car.wheels[0].tyreCoreTemperature = 90
Telemetry.update(state, 1 / 60, settings)
assert(state.condition.wheels[1].temperature == 90
  and state.condition.wheels[1].optimumTemperatureMax == 85,
  '90 C GT3 telemetry must be above the optimal window')
-- Metadata identifies race cars whose IDs do not include their class.
ac.FolderID = { ContentCars = 1 }
ac.getFolder = function() return 'cars' end
io.load = function() return 'metadata' end
JSON = { parse = function() return { name = 'Audi R8 LMS', class = 'race', tags = { 'GT3' } } end }
carId = 'ks_audi_r8_lms_2016'
assert(Temperatures.windows(car).front.maximum == 85, 'GT3 metadata tags must select the profile')
JSON.parse = function() return { name = 'Porsche 911 GT3', class = 'street', tags = { 'street' } } end
carId = 'ks_porsche_991_gt3'
assert(Temperatures.windows(car).front.maximum == 102,
  'a street car named GT3 must retain the compound curve')
local general = Temperatures.generalTemperature
assert(math.abs(general({temperatureCore = 80, temperatureInside = 65,
  temperatureMiddle = 65, temperatureOutside = 65}) - 77) < 0.001,
  'general temperature must weight core 80% and the mean surface 20%')
assert(general({temperatureCore = 80}) == 80, 'missing surface must use the core')
assert(general({temperatureInside = 75, temperatureMiddle = 80, temperatureOutside = 85}) == 80,
  'missing core must use the surface average')
assert(general({temperatureCore = 80, temperatureInside = 0 / 0,
  temperatureMiddle = 70, temperatureOutside = math.huge}) == 78,
  'invalid samples must not enter the surface average')
assert(general({temperature = 70}) == 70 and general({}) == nil,
  'legacy fallback and fully missing temperatures must remain valid')
local zone = Temperatures.zoneTemperature
local blendedWheel = {temperatureCore = 80, temperatureInside = 50,
  temperatureMiddle = 65, temperatureOutside = 95}
assert(math.abs(zone(blendedWheel, 50) - 74) < 0.001
  and math.abs(zone(blendedWheel, 65) - 77) < 0.001
  and math.abs(zone(blendedWheel, 95) - 83) < 0.001,
  'each zone must blend its own surface sample with 80% core')
assert(math.abs((zone(blendedWheel, 50) + zone(blendedWheel, 65)
  + zone(blendedWheel, 95)) / 3 - general(blendedWheel)) < 0.001,
  'average of weighted zones must equal the uniform general temperature')
assert(zone({}, 65) == 65, 'missing core must preserve the real zone temperature')
assert(zone(blendedWheel, nil) == general(blendedWheel)
  and zone(blendedWheel, math.huge) == general(blendedWheel),
  'invalid or missing zone readings must use the general fallback')
print('Tyre temperature: working windows, axle separation, caching, compound changes and missing data passed')
