local U = require('src/utils')
local M = {}
local cache = {}
local finite
local THRESHOLDS = { {name='HIGH', grip=100}, {name='MEDIUM', grip=98},
  {name='LOW', grip=96}, {name='EOL', grip=94} }

local function safe(object,key)
  local ok,value=pcall(function() return object and object[key] end)
  return ok and value or nil
end
finite=function(value)
  return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
end

local function loadCurve(config, axle, shortName, compound)
  local sections=safe(config,'sections')
  if type(sections)~='table' then
    if type(compound) ~= 'number' or compound < 0 then return nil end
    local suffix = compound > 0 and tostring(compound) or ''
    local ok,lut=pcall(function() return config:tryGetLut(axle .. (suffix~='' and '_' .. suffix or ''),'WEAR_CURVE') end)
    return ok and lut or nil
  end
  for name,data in pairs(sections) do
    local sectionAxle=tostring(name):upper():match('^(FRONT)') or tostring(name):upper():match('^(REAR)')
    local names=safe(data,'SHORT_NAME')
    local curveName=safe(safe(data,'WEAR_CURVE'),1)
    if sectionAxle==axle and type(names)=='table' and tostring(names[1])==shortName and curveName then
      local ok,lut=pcall(function() return config:tryGetLut(name,'WEAR_CURVE') end)
      if ok and lut then return lut end
    end
  end
  return nil
end

local function readCurves(car)
  local index=U.read(car,'index',0)
  local id=ac.getCarID and ac.getCarID(index) or nil
  local compound=U.read(car,'compoundIndex',nil)
  local shortName
  if ac.getTyresName then
    local ok,name=pcall(ac.getTyresName,index,compound)
    if ok then shortName=name end
  else
    shortName=compound and tostring(compound) or ''
  end
  if not id or not shortName then return nil end
  local key=table.concat({tostring(id),tostring(compound),tostring(shortName)},':')
  if cache[key]~=nil then return cache[key] or nil end
  local result={compound=shortName}
  if ac.INIConfig and ac.INIConfig.carData then
    local ok,config=pcall(ac.INIConfig.carData,index,'tyres.ini')
    if ok and config then
      for _,axle in ipairs({'FRONT','REAR'}) do
        local lut=loadCurve(config,axle,shortName,compound)
        if lut then
          local points={}
          local lastGrip=math.huge
          for i=0,1023 do
            local readOK,x,y=pcall(function() return lut:getPointInput(i),lut:getPointOutput(i) end)
            if not readOK or not finite(x) or not finite(y) then break end
            if y<=lastGrip then points[#points+1]={distance=x,grip=y} end
            lastGrip=y
          end
          if #points>=2 then result[axle]={lut=lut,points=points} end
        end
      end
    end
  end
  if not result.FRONT or not result.REAR then cache[key]=false; return nil end
  cache[key]=result
  return result
end

local function distanceAt(curve,target)
  local points=curve.points
  for i=2,#points do
    local before,after=points[i-1],points[i]
    if before.grip>=target and after.grip<=target then
      if before.grip==after.grip then return after.distance end
      local ratio=(before.grip-target)/(before.grip-after.grip)
      return before.distance+(after.distance-before.distance)*ratio
    end
  end
  if points[1].grip<target then return points[1].distance end
  if points[#points].grip>target then return points[#points].distance end
  return nil
end

function M.snapshot(car,sim)
  local curves=readCurves(car)
  if not curves then return nil end
  local rate=tonumber(safe(sim,'tyreConsumptionRate'))
  if not finite(rate) or rate==nil then rate=1 end
  local wearDisabled=rate<=0
  if wearDisabled then rate=0 end
  local distanceScale=wearDisabled and 0 or 10/rate -- CMRT threshold kilometres include consumption rate.
  local virtualScale=10 -- The tyre's live virtual distance uses the same factor as CMRT.
  local distances,progressThresholds={},{}
  local frontEol,rearEol=distanceAt(curves.FRONT,94),distanceAt(curves.REAR,94)
  if not frontEol or not rearEol or frontEol<=0 or rearEol<=0 then return nil end
  for _,threshold in ipairs(THRESHOLDS) do
    local front=distanceAt(curves.FRONT,threshold.grip)
    local rear=distanceAt(curves.REAR,threshold.grip)
    if not front or not rear then return nil end
    distances[threshold.name]=wearDisabled and nil or (front+rear)*0.5*distanceScale
    progressThresholds[threshold.name]=wearDisabled and 100
      or U.clamp(((1-front/frontEol)+(1-rear/rearEol))*50,0,100)
  end
  local wheelValues,remaining,distancesDriven={},{},{}
  local wheels=U.read(car,'wheels',nil)
  for i=0,3 do
    local wheel=U.read(wheels,i,nil)
    local virtualKm=U.read(wheel,'tyreVirtualKM',nil)
    local curve=curves[i<2 and 'FRONT' or 'REAR']
    if not finite(virtualKm) or virtualKm<0 then return nil end
    local distance=virtualKm*virtualScale
    local ok,grip=pcall(function() return curve.lut:get(distance) end)
    if not ok or not finite(grip) then return nil end
    wheelValues[#wheelValues+1]=grip
    distancesDriven[#distancesDriven+1]=distance
    local axleEol=i<2 and frontEol or rearEol
    remaining[#remaining+1]=wearDisabled and 100 or U.clamp(1-virtualKm*rate/axleEol,0,1)*100
  end
  local average=0
  for i=1,4 do average=average+wheelValues[i]/4 end
  local remainingAverage=0
  for i=1,4 do remainingAverage=remainingAverage+remaining[i]/4 end
  local trackKm=tonumber(safe(sim,'trackLengthM'))
  trackKm=trackKm and trackKm>0 and trackKm/1000 or nil
  local details={}
  for _,threshold in ipairs(THRESHOLDS) do
    local km=distances[threshold.name]
    details[#details+1]={name=threshold.name,grip=threshold.grip,km=km,
      laps=trackKm and km and km/trackKm or nil}
  end
  local shortName=curves.compound
  local compoundName=shortName
  if ac.getTyresLongName then
    local ok,name=pcall(ac.getTyresLongName,U.read(car,'index',0),U.read(car,'compoundIndex',nil))
    if ok and type(name)=='string' and name~='' then compoundName=name end
  end
  return {average=average,remaining=remainingAverage,thresholds=distances,
    progressThresholds=progressThresholds,
    details=details,compound=compoundName,virtualKm=distancesDriven,tyreGrips=wheelValues,
    wearDisabled=wearDisabled}
end

-- Compatibility for callers that only need the four-tyre arithmetic mean.
function M.average(car,sim)
  local result=M.snapshot(car,sim)
  return result and result.average or nil
end

return M
