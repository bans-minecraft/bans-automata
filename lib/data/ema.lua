local Assert = require("lib.assert")
local Class = require("lib.class")

local EMA = Class("EMA")

function EMA:init(alpha, startOpt)
  Assert.assertIsNumber(alpha)
  self.alpha = alpha
  self.value = nil
  self.rate = nil

  if startOpt ~= nil then
    self:push(startOpt)
  end
end

function EMA:push(value)
  Assert.assertIsNumber(value)
  if self.value == nil then
    self.value = value
    self.rate = 0
  else
    local delta = value - self.value
    self.rate = (self.alpha * delta) + (1 - self.alpha) * self.rate
    self.value = value
  end
end

function EMA:get()
  return self.value
end

function EMA:getRate()
  return self.rate
end

function EMA:reset()
  self.value = nil
  self.rate = nil
end

return EMA
