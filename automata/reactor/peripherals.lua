local Assert = require("lib.assert")
local Class = require("lib.class")

local Peripherals = Class("Peripherals")

function Peripherals:init()
  self:findReactor()
  self:findCoolantReturn()
end

function Peripherals:findReactor()
  self.reactor = peripheral.find("fissionReactorLogicAdapter")
  if not self.reactor then
    error("Failed to find reactor peripheral (expected to find 'fissionReactorLogicAdapter')")
  end
end

function Peripherals:findCoolantReturn()
  self.coolantReturn = peripheral.find("ultimateMechanicalPipe")
  if not self.coolantReturn then
    error("Failed to find coolant return peripheral (expected to find 'ultimateMechanicalPipe')")
  end
end

return Peripherals
