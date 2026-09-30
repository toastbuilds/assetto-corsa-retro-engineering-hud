local Theme = {}

-- Both palettes use the same semantic roles. The dial only asks for a role
-- (primary text, raised panel, warning, etc.), so switching themes never
-- leaves a dark-only color behind in one of the instrument layouts.
Theme.palettes = {
  dark = {
    -- graphite surfaces, warm instrument text, amber rules and restrained cyan
    void = rgbm(0x0B / 255, 0x09 / 255, 0x07 / 255, 0.98),
    surface = rgbm(0x15 / 255, 0x11 / 255, 0x0D / 255, 0.98),
    panel = rgbm(0x0D / 255, 0x0B / 255, 0x09 / 255, 0.98),
    panelRaised = rgbm(0x1A / 255, 0x13 / 255, 0x0E / 255, 0.98),
    metal = rgbm(0x54 / 255, 0x51 / 255, 0x49 / 255, 0.92),
    metalDim = rgbm(0x28 / 255, 0x27 / 255, 0x23 / 255, 0.9),
    outline = rgbm(0x76 / 255, 0x54 / 255, 0x2C / 255, 0.95),
    outlineSoft = rgbm(0x60 / 255, 0x45 / 255, 0x23 / 255, 0.78),
    outlineDim = rgbm(0x33 / 255, 0x25 / 255, 0x19 / 255, 0.9),
    primary = rgbm(0xF2 / 255, 0xDB / 255, 0xAE / 255, 1),
    secondary = rgbm(0x98 / 255, 0x7A / 255, 0x4C / 255, 0.95),
    amber = rgbm(0xFF / 255, 0xC4 / 255, 0x6B / 255, 1),
    amberDim = rgbm(0x5E / 255, 0x43 / 255, 0x19 / 255, 0.92),
    flagYellow = rgbm(0xF4 / 255, 0xC7 / 255, 0x00 / 255, 1),
    backlight = rgbm(0xFF / 255, 0xD9 / 255, 0x8A / 255, 1),
    coreAmber = rgbm(0x9A / 255, 0x63 / 255, 0x16 / 255, 0.94),
    cyan = rgbm(0x68 / 255, 0xB7 / 255, 0xD6 / 255, 1),
    cyanDim = rgbm(0x29 / 255, 0x56 / 255, 0x5C / 255, 0.95),
    shiftBlue = rgbm(0x46 / 255, 0x9B / 255, 0xCA / 255, 1),
    shiftBlueDim = rgbm(0x0D / 255, 0x2C / 255, 0x46 / 255, 1),
    green = rgbm(0x7E / 255, 0xC8 / 255, 0x6A / 255, 1),
    red = rgbm(0xD8 / 255, 0x4B / 255, 0x3E / 255, 1),
    redDim = rgbm(0x52 / 255, 0x1B / 255, 0x18 / 255, 0.92),
    coreRed = rgbm(0x83 / 255, 0x24 / 255, 0x1B / 255, 0.94),
    inactive = rgbm(0x2A / 255, 0x21 / 255, 0x17 / 255, 0.92),
    debug = rgbm(0x0B / 255, 0x09 / 255, 0x07 / 255, 0.94)
  },

  light = {
    -- warm instrument paper with graphite text and deeper status accents
    void = rgbm(0xD8 / 255, 0xD2 / 255, 0xC6 / 255, 0.98),
    surface = rgbm(0xE9 / 255, 0xE4 / 255, 0xD9 / 255, 0.98),
    panel = rgbm(0xF7 / 255, 0xF3 / 255, 0xEA / 255, 0.98),
    panelRaised = rgbm(0xFF / 255, 0xFC / 255, 0xF5 / 255, 0.98),
    metal = rgbm(0x77 / 255, 0x72 / 255, 0x68 / 255, 0.92),
    metalDim = rgbm(0xB6 / 255, 0xB0 / 255, 0xA4 / 255, 0.9),
    outline = rgbm(0x8A / 255, 0x5A / 255, 0x27 / 255, 0.95),
    outlineSoft = rgbm(0xB2 / 255, 0x94 / 255, 0x6B / 255, 0.78),
    outlineDim = rgbm(0x82 / 255, 0x79 / 255, 0x6B / 255, 0.82),
    primary = rgbm(0x2E / 255, 0x2B / 255, 0x26 / 255, 1),
    secondary = rgbm(0x65 / 255, 0x59 / 255, 0x48 / 255, 0.95),
    amber = rgbm(0x95 / 255, 0x50 / 255, 0x00 / 255, 1),
    amberDim = rgbm(0xF0 / 255, 0xD2 / 255, 0x9C / 255, 0.92),
    flagYellow = rgbm(0xC2 / 255, 0x86 / 255, 0x00 / 255, 1),
    backlight = rgbm(0xA5 / 255, 0x5D / 255, 0x0A / 255, 1),
    coreAmber = rgbm(0xF8 / 255, 0xE4 / 255, 0xBA / 255, 0.94),
    cyan = rgbm(0x0B / 255, 0x78 / 255, 0x98 / 255, 1),
    cyanDim = rgbm(0x74 / 255, 0xA9 / 255, 0xB8 / 255, 0.95),
    shiftBlue = rgbm(0x1A / 255, 0x6F / 255, 0xA0 / 255, 1),
    shiftBlueDim = rgbm(0xB9 / 255, 0xD8 / 255, 0xE6 / 255, 1),
    green = rgbm(0x2F / 255, 0x7A / 255, 0x42 / 255, 1),
    red = rgbm(0xAD / 255, 0x29 / 255, 0x22 / 255, 1),
    redDim = rgbm(0xEF / 255, 0xBB / 255, 0xB5 / 255, 0.92),
    coreRed = rgbm(0xF7 / 255, 0xD4 / 255, 0xCF / 255, 0.94),
    inactive = rgbm(0xA8 / 255, 0x9F / 255, 0x90 / 255, 0.92),
    debug = rgbm(0xE8 / 255, 0xE2 / 255, 0xD7 / 255, 0.94)
  }
}

-- Keep the old export available for callers that only need the default
-- palette, while the dial uses get() for the selected theme each frame.
Theme.colors = Theme.palettes.dark

function Theme.get(name)
  return Theme.palettes[name] or Theme.palettes.dark
end

Theme.fonts = {
  utility = 'Consolas;Weight=Regular'
}

function Theme.withAlpha(color, alpha)
  return rgbm(color.r, color.g, color.b, alpha)
end

return Theme
