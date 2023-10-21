local pretty = require("cc.pretty")

local M = {}
M.level = {
  info = { "INFO ", colors.cyan },
  warn = { "WARN ", colors.yellow },
  error = { "ERROR", colors.red }
}

M.logfile = nil

M.setLogFile = function(name)
  M.logfile = name
end

M.write = function(level, message)
  if level then
    term.setTextColor(level[2])
  end

  if level then
    message = ("[%s] %s"):format(level[1], message)
  else
    message = ("        %s"):format(message)
  end

  print(message)
  term.setTextColor(colors.white)

  if M.logfile ~= nil then
    local file = fs.open(M.logfile, "a")
    file.writeLine(message)
    file.close()
  end
end

M.log = function(level, ...)
  local level_info = M.level[level]
  if level_info == nil then
    level_info = M.level.error
  end

  local args = {}
  for _, v in ipairs({ ... }) do
    if type(v) == "string" then
      table.insert(args, v)
    elseif v == nil then
      table.insert(args, "nil")
    else
      table.insert(args, pretty.render(pretty.pretty(v), 30))
    end
  end

  M.write(level_info, table.concat(args, " "))
  if level == "error" then
    M.write(nil, debug.traceback())
  end
end

for level, _ in pairs(M.level) do
  M[level] = function(...)
    M.log(level, ...)
  end
end

M.assert = function(value)
  if not value then
    M.error("Assertion failed")
  end
end

M.assertIs = function(value, type_name)
  if type(value) ~= type_name then
    M.error("Assertion failed: expected", type_name, "found", type(value))
  end
end

M.assertClass = function(value, class)
  if type(value) ~= "table" or value.__index ~= class then
    local found = type(value)
    if value.__index and value.__index.__name then
      found = value.__index.__name
    end

    M.error("Assertion failed: expected", class.__name, "found", type(value))
  end
end

return M
