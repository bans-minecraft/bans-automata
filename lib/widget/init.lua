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

function Widget:setVisible(visible)
  Assert.assertIs(visible, "boolean")
  self.visible = visible
end

function Widget:hide()
  self:setVisible(false)
end

function Widget:show()
  self:setVisible(true)
end

function Widget:queueRedraw()
  if self.parent ~= nil then self.parent:queueRedraw() end
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

return Widget
