-- Standalone faces show measurements and status abbreviations, without captions.
local M={}
local captions={'SPEED','GEAR','RPM','TURBO','FUEL','BRAKE','THROTTLE','CLUTCH',
  'LIGHTS','STEERING','STEER','INPUT','AERO','AUX','BATTERY','BAT','ERS','CHG','PWR','BRK','THR','CL'}
local only={['RPM ×1000']=true,['RPM x1000']=true}
for _,name in ipairs(captions) do only[name]=true end
function M.value(value)
  local result=tostring(value)
  if only[result] then return nil end
  for _,name in ipairs(captions) do
    result=result:gsub('%f[%a]'..name..'%f[%A]%s*','')
  end
  result=result:match('^%s*(.-)%s*$')
  return result~='' and result or nil
end
function M.fuelColor(fraction, state, colors, normal)
  if fraction == nil or fraction >= 0.15 then return normal end
  if fraction < 0.10 and math.floor((state.clock or 0) / 0.3) % 2 ~= 0 then
    return colors.inactive
  end
  return colors.red
end
return M
