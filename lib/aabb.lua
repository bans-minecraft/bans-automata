local class = require("lib.class")

local AABB = class("AABB")

function AABB:init()
  self.minX = math.huge
  self.minY = math.huge
  self.minZ = math.huge
  self.maxX = -math.huge
  self.maxY = -math.huge
  self.maxZ = -math.huge
end

function AABB:addPoint(x, y, z)
  self.minX = math.min(self.minX, x)
  self.minY = math.min(self.minY, y)
  self.minZ = math.min(self.minZ, z)
  self.maxX = math.max(self.maxX, x)
  self.maxY = math.max(self.maxY, y)
  self.maxZ = math.max(self.maxZ, z)
  return self
end

function AABB:contains(x, y, z)
  return x >= self.minX and x <= self.maxX and y >= self.minY and y <= self.maxY and z >= self.minZ and z <= self.maxZ
end

return AABB

