local Assert      = require("lib.assert")
local Class       = require("lib.class")
local Size        = require("lib.size")

local Requisition = Class("Requisition")

function Requisition:init(minimum, natural)
  Assert.assertInstance(minimum, Size)
  Assert.assertInstance(natural, Size)
  self.minimum = minimum
  self.natural = natural
end

function Requisition.static.createEmpty()
  return Requisition:new(Size:new(0, 0), Size:new(0, 0))
end

function Requisition:__tostring()
  return ("[min = %s, natural = %s]"):format(self.minimum, self.natural)
end

return Requisition
