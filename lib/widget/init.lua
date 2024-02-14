local Assert = require("lib.assert")
local Class = require("lib.class")
local Rect = require("lib.rect")
local RenderContext = require("lib.widget.render.context")
local Requisition = require("lib.widget.requisition")
local Size = require("lib.size")
local Css = require("lib.widget.theme.css")
local Log = require("lib.log")

local Widget = Class("Widget")

function Widget:init()
  self.parent = nil
  self.visible = true
  self.size = Size:new(0, 0)
  self.cached = {}
  self.style = nil
end

function Widget:clearParent()
  self.parent = nil
end

function Widget:setParent(parent)
  Assert.assertInstance(parent, Widget)
  Assert.assertIsNil(self.parent, "Widget already has a parent")
  self.parent = parent
end

function Widget:getChildren()
  return {}
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

function Widget:applyStyle(iterator)
  Log.info("Widget:applyStyle", self)
  Log.indent = Log.indent + 1
  Assert.assertInstance(iterator, Css.Iterator)
  iterator:enter(self)
  if iterator.node then
    Log.info("Applying style to", self, ":", iterator.node.attributes)
    self.style = iterator.node.attributes
  end

  local children = self:getChildren()
  Log.info(self, "has", #children, "children")
  for _, child in pairs(children) do
    child:applyStyle(iterator)
  end

  iterator:leave()
  Log.indent = Log.indent - 1
end

return Widget
