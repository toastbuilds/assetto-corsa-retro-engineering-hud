package.path = './?.lua;./?/init.lua;' .. package.path
local carId, loads = 'pressure_test', 0
local ideals = {FRONT = 26.5, REAR = 27, FRONT_1 = 28}
ac = {
  getCarID = function() return carId end,
  INIConfig = {carData = function()
    loads = loads + 1
    return {get = function(_,section,key,default)
      assert(key == 'PRESSURE_IDEAL' and default == -1)
      return ideals[section] or default
    end}
  end}
}
local Readouts = require('src/tyre_readouts')
local car = {index=0,compoundIndex=0}
local result = Readouts.idealPressures(car)
assert(result.front == 26.5 and result.rear == 27)
Readouts.idealPressures(car)
assert(loads == 1, 'ideal references must be cached')
car.compoundIndex = 1
result = Readouts.idealPressures(car)
assert(result.front == 28 and result.rear == nil, 'never borrow another axle or compound pressure')
carId = 'blocked'
ac.INIConfig.carData = function() error('packed physics unavailable') end
assert(Readouts.idealPressures(car).front == nil)
assert(math.abs(Readouts.pressure(26,'bar') - 1.7926368954) < 0.00001)
assert(math.abs(Readouts.pressure(26,'kPa') - 179.26368954) < 0.00001)
assert(Readouts.temperature(80,'F') == 176)
local wheel = {available=true,pressure=27,idealPressure=26,wearAvailable=true,remaining=0.96,
  temperatureCore=80,temperatureInside=60,temperatureMiddle=70,temperatureOutside=80}
local text, unit = Readouts.wheel(wheel,{})
assert(text == '96' and unit == '%')
text, unit = Readouts.wheel(wheel,{numericMetric='pressure',pressureUnit='bar'})
assert(text == '1.86' and unit == 'bar')
assert(Readouts.wheel(wheel,{numericMetric='pressure',pressureReadout='delta'}) == '+1.0')
wheel.idealPressure=nil
assert(Readouts.wheel(wheel,{numericMetric='pressure',pressureReadout='delta'}) == '~+1.0')
assert(Readouts.numericTemperature(wheel,'surface') == 70)
assert(Readouts.numericTemperature(wheel,'blend',0.8) == 78)
assert(Readouts.wheel(wheel,{numericMetric='temperature',temperatureUnit='F'}) == '176')
wheel.temperatureCore=nil
assert(Readouts.numericTemperature(wheel,'core') == nil, 'core mode cannot silently show a surface reading')
assert(Readouts.numericTemperature(wheel,'blend',0.8) == nil, 'a blend needs its selected channels')
assert(Readouts.numericTemperature(wheel,'blend',0) == 70)
wheel.pressure=0/0
assert(Readouts.wheel(wheel,{numericMetric='pressure'}) == nil)
wheel.wearAvailable=false
assert(Readouts.wheel(wheel,{numericMetric='life'}) == nil)
local reference = Readouts.references({optimumTemperatureMin=78,optimumTemperatureMax=102,
  optimumTemperature=85,idealPressure=28},true,{},true)
assert(reference.minimum == 78 and reference.maximum == 102 and not reference.thermalEstimated
  and reference.idealPressure == 28 and not reference.pressureEstimated, 'real GT3 physics has priority')
reference = Readouts.references({optimumTemperature=95},false,{},true)
assert(reference.minimum == 90 and reference.maximum == 100 and reference.thermalEstimated)
reference = Readouts.references({},false,{fallbackPressureRear=30,fallbackTemperatureMin=70,fallbackTemperatureMax=82},false)
assert(reference.idealPressure == 30 and reference.minimum == 70 and reference.maximum == 82)
reference = Readouts.references({optimumTemperature=95},true,{},true)
assert(reference.minimum == 75 and reference.maximum == 85 and reference.thermalEstimated)
print('Tyre readouts: physics priorities, compound caches, units, metric selection, missing measurements and labelled estimates passed')
