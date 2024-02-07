local Assert = require("lib.assert")
local Class = require("lib.class")
local Requisition = require("lib.widget.requisition")
local RenderContext = require("lib.widget.render.context")
local Rect = require("lib.rect")
local Size = require("lib.size")

local Widget = Class("Widget")

function Widget:init()
  self.parent = nil
  self.visible = true
  self.size = Size:new(0, 0)
end

function Widget:destroy()
  if self.parent ~= nil then
    self.parent:removeChild(self)
  end
end

function Widget:setVisible(visible)
  Assert.assertIs(visible, "boolean")
  self.visible = visible
  self:queueRedraw()
end

function Widget:hide()
  self:setVisible(false)
end

function Widget:show()
  self:setVisible(true)
end

function Widget:getSizeRequest()
  return Requisition:new(Size:new(0, 0), Size:new(0, 0))
end

function Widget:setAllocation(allocation)
  Assert.assertInstance(allocation, Rect)
  self.allocation = allocation:clone()
end

function Widget:render(context)
  Assert.assertInstance(context, RenderContext)
end

function Widget:queueRedraw()
end

return Widget
