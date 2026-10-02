local Audio = {}
local sounds = {
  sectorRecord = { path = 'assets/notification-qqv87.wav' },
  lapRecord = { path = 'assets/experimental-5btgm.wav' }
}

local function ensurePlayer(sound)
  if sound.player then return sound.player end
  local ok, player = pcall(function() return ui.MediaPlayer(sound.path) end)
  if not ok or player == nil then
    return nil, ok and 'Media player creation returned no player' or tostring(player)
  end
  sound.player = player
  return player
end

local function failure(sound, message)
  if sound.lastError ~= message and type(ac.error) == 'function' then
    pcall(ac.error, '[Retro UI Timer audio] ' .. sound.path .. ': ' .. message)
  end
  sound.lastError = message
  return false, message
end

local function play(sound)
  local player, err = ensurePlayer(sound)
  if not player then return failure(sound, err) end
  local ok, message = pcall(function()
    player:setVolume(1)
    player:setCurrentTime(0)
    player:play()
  end)
  if not ok then return failure(sound, tostring(message)) end
  sound.lastError = nil
  return true
end

function Audio.playSectorRecord()
  return play(sounds.sectorRecord)
end

function Audio.playLapRecord()
  return play(sounds.lapRecord)
end

return Audio
