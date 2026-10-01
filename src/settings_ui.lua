local M = {}
local openSections = {}
local pendingReset
local notices = {}

local function showNotice(page, appearance)
  local notice = notices[page]
  if not notice then return end
  if ui.time() > notice.expires then notices[page] = nil; return end
  if notice.appearance == appearance then ui.textWrapped(notice.message) end
end

function M.section(page, key, title, initiallyOpen, draw)
  local id = page .. '.' .. key
  local opened = openSections[id]
  if opened == nil then opened = initiallyOpen ~= false end
  if ui.button((opened and 'v  ' or '>  ') .. title .. '##' .. id, vec2(ui.availableSpaceX(), 0)) then
    opened = not opened
  end
  openSections[id] = opened
  if opened then
    ui.separator()
    draw()
    ui.separator()
  end
end

function M.choice(page, key, label, current, choices, set)
  local index, labels = 0, {}
  for i, choice in ipairs(choices) do
    labels[i - 1] = choice.label
    if choice.value == current then index = i - 1 end
  end
  ui.text(label)
  ui.sameLine(190)
  local selected, changed = ui.combo('##' .. page .. '.' .. key, index, ui.ComboFlags.None, labels)
  if changed and choices[selected + 1] then set(choices[selected + 1].value) end
end

function M.needle(page, key, label, current, config, set)
  local index = 1
  for i, id in ipairs(config.needleOrder) do if id == current then index = i; break end end
  ui.text(label .. ': ' .. config.needleNames[config.needleOrder[index]])
  local selected, changed = ui.slider('##' .. page .. '.' .. key, index, 1,
    #config.needleOrder, '%.0f / ' .. #config.needleOrder, 1)
  if changed then
    selected = math.max(1, math.min(#config.needleOrder, math.floor(selected + 0.5)))
    set(config.needleOrder[selected])
  end
end

function M.resetAppearance(page, reset)
  if ui.button('Reset appearance##' .. page) then
    reset()
    notices[page] = { message = 'Appearance restored to defaults.', appearance = true,
      expires = ui.time() + 7 }
  end
  showNotice(page, true)
end

function M.resetAll(page, reset, details)
  if ui.button('Reset all##' .. page) then pendingReset = page end
  if pendingReset == page then
    ui.textWrapped(details or 'Restore all settings for this instrument?')
    if ui.button('Confirm reset##' .. page) then
      local called, ok, err = pcall(reset)
      local message = not called and ('Reset failed: ' .. tostring(ok))
        or ok == false and ('Reset failed: ' .. tostring(err))
        or 'All settings restored to defaults.'
      notices[page] = { message = message, appearance = false, expires = ui.time() + 7 }
      pendingReset = nil
    end
    ui.sameLine()
    if ui.button('Cancel##' .. page) then pendingReset = nil end
  end
  showNotice(page, false)
end

return M
