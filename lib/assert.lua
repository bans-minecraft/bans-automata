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
  local message
  if messageOpt ~= nil then
    message = ("Assertion failed: %s"):format(message)
  else
    message = ("Assertion failed: expected '%s'; found '%s'"):format(type_name, type(value))
  end

  if type(value) ~= type_name then
    error(message)
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
