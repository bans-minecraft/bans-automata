local Assert = require("lib.assert")
local Class = require("lib.class")
local Css = require("lib.widget.theme.css")

local Theme = Class("Theme")

local DEFAULT_THEME = {
  ["Window"] = {
    bg = colors.gray,
    fg = colors.white,
    fill = true
  },

  ["Label"] = {
    fg = colors.white,
  },

  ["StatusBar"] = {
    bg = colors.blue,
    fg = colors.lightBlue,
    fill = true
  },

  ["StatusBar > Label"] = {
    fg = colors.lightBlue,
    bg = colors.blue
  },

  ["Button"] = {
    bg = colors.lightGray,
    fg = colors.black,
    fill = true,
    states = {
      pressed = {
        bg = colors.white,
      },
      disabled = {
        fg = colors.gray,
      },
      primary = {
        fg = colors.blue,
      }
    }
  }
}

function Theme:init(theme)
  self.css = Css.build(theme or DEFAULT_THEME)
end

function Theme.static.loadTheme(path)
  if not fs.exists(path) then
    error(("Theme file does not exist: %s"):format(path))
  end

  local file = fs.open(path, "r")
  local contents = file.readAll()
  file.close()

  local theme = textutils.unserialize(contents)
  Assert.assertIsTable(theme)
  return Theme:new(theme)
end

return Theme
