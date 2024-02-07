local Assert = require("lib.assert")
local Class = require("lib.class")
local Size = require("lib.size")
local Log = require("lib.log")
local Requisition = require("lib.widget.requisition")
local Widget = require("lib.widget")
local Utils = require("lib.utils")

local Label = Class("Label", Widget)

local function isKnownAlignment(alignment)
  Assert.assertIs(alignment, "string")
  return alignment == "left" or alignment == "right" or alignment == "center"
end

function Label:init(textOpt, fgColorOpt, bgColorOpt, alignOpt)
  Widget.init(self)

  self.text = ""
  self.fgColor = colors.white
  self.bgColor = colors.black
  self.align = "left"

  if textOpt ~= nil then
    Assert.assertIs(textOpt, "string")
    self.text = textOpt
  end

  if fgColorOpt ~= nil then
    Assert.assertIs(fgColorOpt, "number")
    self.fgColor = fgColorOpt
  end

  if bgColorOpt ~= nil then
    Assert.assertIs(bgColorOpt, "number")
    self.bgColor = bgColorOpt
  end

  if alignOpt ~= nil then
    Assert.assertIs(alignOpt, "string")
    Assert.assert(isKnownAlignment(alignOpt))
    self.align = alignOpt
  end
end

function Label:setForeground(color)
  Assert.assertIs(color, "number")
  self.fgColor = color
  self:queueRedraw()
end

function Label:setBackground(color)
  Assert.assertIs(color, "number")
  self.bgColor = color
  self:queueRedraw()
end

function Label:setText(text)
  Assert.assertIs(text, "string")
  self.text = text
  self:queueRedraw()
end

function Label:setAlignment(alignment)
  Assert.assertIs(alignment, "string")
  Assert.assert(isKnownAlignment(alignment))
  self.align = alignment
  self:queueRedraw()
end

function Label:getSizeRequest()
  local minimum = Size:new(1, 1)
  local natural = Size:new(#self.text, 1)
  return Requisition:new(minimum, natural)
end

function Label:setAllocation(allocation)
  Widget.setAllocation(self, allocation)
  Log.info(("Label:setAllocation allocation = %s"):format(allocation))
end

function Label:render(context)
  Log.info(("Label:render allocation = %s"):format(self.allocation))
  Widget.render(self, context)
  context:renderRect(self.allocation, self.bgColor)

  local visible = Utils.ellipsize(self.text, self.allocation.size.width)
  context:renderString(self.allocation.position, visible, self.bgColor, self.fgColor)
end

return Label
