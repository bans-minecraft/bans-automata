local Assert = require("lib.assert")
local Box = require("lib.widget.container.box")
local Class = require("lib.class")
local Label = require("lib.widget.display.label")

local StatusBar = Class("StatusBar", Box)

function StatusBar:init()
  Box.init(self, "horizontal", colors.blue)
end

function StatusBar:addLabelStart(textOpt, colorOpt)
  local label = Label:new(textOpt, colorOpt or colors.lightBlue, colors.blue)
  self:addChild(label, "start")
  return label
end

function StatusBar:addLabelEnd(textOpt, colorOpt)
  local label = Label:new(textOpt, colorOpt or colors.lightBlue, colors.blue)
  self:addChild(label, "end")
  return label
end

return StatusBar
