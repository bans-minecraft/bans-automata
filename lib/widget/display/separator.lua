local Assert = require("lib.assert")
local Class = require("lib.class")
local Requisition = require("lib.widget.requisition")
local Size = require("lib.size")
local Widget = require("lib.widget")

local Separator = Class("Separator", Widget)

function Separator:init(orientation, colorOpt)
  Assert.assertIsString(orientation)
  Widget.init(self)
  self.orientation = orientation
  self.color = colors.black

  if colorOpt ~= nil then
    Assert.assertIsNumber(colorOpt)
    self.color = colorOpt
  end
end

function Separator:getSizeRequest()
  local size = Size:new(1, 1)
  return Requisition:new(size, size)
end

function Separator:render(context)
  context:clear(self.color)
end

return Separator
