local Audio = {
  path = 'assets/notification-qqv87.wav',
  player = nil,
  unavailable = false
}

local function ensurePlayer()
  if Audio.player or Audio.unavailable then return Audio.player end
  if type(ui.MediaPlayer) ~= 'function' then
    Audio.unavailable = true
    return nil
  end
  local ok, player = pcall(ui.MediaPlayer, Audio.path)
  if not ok or player == nil then
    Audio.unavailable = true
    return nil
  end
  Audio.player = player
  return player
end

function Audio.play()
  local player = ensurePlayer()
  if not player then return false end
  local volume = 1
  if type(ac.getAudioVolume) == 'function' and ac.AudioChannel and ac.AudioChannel.Main ~= nil then
    local ok, value = pcall(ac.getAudioVolume, ac.AudioChannel.Main)
    if ok and tonumber(value) then volume = math.max(0, math.min(1, tonumber(value))) end
  end
  pcall(function() player:setVolume(volume) end)
  local ok = pcall(function() player:play() end)
  return ok
end

return Audio
