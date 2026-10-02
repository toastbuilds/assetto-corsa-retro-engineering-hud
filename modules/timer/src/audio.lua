local Audio = {}
local sounds = {
  sectorRecord = { path = 'assets/notification-qqv87.wav' },
  lapRecord = { path = 'assets/experimental-5btgm.wav' }
}

local function ensurePlayer(sound)
  if sound.player or sound.unavailable then return sound.player end
  if type(ui.MediaPlayer) ~= 'function' then
    sound.unavailable = true
    return nil
  end
  local ok, player = pcall(ui.MediaPlayer, sound.path)
  if not ok or player == nil then
    sound.unavailable = true
    return nil
  end
  sound.player = player
  return player
end

local function play(sound)
  local player = ensurePlayer(sound)
  if not player then return false end
  pcall(function() player:setVolume(1) end)
  pcall(function() player:setCurrentTime(0) end)
  local ok = pcall(function() player:play() end)
  return ok
end

function Audio.playSectorRecord()
  return play(sounds.sectorRecord)
end

function Audio.playLapRecord()
  return play(sounds.lapRecord)
end

return Audio
