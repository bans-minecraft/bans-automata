local Log = require("lib.log")

local M = {}

M.concat = function(dest, src)
  for i = 1, #src do
    dest[#dest + 1] = src[i]
  end

  return dest
end

M.contains = function(ts, value)
  for _, v in pairs(ts) do
    if v == value then
      return true
    end
  end

  return false
end

M.isEmpty = function(ts)
  for _, value in pairs(ts) do
    if value ~= nil then
      return false
    end
  end

  return true
end

M.cloneTable = function(ts)
  local result = {}
  for key, value in pairs(ts) do
    if type(value) == "table" then
      value = M.cloneTable(value)
    end

    result[key] = value
  end

  return result
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
  Log.assertIs(config, "table")

  return M.applyDefaults(config, defaults or {})
end

return M
