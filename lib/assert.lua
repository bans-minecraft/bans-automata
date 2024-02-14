local Types = require("lib.types")

local M = {}

M.assert = function(value, message)
  if not value then
    if message then
      error("Assertion failed: " .. message)
    else
      error("Assertion failed")
    end
  end
end

M.assertEq = function(value, expected, message)
  if value ~= expected then
    if message then
      error("Assertion failed: " .. message)
    else
      error(("Assertion failed: expected '%s' to be equal to '%s'"):format(value, expected))
    end
  end
end

M.assertNeq = function(value, expected, message)
  if value == expected then
    if message then
      error("Assertion failed: " .. message)
    else
      error(("Assertion failed: expected '%s' to not be equal to '%s'"):format(value, expected))
    end
  end
end

M.assertIs = function(value, type_name, messageOpt)
  if type(value) ~= type_name then
    if messageOpt ~= nil then
      error(("Assertion failed: %s"):format(messageOpt))
    else
      error(("Assertion failed: expected '%s'; found '%s'"):format(type_name), type(value))
    end
  end
end

M.assertIsNil = function(value, messageOpt) M.assert(value == nil, messageOpt or "expected value to be nil") end
M.assertIsBoolean = function(value, messageOpt) M.assertIs(value, "boolean", messageOpt) end
M.assertIsNumber = function(value, messageOpt) M.assertIs(value, "number", messageOpt) end
M.assertIsString = function(value, messageOpt) M.assertIs(value, "string", messageOpt) end
M.assertIsTable = function(value, messageOpt) M.assertIs(value, "table", messageOpt) end

M.assertIsCallable = function(value, messageOpt)
  if not Types.isCallable(value) then
    if messageOpt ~= nil then
      error(("Assertion failed: %s"):format(messageOpt))
    else
      error(("Assertion failed: expected callable; found '%s'"):format(type(value)))
    end
  end
end

M.assertIsIndexable = function(value, messageOpt)
  if not Types.isIndexable(value) then
    if messageOpt ~= nil then
      error(("Assertion failed: %s"):format(messageOpt))
    else
      error(("Assertion failed: expected indexable; found '%s'"):format(type(value)))
    end
  end
end

M.assertIsIterable = function(value, messageOpt)
  if not Types.isIterable(value) then
    if messageOpt ~= nil then
      error(("Assertion failed: %s"):format(messageOpt))
    else
      error(("Assertion failed: expected iterable; found '%s'"):format(type(value)))
    end
  end
end

M.assertIsWritable = function(value, messageOpt)
  if not Types.isWritable(value) then
    if messageOpt ~= nil then
      error(("Assertion failed: %s"):format(messageOpt))
    else
      error(("Assertion failed: expected writable; found '%s'"):format(type(value)))
    end
  end
end

M.assertInstance = function(value, class)
  if type(value) ~= "table" then
    error("Assertion failed: expected instance of '" .. tostring(class) .. "'; found " .. type(value))
  end

  if not class:isInstance(value) then
    error("Assertion failed: expected instance of '" .. tostring(class) .. "'; found " .. tostring(value))
  end
end

return M
