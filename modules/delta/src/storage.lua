local Storage = {}
Storage.__index = Storage

local function replaceInvalidCharacters(value)
  value = tostring(value or 'unknown')
  value = value:gsub('["%*%?<>|:/\\]', '_')
  value = value:gsub('%s+', '_')
  return value:sub(1, 150)
end

local function binaryAvailable()
  return type(io) == 'table' and type(io.load) == 'function'
    and type(io.save) == 'function' and type(stringify) == 'table'
    and type(stringify.binary) == 'function'
    and type(stringify.binary.parse) == 'function'
end

local function memoryStorage(default)
  local value = default
  return {
    get = function() return value end,
    set = function(_, nextValue) value = nextValue end
  }
end

local function storedValue(key, default)
  local ok, value = pcall(ac.storage, key, default)
  if ok and value ~= nil then return value end
  return memoryStorage(default)
end

function Storage.new(trackName, carName)
  local trackKey = replaceInvalidCharacters(trackName)
  local carKey = replaceInvalidCharacters(carName)
  local folder = 'CMRTRetroDeltaBar/'
  local folderOk, documents = pcall(ac.getFolder, ac.FolderID and ac.FolderID.ACDocuments or 31)
  if folderOk and type(documents) == 'string' and documents ~= '' then
    folder = documents .. '/CMRTRetroDeltaBar/'
  end
  local prefix = folder .. trackKey .. '[#]' .. carKey .. '[v1]'
  local self = setmetatable({
    folder = folder,
    bestPath = prefix .. '.delta',
    modeStorage = storedValue('CMRTRetroDeltaBar.last_barmode_v1', 0),
    fallbackStorage = storedValue('CMRTRetroDeltaBar.best.' .. trackKey .. '[#]' .. carKey .. '[v1]', nil)
  }, Storage)
  pcall(function()
    if io.dirExists(folder) == false then io.createDir(folder) end
  end)
  return self
end

function Storage:getLastMode(default)
  local value = nil
  pcall(function() value = self.modeStorage:get() end)
  value = tonumber(value)
  if not value or value < 0 or value > 5 then return default or 0 end
  return math.floor(value)
end

function Storage:setLastMode(mode)
  pcall(function() self.modeStorage:set(mode) end)
end

function Storage:load()
  local data = nil
  if binaryAvailable() then
    local ok, raw = pcall(io.load, self.bestPath, nil)
    if ok and raw ~= nil then
      local parsedOk, parsed = pcall(stringify.binary.parse, raw)
      if parsedOk and type(parsed) == 'table' then data = parsed end
    end
  end
  if data == nil then
    pcall(function()
      local raw = self.fallbackStorage:get()
      if type(raw) == 'string' and type(stringify) == 'table' and type(stringify.parse) == 'function' then
        data = stringify.parse(raw)
      end
    end)
  end
  return type(data) == 'table' and data or nil
end

function Storage:save(data)
  if type(data) ~= 'table' then return false end
  local saved = false
  if binaryAvailable() then
    local ok, raw = pcall(stringify.binary, data)
    if ok and raw ~= nil then
      local writeOk = pcall(io.save, self.bestPath, raw)
      saved = writeOk
    end
  end
  if not saved then
    pcall(function()
      if type(stringify) == 'table' and type(stringify.serialize) == 'function' then
        self.fallbackStorage:set(stringify.serialize(data))
        saved = true
      end
    end)
  end
  return saved
end

return Storage
