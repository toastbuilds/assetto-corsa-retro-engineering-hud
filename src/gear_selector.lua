-- Mechanical selector presentation: live numerals never wait for the plate.
local M = {duration=0.12, startAngle=-155, endAngle=-25}
local function finite(value)
  return type(value)=='number' and value==value and math.abs(value)<math.huge
end
local function validCount(value)
  return finite(value) and value>=1 and value<=32 and value==math.floor(value)
end
function M.count(value, gear)
  local count=validCount(value) and value or 6
  if validCount(gear) then count=math.max(count,gear) end
  return count
end
function M.observe(state, value, gear, key)
  if state._gearCountCarKey~=key then
    state._gearCountCarKey=key
    state._observedGearCount=0
  end
  if validCount(gear) then state._observedGearCount=math.max(state._observedGearCount or 0,gear) end
  state.gearCount=M.count(value,validCount(value) and gear or state._observedGearCount)
  state.gearCountSource=validCount(value) and 'car' or (state.gearCount>6 and 'observed' or 'fallback')
end
function M.gear(state)
  if state.available==false then return nil end
  if state.gearText=='R' then return -1 end
  if state.gearText=='N' then return 0 end
  local gear=tonumber(state.gearText) or state.gear
  return finite(gear) and gear>=-1 and gear<=32 and gear==math.floor(gear) and gear or nil
end
function M.angle(gear,count)
  if gear==nil or gear==0 then return nil end
  local index=gear==-1 and 0 or gear
  return M.startAngle+(M.endAngle-M.startAngle)*(index+0.5)/(count+1)
end
function M.at(animation,now)
  local t=math.max(0,math.min(1,(now-animation.started)/M.duration))
  if t>=1 then return animation.target end
  -- Ease-out-back with a restrained ~1.25% overshoot, settled at 120 ms.
  local x=t-1
  local eased=1+1.6*x*x*x+0.6*x*x
  return animation.from+(animation.target-animation.from)*eased
end
function M.sample(animation,gear,count,now,enabled,key)
  now=finite(now) and now or 0
  local target=M.angle(gear,count)
  if not animation or animation.count~=count or animation.key~=key
      or now<animation.last or now-animation.last>0.25 then
    local angle=target or -90
    animation={gear=gear,count=count,key=key,from=angle,target=angle,started=now,last=now}
  else
    local current=M.at(animation,now)
    if animation.gear~=gear then
      animation.from,animation.target,animation.started=current,target or animation.target,now
      animation.gear=gear
    end
    animation.last=now
  end
  if enabled==false then animation.from,animation.started=animation.target,now-M.duration end
  return animation,M.at(animation,now)
end
return M
