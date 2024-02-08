local Class = require("lib.class")
local Window = require("lib.widget.display.window")
local Label = require("lib.widget.display.label")
local Box = require("lib.widget.container.box")

local ControlWindow = Class("ControlWindow", Window)

function ControlWindow:init()
  Window.init(self)

  self.statusLeft = Label:new("Reactor Control", colors.black, colors.gray)
  self.statusRight = Label:new("", colors.white, colors.gray)
  self:updateStatusString()

  local status = Box:new("horizontal")
  status:addChild(self.statusLeft, "start", true, true)
  status:addChild(self.statusRight, "end", false, false)

  local box = Box:new("vertical")
  box:addChild(Label:new("Control Window", colors.black, colors.cyan), "start", true, true)
  box:addChild(status, "start", false, false)

  self:setChild(box)
end

function ControlWindow:updateStatusString()
  self.statusLeft:setText(("Reactor Control"))

  local time = os.time()
  local hour = math.floor(time)
  local minute = math.floor(60 * (time - hour))

  self.statusRight:setText(("%02d:%02d"):format(hour, minute))
end

function ControlWindow:update()
  self:updateStatusString()
end

return ControlWindow
