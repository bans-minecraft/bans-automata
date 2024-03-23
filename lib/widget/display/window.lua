local Class = require("lib.class")
local Bin = require("lib.widget.container.bin")

local Window = Class("Window", Bin)

function Window:init(bgColorOpt)
  Bin.init(self, bgColorOpt)
  self.redrawQueued = true
end

function Window:queueRedraw()
  Bin.queueRedraw(self)
  self.redrawQueued = true
end

function Window:isRedrawQueued()
  return self.redrawQueued
end

function Window:clearRedraw()
  self.redrawQueued = false
end

return Window
