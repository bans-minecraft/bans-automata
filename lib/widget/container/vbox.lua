local Class = require("lib.class")
local Container = require("lib.widget.container")

local VBox = Class("VBox", Container)

function VBox:init()
  Container.init(self, "vertical")
end

return VBox
