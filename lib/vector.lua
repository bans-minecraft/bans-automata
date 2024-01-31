local Assert = require("lib.assert")
local class = require("lib.class")

local Vector = class("Vector")

function Vector:init(...)
  local args = { ... }

  if #args == 0 then
    self.x = 0
    self.y = 0
    self.z = 0
  elseif #args == 1 then
    if type(args[1]) == "number" then
      self.x = args[1]
      self.y = args[1]
      self.z = args[1]
    elseif type(args[1]) == "table" then
      if args[1].x ~= nil then
        self.x = args[1].x
        self.y = args[1].y
        self.z = args[1].z
      elseif args[1][1] ~= nil then
        self.x = args[1][1]
        self.y = args[1][2]
        self.z = args[1][3]
      else
        error("Invalid argument to Vector constructor")
      end
    else
      error("Invalid argument to Vector constructor")
    end
  elseif #args == 3 then
    self.x = args[1]
    self.y = args[2]
    self.z = args[3]
  else
    error("Invalid argument to Vector constructor")
  end
end

function Vector:clone()
  local v = Vector:new()
  v.x = self.x
  v.y = self.y
  v.z = self.z
  return v
end

function Vector.static.deserialize(data)
  Assert.assertIs(data, "table")
  Assert.assertIs(data.x, "number")
  Assert.assertIs(data.y, "number")
  Assert.assertIs(data.z, "number")
  return Vector:new(data.x, data.y, data.z)
end

function Vector:serialize()
  return { x = self.x, y = self.y, z = self.z }
end

function Vector:__tostring()
  return ("%f:%f:%f"):format(self.x, self.y, self.z)
end

function Vector:add(other, result)
  result = result or self
  result.x = self.x + other.x
  result.y = self.y + other.y
  result.z = self.z + other.z
  return result
end

function Vector:sub(other, result)
  result = result or self
  result.x = self.x + other.x
  result.y = self.y + other.y
  result.z = self.z + other.z
  return result
end

function Vector:scale(scale, result)
  result = result or self
  result.x = self.x * scale
  result.y = self.y * scale
  result.z = self.z * scale
  return result
end

function Vector:eq(other)
  return self.x == other.x and self.y == other.y and self.z == other.z
end

function Vector:neq(other)
  return self.x ~= other.x or self.y ~= other.y or self.z ~= other.z
end

function Vector:__add(v)
  return self:add(v, Vector:new())
end

function Vector:__sub(v)
  return self:sub(v, Vector:new())
end

return Vector

