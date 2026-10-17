local U = require('src/utils')
local M = {}
local RANGE, REFERENCE_RANGE, MIN_SPEED = 120, 240, 60
local ALIGNMENT = math.cos(math.rad(20))

local function number(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value or nil
end

local function field(object, key, fallback) return U.read(object, key, fallback) end
local function components(vector)
  return number(field(vector, 'x')), number(field(vector, 'y')), number(field(vector, 'z'))
end
local function direction(car)
  local x,y,z = components(field(car, 'look'))
  if not x or not y or not z then return end
  local length = math.sqrt(x*x+y*y+z*z)
  if length < 0.1 then return end
  local vx,vy,vz = components(field(car,'velocity'))
  if vx and vy and vz then
    local movement = math.sqrt(vx*vx+vy*vy+vz*vz)
    if movement > 1 and (vx*x+vy*y+vz*z)/(movement*length) < 0.5 then return end
  end
  return x/length,y/length,z/length
end
local function speed(car)
  return number(field(car, 'speedKmh')) or (number(field(car, 'speedMs')) or 0)*3.6
end
local function size(car, axis, fallback)
  return math.max(0.5, number(field(field(car, 'aabbSize'), axis)) or fallback)
end
local function pit(car)
  return field(car,'isInPit') == true or field(car,'isInPitlane') == true
end

function M.reset(state)
  state.slipstream = {available=false, intensity=0, source='unavailable'}
  state._slipstreamRuntime = nil
end

local function geometry(car, sim, runtime, px, py, pz, fx, fy, fz)
  local horizontal = math.sqrt(fx*fx+fz*fz)
  if horizontal < 0.1 then return nil end
  local sx,sz = -fz/horizontal,fx/horizontal
  local ux,uy,uz = -fx*fy/horizontal,horizontal,-fz*fy/horizontal
  local ownLength, ownWidth = size(car,'z',4.5),size(car,'x',1.9)
  local index = field(car,'index',0)
  local best, target, distance, clear = 0,nil,nil,true
  local online = field(sim,'isOnlineRace') == true and field(sim,'isReplayActive') ~= true
  local present = {}
  local ok = pcall(function()
    for _, other in ac.iterateCars() do
      local otherIndex = field(other,'index',-1)
      if otherIndex >= 0 and otherIndex ~= index then
        present[otherIndex] = true
        if field(other,'justJumped') == true then runtime.jumped[otherIndex] = runtime.clock+1 end
        local connected = not online or field(other,'isConnected') ~= false
        if connected and field(other,'isActive') ~= false and not pit(other)
            and (runtime.jumped[otherIndex] or 0) <= runtime.clock and speed(other) >= 30 then
          local ox,oy,oz = components(field(other,'position'))
          local lx,ly,lz = direction(other)
          if ox and oy and oz and lx and fx*lx+fy*ly+fz*lz >= ALIGNMENT then
            local dx,dy,dz = ox-px,oy-py,oz-pz
            local along = dx*fx+dy*fy+dz*fz
            local gap = math.max(0,along-(ownLength+size(other,'z',4.5))/2)
            local lateral = math.abs(dx*sx+dz*sz)
            local vertical = math.abs(dx*ux+dy*uy+dz*uz)
            local halfWidth = (ownWidth+size(other,'x',1.9))*0.35+gap*0.025
            if along > 0 and gap < REFERENCE_RANGE and lateral < halfWidth and vertical < 3 then
              clear = false
              if gap < RANGE then
                local strength = (1-gap/RANGE)^1.5*(1-(lateral/halfWidth)^2)
                  * U.clamp((speed(car)-MIN_SPEED)/60,0,1)*U.clamp(speed(other)/120,0,1)
                if strength > best then best,target,distance = strength,otherIndex,gap end
              end
            end
          end
        end
      end
    end
  end)
  for i in pairs(runtime.jumped) do if not present[i] then runtime.jumped[i] = nil end end
  if not ok then return nil end
  return best,target,distance,clear
end

local function ambientDensity(car, sim)
  if not ac.getAirPressure then return end
  local temperature = number(field(sim,'ambientTemperature'))
  local ok,pressure = pcall(ac.getAirPressure,field(car,'position'))
  pressure = ok and number(pressure) or nil
  if not pressure or pressure < 30 or pressure > 120 or not temperature
      or temperature < -80 or temperature > 80 then return end
  return pressure*1000/(287.05*(temperature+273.15))
end

function M.update(state, car, sim, dt, enabled)
  if enabled == false or not car or not sim then M.reset(state); return end
  local px,py,pz = components(field(car,'position'))
  local fx,fy,fz = direction(car)
  if not px or not py or not pz or not fx then M.reset(state); return end
  local replay = field(sim,'isReplayActive') == true
  local session = field(sim,'currentSessionIndex',0)
  local frame = replay and number(field(sim,'replayCurrentFrame')) or nil
  local frameMs = number(field(sim,'replayFrameMs')) or 16
  local step = U.clamp(number(dt) or 0,0,0.1)
  local runtime = state._slipstreamRuntime
  local index = field(car,'index',0)
  local sessionTime = number(field(sim,'currentSessionTime'))
  local reset = not runtime or runtime.session ~= session or runtime.replay ~= replay or runtime.index ~= index
    or sessionTime and runtime.sessionTime and sessionTime < runtime.sessionTime
  if runtime and not reset then
    local moved = math.sqrt((px-runtime.px)^2+(py-runtime.py)^2+(pz-runtime.pz)^2)
    local rate = math.abs(number(field(sim,'replayPlaybackRate')) or 1)
    reset = moved > math.max(35,speed(car)/3.6*step*rate*4+10)
      or frame and runtime.frame and (frame < runtime.frame
        or (frame-runtime.frame)*frameMs/1000 > step*rate+math.max(0.25,frameMs/1000*3))
  end
  local discontinuity = runtime ~= nil and reset
  if reset then
    M.reset(state)
    runtime = {session=session,replay=replay,index=index,clock=0,jumped={},cooldown=discontinuity and 1 or 0}
    state._slipstreamRuntime = runtime
  end
  if field(sim,'isPaused') == true or replay and field(sim,'replayPlaybackRate') == 0 then step = 0 end
  runtime.clock = runtime.clock+step
  runtime.px,runtime.py,runtime.pz,runtime.frame = px,py,pz,frame
  runtime.sessionTime = sessionTime
  if field(car,'justJumped') == true then
    runtime.cooldown = runtime.clock+1
  end
  if pit(car) or field(car,'justJumped') == true or runtime.clock < runtime.cooldown then
    state.slipstream = {available=false,intensity=0,source='unavailable'}
    runtime.baseline,runtime.cleanSeconds,runtime.cleanRatio = nil,0,nil
    return
  end

  local strength,target,distance,clear = geometry(car,sim,runtime,px,py,pz,fx,fy,fz)
  if strength == nil then M.reset(state); return end
  local output = state.slipstream
  output.available,output.targetIndex,output.distanceM = true,target,distance
  local source,reduction = 'estimated',nil
  local physics
  if not replay and ac.getCarPhysics then
    local ok,result = pcall(ac.getCarPhysics,index)
    if ok and field(result,'isAvailable') ~= false then physics = result end
  end
  local density = number(field(physics,'airDensity'))
  local ambient = density and density > 0 and ambientDensity(car,sim) or nil
  if ambient then
    local ratio = density/ambient
    if clear and speed(car) >= MIN_SPEED then
      runtime.cleanSeconds = (runtime.cleanSeconds or 0)+step
      runtime.cleanRatio = runtime.cleanRatio and runtime.cleanRatio+(ratio-runtime.cleanRatio)
        *(1-math.exp(-step/0.4)) or ratio
      if runtime.cleanSeconds >= 1 then runtime.baseline = runtime.cleanRatio end
    else runtime.cleanSeconds,runtime.cleanRatio = 0,nil end
    if runtime.baseline and runtime.baseline > 0 then
      reduction = U.clamp(1-ratio/runtime.baseline,0,1)
      source = 'physics'
      strength = target and speed(car) >= MIN_SPEED and U.clamp(reduction/0.20,0,1) or 0
    end
  else
    runtime.cleanSeconds,runtime.cleanRatio = 0,nil
  end
  local threshold = runtime.active and 0.03 or 0.05
  runtime.active = strength >= threshold
  local desired = runtime.active and strength or 0
  local current = output.intensity or 0
  local tau = desired > current and 0.2 or 0.5
  output.intensity = current+(desired-current)*(1-math.exp(-step/tau))
  if output.intensity < 0.001 then output.intensity = 0 end
  -- Integrating phase prevents pulse jumps when the wake strengthens or weakens.
  -- The existing zero step while paused also freezes the visual pulse.
  local pulsesPerSecond = 0.55+1.05*output.intensity
  output.pulsePhase = ((output.pulsePhase or 0.5)+step*pulsesPerSecond)%1
  output.source,output.densityReduction = source,reduction
end

return M
