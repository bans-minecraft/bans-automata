local M = {}

M.is = function(value, classOrType)
  local t = type(classOrType)
  if t == "string" then
    return type(value) == classOrType
  elseif t == "table" then
    return value.__index == classOrType
  else
    error(("Expected either 'string' or 'table' in second argument to is(); found '%s'"):format(t))
  end
end

M.isCallable = function(obj)
  return type(obj) == "function" or getmetatable(obj) and getmetatable(obj).__call and true
end

M.isIndexable = function(obj)
  if type(obj) == "table" then
    return true
  end

  local meta = getmetatable(obj)
  if meta and meta.__len and meta.__index then
    return true
  end

  return false
end

M.isIterable = function(obj)
  if type(obj) == "table" then
    return true
  end

  local meta = getmetatable(obj)
  if meta and meta.__pairs then
    return true
  end

  return false
end

M.isWritable = function(obj)
  if type(obj) == "table" then
    return true
  end

  local meta = getmetatable(obj)
  if meta and meta.__newindex then
    return true
  end

  return false
end

M.typeName = function(obj)
  if type(obj) == "table" then
    if obj.__index and type(obj.__index.isInstanceOf) == "function" and type(obj.class) == "table" then
      return obj.class
    end
  end

  return type(obj)
end

M.isNil = function(value) return value == nil end
M.isBoolean = function(value) return type(value) == "boolean" end
M.isNumber = function(value) return type(value) == "number" end
M.isString = function(value) return type(value) == "string" end
M.isTable = function(value) return type(value) == "table" end

M.isInteger = function(value)
  return type(value) == "number" and math.ceil(value) == value
end

return M
