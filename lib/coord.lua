local Log = require("lib.log")

local Coord = {}
Coord.__index = Coord
Coord.__name = "Coord"

function Coord:create(row, col)
  Log.assertIs(row, "number")
  Log.assertIs(col, "number")
  local coord = { row = row, col = col }
  setmetatable(coord, Coord)
  return coord
end

function Coord:deserialize(data)
  Log.assertIs(data, "table")
  Log.assertIs(data.row, "number")
  Log.assertIs(data.col, "number")
  return Coord:create(data.row, data.col)
end

function Coord:serialize()
  return { row = self.row, col = self.col }
end

function Coord:clone()
  return Coord:create(self.row, self.col)
end

function Coord:toIndex(stride)
  Log.assertIs(stride, "number")
  return self.col + (self.row - 1) * stride
end

function Coord:__tostring()
  return ("%d:%d"):format(self.row, self.col)
end

return Coord
