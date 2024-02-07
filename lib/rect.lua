local Assert = require("lib.assert")
local Class = require("lib.class")
local Size = require("lib.size")
local Coord = require("lib.coord")

local Rect = Class("Rect")

function Rect:init(position, size)
  Assert.assertInstance(position, Coord)
  Assert.assertInstance(size, Size)
  self.position = position
  self.size = size
end

function Rect.static.make(row, col, width, height)
  return Rect:new(Coord:new(row, col), Size:new(width, height))
end

function Rect.static.createEmpty()
  return Rect:new(Coord:new(1, 1), Size:new(0, 0))
end

function Rect.static.deserialize(data)
  Assert.assertIs(data, "table")
  local position = Coord.deserialize(data.position)
  local size = Size.deserialize(data.size)
  return Rect:new(position, size)
end

function Rect:serialize()
  return {
    position = self.position:serialize(),
    size = self.size:serialize()
  }
end

function Rect:clone()
  return Rect:new(self.position:clone(), self.size:clone())
end

function Rect:__tostring()
  return ("%s;%s"):format(self.position, self.size)
end

return Rect
