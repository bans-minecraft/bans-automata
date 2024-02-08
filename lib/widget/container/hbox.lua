local Class = require("lib.class")
local Box = require("lib.widget.container.box")

local HBox = Class("HBox", Box)

function HBox:init()
  Box.init(self, "horizontal")
end

return HBox
