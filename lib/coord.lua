local Assert = require("lib.assert")
local class = require("lib.class")

local Coord = class("Coord")

function Coord:init(row, col)
  Assert.assertIs(row, "number")
  Assert.assertIs(col, "number")
  self.row = row
  self.col = col
end

function Coord.static.deserialize(data)
  Assert.assertIs(data, "table")
  Assert.assertIs(data.row, "number")
  Assert.assertIs(data.col, "number")
  return Coord:new(data.row, data.col)
end

function Coord:serialize()
  return { row = self.row, col = self.col }
end

function Coord:clone()
  return Coord:new(self.row, self.col)
end

function Coord:toIndex(stride)
  Assert.assertIs(stride, "number")
  return self.col + (self.row - 1) * stride
end

function Coord:__tostring()
  return ("[instance Coord(r%d,c%d)]"):format(self.row, self.col)
end

return Coord
