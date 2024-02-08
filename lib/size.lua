local Assert = require("lib.assert")
local Class = require("lib.class")

local Size = Class("Size")

function Size:init(width, height)
  Assert.assertIs(width, "number")
  Assert.assertIs(height, "number")
  self.width = width
  self.height = height
end

function Size.static.deserialize(data)
  Assert.assertIs(data, "table")
  Assert.assertIs(data.width, "number")
  Assert.assertIs(data.height, "number")
  return Size:new(data.width, data.height)
end

function Size:serialize()
  return { width = self.width, height = self.height }
end

function Size:clone()
  return Size:new(self.width, self.height)
end

function Size:expand(width, height)
  self.width = self.width + width
  self.height = self.height + height
end

function Size:__tostring()
  return ("[instance Size(%d x %d)]"):format(self.width, self.height)
end

return Size
