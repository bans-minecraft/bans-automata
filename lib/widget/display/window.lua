local Class = require("lib.class")
local Size = require("lib.size")
local Rect = require("lib.rect")
local Coord = require("lib.coord")
local Bin = require("lib.widget.container.bin")
local RenderContext = require("lib.widget.render.context")
local Log = require("lib.log")

local Window = Class("Window", Bin)

function Window:init()
  Bin.init(self)
end

function Window:renderWindow()
  local width, height = term.getSize()
  Log.info(("Window:renderWindow width = %d, height = %d"):format(width, height))
  local size = Size:new(width, height)
  Log.info(("Window:renderWindow size = %s"):format(size))
  local context = RenderContext:new()

  term.clear()
  local requisition = self:getSizeRequest()
  Log.info(("Window:renderWindow requisition = %s"):format(requisition))
  self:setAllocation(Rect:new(Coord:new(1, 1), size))
  self:render(context)
end

return Window
