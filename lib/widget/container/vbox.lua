local Class = require("lib.class")
local Box = require("lib.widget.container.box")

local VBox = Class("VBox", Box)

function VBox:init()
  Box.init(self, "vertical")
end

return VBox
