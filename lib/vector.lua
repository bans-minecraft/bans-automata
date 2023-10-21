local M = {}
M.__index = M
M.__name = "Vector"

function M:create(...)
  local args = { ... }
  local v    = {}
  setmetatable(v, M)

  if #args == 0 then
    v.x = args[1]
    v.y = args[2]
    v.z = args[3]
  elseif #args == 1 then
    if type(args[1]) == "number" then
      v.x = args[1]
      v.y = args[1]
      v.z = args[1]
    elseif type(args[1]) == "table" then
      if args[1].x ~= nil then
        v.x = args[1].x
        v.y = args[1].y
        v.z = args[1].z
      elseif args[1][1] ~= nil then
        v.x = args[1][1]
        v.y = args[1][2]
        v.z = args[1][3]
      else
        error("Invalid argument to Vector constructor")
      end
    else
      error("Invalid argument to Vector constructor")
    end
  elseif #args == 3 then
    v.x = args[1]
    v.y = args[2]
    v.z = args[3]
  else
    error("Invalid argument to Vector constructor")
  end

  return v
end

function M:clone()
  local v = M:create()
  v.x = self.x
  v.y = self.y
  v.z = self.z
  return v
end

function M:__tostring()
  return ("%f:%f:%f"):format(self.x, self.y, self.z)
end

function M:add(other, result)
  result = result or self
  result.x = self.x + other.x
  result.y = self.y + other.y
  result.z = self.z + other.z
  return result
end

function M:sub(other, result)
  result = result or self
  result.x = self.x + other.x
  result.y = self.y + other.y
  result.z = self.z + other.z
  return result
end

function M:scale(scale, result)
  result = result or self
  result.x = self.x * scale
  result.y = self.y * scale
  result.z = self.z * scale
  return result
end

function M:eq(other)
  return self.x == other.x and self.y == other.y and self.z == other.z
end

function M:neq(other)
  return self.x ~= other.x or self.y ~= other.y or self.z ~= other.z
end

function M:__add(v)
  return self:add(v, M:create())
end

function M:__sub(v)
  return self:sub(v, M:create())
end

return M
