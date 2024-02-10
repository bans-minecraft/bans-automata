local Assert = require("lib.assert")
local Log = require("lib.log")

local M = {}

M.choose = function(condition, true_value, false_value)
  if condition then return true_value else return false_value end
end

M.clone = function(value)
  local value_type = type(value)
  if value_type == "nil" or value_type == "number" or value_type == "boolean" or value_type == "string" then
    return value
  elseif value_type == "table" then
    if type(value.clone) == "function" then
      return value:clone()
    else
      return M.cloneTable(value)
    end
  else
    error(("Cannot clone value of type '%s'"):format(value_type))
  end
end

M.applyDefaults = function(dest, defaults)
  for key, value in pairs(defaults) do
    if dest[key] == nil then
      if type(value) == "table" then
        dest[key] = M.cloneTable(value)
      else
        dest[key] = value
      end
    else
      if type(value) == "table" and type(dest[key]) == "table" then
        dest[key] = M.applyDefaults(dest[key], value)
      end
    end
  end
end

M.loadConfig = function(config_path, defaults)
  if not fs.exists(config_path) then
    Log:warn("Configuration file does not exist: " .. config_path)
    return M.cloneTable(defaults or {})
  end

  local file = fs.open(config_path, "r")
  local contents = file.readAll()
  file.close()

  local config = textutils.unserialize(contents)
  Assert.assertIs(config, "table")

  return M.applyDefaults(config, defaults or {})
end

M.numberOrDefault = function(value, default)
  if value == nil then
    return default
  end

  Assert.assertIs(value, "number")
  return value
end

M.generateId = function(length)
  local id = ""

  math.randomseed(os.epoch() ^ 5)
  for _ = 1, length do
    id = id .. string.char(math.random(97, 122))
  end

  return id
end

M.memoize = function(func)
  local cache = {}

  return function(arg)
    local result = cache[arg]

    if result == nil then
      result = func(arg)
      cache[arg] = result
    end

    return result
  end
end

return M
