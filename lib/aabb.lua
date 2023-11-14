local AABB = {}
AABB.__index = AABB
AABB.__name = "AABB"

function AABB:create()
  local instance = {
    minX = math.huge,
    minY = math.huge,
    minZ = math.huge,
    maxX = -math.huge,
    maxY = -math.huge,
    maxZ = -math.huge,
  }

  setmetatable(instance, AABB)
  return instance
end

function AABB:addPoint(x, y, z)
  self.minX = math.min(self.minX, x)
  self.minY = math.min(self.minY, y)
  self.minZ = math.min(self.minZ, z)
  self.maxX = math.max(self.maxX, x)
  self.maxY = math.max(self.maxY, y)
  self.maxZ = math.max(self.maxZ, z)
end

function AABB:contains(x, y, z)
  return x >= self.minX and x <= self.maxX and y >= self.minY and y <= self.maxY and z >= self.minZ and z <= self.maxZ
end

return AABB
