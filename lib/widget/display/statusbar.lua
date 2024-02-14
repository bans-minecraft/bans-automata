local Assert = require("lib.assert")
local Box = require("lib.widget.container.box")
local Class = require("lib.class")
local Label = require("lib.widget.display.label")

local StatusBar = Class("StatusBar", Box)

function StatusBar:init()
  Box.init(self, "horizontal")
end

return StatusBar
