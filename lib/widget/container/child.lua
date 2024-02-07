local Assert = require("lib.assert")
local Class = require("lib.class")
local Requisition = require("lib.widget.requisition")
local Size = require("lib.size")
local Widget = require("lib.widget")
local Rect = require("lib.rect")
local Coord = require("lib.coord")

local Child = Class("Child")

function Child:init(widget)
  Assert.assertInstance(widget, Widget)
  self.widget = widget
  self.padding = 0
  self.expand = false
  self.fill = false
  self.packing = "start"

  self.requisition = Requisition:new(Size:new(0, 0), Size:new(0, 0))
  self.reqMinimum = Size:new(0, 0)
  self.reqNatural = Size:new(0, 0)

  self.allocation = Rect:new(Coord:new(1, 1), Size:new(0, 0))
end

function Child:getSizeRequest(spacing, first, last, orientation)
  -- We add the padding to all sides of the child
  local dbl_padding = 2 * self.padding

  -- The spacing is only added either to the top and bottom, or just the top or bottom.
  local add_spacing = spacing
  if not first and not last then
    add_spacing = 2 * spacing
  end

  self.requisition = self.widget:getSizeRequest()

  self.reqMinimum = self.requisition.minimum:clone()
  self.reqMinimum:expand(dbl_padding, dbl_padding)

  self.reqNatural = self.requisition.natural:clone()
  self.reqNatural:expand(dbl_padding, dbl_padding)

  if orientation == "vertical" then
    self.reqMinimum:expand(0, add_spacing)
    self.reqNatural:expand(0, add_spacing)
  elseif orientation == "horizontal" then
    self.reqMinimum:expand(add_spacing, 0)
    self.reqNatural:expand(add_spacing, 0)
  end
end

function Child:setAllocation(allocation)
  Assert.assertInstance(allocation, Rect)
  self.allocation = allocation:clone()
  self.widget:setAllocation(allocation)
end

function Child:setPackStart()
  self.packing = "start"
end

function Child:setPackEnd()
  self.packing = "end"
end

function Child:getWidthForHeight(height)
  return self.requisition.minimum.width, self.requisition.natural.width
end

function Child:getHeightForWidth(width)
  return self.requisition.minimum.height, self.requisition.natural.height
end

return Child
