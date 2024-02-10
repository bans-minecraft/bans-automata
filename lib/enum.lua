local Enum = {}

function Enum.enum(...)
  local first = select(1, ...)
  local enumeration = {}
  local enumerators = {}

  if type(first) ~= "table" then
    enumerators = table.pack(...)
    for index, value in ipairs(enumerators) do
      if type(value) ~= "string" then
        error(("Expected enumerator at %d to be a string; found '%s'"):format(index, type(value)))
      end

      enumeration[value] = value
    end
  else
    if type(first) ~= "table" then
      error(("Expected first argument to be a table; found '%s'"):format(type(first)))
    end

    for index, value in ipairs(first) do
      if type(value) ~= "string" then
        error(("Expected 'string' at index %d; found '%s'"):format(index, type(value)))
      end

      enumerators[index] = value
      enumeration[value] = value
    end

    for key, value in pairs(first) do
      if type(key) == "string" then
        if enumeration[key] ~= nil then
          error(("Duplicate enumerator '%s' found in array and hash part"):format(key))
        end

        enumeration[key] = value
        enumerators[#enumerators + 1] = key
      end
    end
  end

  if not enumerators[1] then
    error("Expected at least one enumerator")
  end

  local expected = "; expected one of: '" .. table.concat(enumerators, "', '") .. "'"

  setmetatable(enumeration, {
    __index = function(self, key)
      error(("'%s' is not a valid enumerator%s"):format(tostring(key), expected))
    end,

    __newindex = function(self, key, value)
      error("enumeration is read-only")
    end,

    __call = function(self, key)
      if type(key) == "string" then
        local value = rawget(self, key)
        if value ~= nil then
          return value
        end
      end

      return nil, ("'%s' is not a valid enumerator%s"):format(tostring(key), expected)
    end
  })

  return enumeration
end

setmetatable(Enum, {
  __call = function(_, ...)
    return Enum.enum(...)
  end
})

return Enum
