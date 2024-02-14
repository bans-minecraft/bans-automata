package.path = "/?.lua;/?/init.lua;" .. package.path
local Css = require("lib.widget.theme.css")
local Log = require("lib.log")

local DEMO_THEME = {
  ["Window"] = { bg = 4 },
  ["Label"] = { fg = 2, bg = 3 },
  ["StatusBar"] = { fg = 1, bg = 2 },
  ["StatusBar > Label"] = { fg = 1 },
}

local tree = Css.build(DEMO_THEME)
tree:print("")
