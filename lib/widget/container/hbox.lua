local Class = require("lib.class")
local Container = require("lib.widget.container")

local HBox = Class("HBox", Container)

function HBox:init()
  Container.init(self, "horizontal")
end

return HBox
