local Assert = require("lib.assert")
local Class = require("lib.class")
local Widget = require("lib.widget")

local Bin = Class("Bin", Widget)

function Bin:init(bgColorOpt)
  Widget.init(self)
  self.fill = true
  self.bgColor = nil
  self.child = nil

  if bgColorOpt ~= nil then
    Assert.assertIsNumber(bgColorOpt)
    self.bgColor = bgColorOpt
  end
end

function Bin:getChildren()
  return { self.child }
end

function Bin:setChild(child)
  Assert.assertInstance(child, Widget)
  Assert.assertEq(child.parent, nil)

  if self.child then
    self.child:clearParent()
  end

  child:setParent(self)
  self.child = child
end

function Bin:removeChild(child)
  Assert.assertInstance(child, Widget)
  Assert.assertEq(child.parent, self)

  self.child:clearParent()
  self.child = nil
end

function Bin:setBackground(color)
  Assert.assertIsNumber(color)
  self.bgColor = color
  self:queueRedraw()
end

function Bin:setFilled(filled)
  Assert.assertIsBoolean(filled)
  self.fill = filled
  self:queueRedraw()
end

function Bin:getSizeRequest()
  if self.child then
    return self.child:getSizeRequest()
  else
    return Widget.getSizeRequest(self)
  end
end

function Bin:setAllocation(allocation)
  Widget.setAllocation(self, allocation)
  if self.child then
    self.child:setAllocation(allocation)
  end
end

function Bin:render(context)
  if self.fill then
    context:clear(self.bgColor)
  end

  if self.child then
    self.child:render(context)
  end
end

return Bin
