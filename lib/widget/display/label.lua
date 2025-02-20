local Assert = require("lib.assert")
local Class = require("lib.class")
local Coord = require("lib.coord")
local Size = require("lib.size")
local Requisition = require("lib.widget.requisition")
local Widget = require("lib.widget")
local String = require("lib.string")

local Label = Class("Label", Widget)

local function isKnownAlignment(alignment)
  Assert.assertIs(alignment, "string")
  return alignment == "left" or alignment == "right" or alignment == "center"
end

local function alignText(alignment, width, text)
  if alignment == "left" then
    return String.leftAlign(text, width)
  elseif alignment == "right" then
    return String.rightAlign(text, width)
  elseif alignment == "center" then
    return String.centerAlign(text, width)
  else
    return text
  end
end

function Label:init(textOpt, fgColorOpt, bgColorOpt, alignOpt)
  Widget.init(self)

  self.text = ""
  self.fgColor = nil
  self.bgColor = nil
  self.fill = true
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

function Label:setFilled(filled)
  self.fill = filled
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
  local natural = Size:new(math.max(1, #self.text), 1)
  return Requisition:new(minimum, natural)
end

function Label:setAllocation(allocation)
  Widget.setAllocation(self, allocation)
end

function Label:render(context)
  if self.fill then
    context:clear(self.bgColor)
  end

  local width = context:getWidth()
  local visible
  if #self.text < width then
    visible = alignText(self.align, width, self.text)
  else
    visible = String.ellipsize(self.text, width)
  end

  context:renderString(Coord:new(0, 0), visible, self.fgColor, self.bgColor)
end

return Label
