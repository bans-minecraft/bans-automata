local Assert = require("lib.assert")

local M = {}

M.isAlpha = function(str)
  Assert.assertIsString(str)
  return string.find(str, "^%a+$") == 1
end

M.isDigit = function(str)
  Assert.assertIsString(str)
  return string.find(str, "^%d+$") == 1
end

M.isAlnum = function(str)
  Assert.assertIsString(str)
  return string.find(str, "^%w+$") == 1
end

M.isSpace = function(str)
  Assert.assertIsString(str)
  return string.find(str, "^%s+$") == 1
end

M.isLower = function(str)
  Assert.assertIsString(str)
  return string.find(str, "^[%l%s]+$") == 1
end

M.isUpper = function(str)
  Assert.assertIsString(str)
  return string.find(str, "^[%u%s]+$") == 1
end

M.contains = function(str, sub)
  Assert.assertIsString(str)
  Assert.assertIsString(sub)
  return str.find(sub, 1, true) ~= nil
end

M.startsWith = function(str, prefix)
  Assert.assertIsString(str)
  Assert.assertIsString(prefix)
  return str:sub(1, #prefix) == prefix
end

M.replace = function(str, old, new)
  Assert.assertIsString(str)
  Assert.assertIsString(new)
  Assert.assertIsString(new)

  local start = 1
  while true do
    local start_ix, end_ix = str:find(old, start, true)
    if not start_ix then
      break
    end

    local post = str:sub(end_ix + 1)
    str = str:sub(1, (start_ix - 1)) .. new .. post
    start = -1 * post:len()
  end

  return str
end

M.insert = function(str, pos, text)
  Assert.assertIsString(str)
  Assert.assertIsNumber(pos)
  Assert.assertIsString(text)
  return str:sub(1, pos - 1) .. text .. str:sub(pos)
end

local ELLIPSIS = "..."
local ELLIPSIS_LEN = #ELLIPSIS

M.ellipsize = function(str, width)
  Assert.assertIsString(str)
  Assert.assertIsNumber(width)

  if #str > width then
    if width < ELLIPSIS_LEN then
      return ELLIPSIS:sub(1, width)
    end

    return str:sub(1, width - ELLIPSIS_LEN) .. ELLIPSIS
  end

  return str
end

M.leftAlign = function(str, width, char)
  return str .. string.rep(char or ' ', width - #str)
end

M.rightAlign = function(str, width, char)
  return string.rep(char or ' ', width - #str) .. str
end

M.centerAlign = function(str, width, char)
  char = char or ' '
  local pad = width - #str
  local left = math.floor(pad / 2)
  local right = math.ceil(pad / 2)
  return string.rep(char, left) .. str .. string.rep(char, right)
end

local TRUTHY_STRINGS = {
  yes = true,
  y = true,
  on = true,
  t = true,
  ["true"] = true,
  ["1"] = true
}

M.parseBoolean = function(str)
  Assert.assertIsString(str)
  str = str:lower()
  if TRUTHY_STRINGS[str] then
    return true
  end

  return false
end

return M
