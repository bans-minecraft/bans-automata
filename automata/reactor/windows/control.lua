local Class = require("lib.class")
local Window = require("lib.widget.display.window")
local Label = require("lib.widget.display.label")
local Box = require("lib.widget.container.box")
local StatusBar = require("lib.widget.display.statusbar")

local ControlWindow = Class("ControlWindow", Window)

function ControlWindow:init()
  Window.init(self)

  local status = StatusBar:new()
  self.statusLeft = Label:new("Reactor Control")
  self.statusRight = Label:new("")
  status:addChild(self.statusLeft, "start")
  status:addChild(self.statusRight, "end")

  local box = Box:new("vertical")
  box:addChild(Label:new("Control Window"), "start", true, true)
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
