local M = {}

local function ensureDirectory(path)
  if io.dirExists(path) then return true end
  local ok = pcall(io.createDir, path)
  return ok and io.dirExists(path)
end

local function saveAndVerify(path, contents)
  local ok, result = pcall(io.save, path, contents)
  if not ok or result == false then return false end
  local readOk, saved = pcall(io.load, path)
  return readOk and saved == contents
end

function M.restore(moduleDirectory, panel, reload)
  local active = moduleDirectory .. '/classes.ini'
  local factory = moduleDirectory .. '/classes.default.ini'
  local okCurrent, current = pcall(io.load, active)
  local okFactory, defaults = pcall(io.load, factory)
  if not okCurrent or type(current) ~= 'string' then return false, 'Could not read classes.ini.' end
  if not okFactory or type(defaults) ~= 'string' then return false, 'Factory class map is missing.' end

  local okDocuments, documents = pcall(ac.getFolder, ac.FolderID.ACDocuments)
  if not okDocuments or type(documents) ~= 'string' or documents == '' then
    return false, 'Assetto Corsa Documents folder is unavailable.'
  end
  local root = documents .. '/RetroUI'
  local backups = root .. '/Class Backups'
  local folder = backups .. '/' .. panel
  if not ensureDirectory(root) or not ensureDirectory(backups) or not ensureDirectory(folder) then
    return false, 'Could not create the class backup folder.'
  end
  local stamp = os.date('%Y%m%d-%H%M%S')
  local backup
  for index = 1, 1000 do
    local candidate = folder .. '/' .. stamp .. '-' .. index .. '.ini'
    if not io.exists(candidate) then backup = candidate; break end
  end
  if not backup or not saveAndVerify(backup, current) then
    return false, 'Could not save the previous class map.'
  end
  if not saveAndVerify(active, defaults) then
    saveAndVerify(active, current)
    return false, 'Could not restore the factory class map.'
  end
  local reloaded, err = pcall(reload)
  if not reloaded then
    saveAndVerify(active, current)
    pcall(reload)
    return false, 'Could not reload class mappings: ' .. tostring(err)
  end
  return true, backup
end

return M
