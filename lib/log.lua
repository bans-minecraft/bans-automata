local pretty = pcall(require, "cc.pretty")
local prettyPrint
if pretty then
  prettyPrint = function(value, width)
    return pretty.render(pretty.pretty(value), width)
  end
else
  local inspect = require("inspect")
  prettyPrint = function(value, width)
    return inspect(value)
  end
end

local M = {}
M.level = {
  info = { "INFO ", colors and colors.cyan },
  warn = { "WARN ", colors and colors.yellow },
  error = { "ERROR", colors and colors.red },
}

M.logfile = nil

M.setLogFile = function(name, fresh)
  M.logfile = name
  if fresh and fs.exists(name) then
    fs.delete(name)
  end
end

M.write = function(level, message)
  if term and level then
    term.setTextColor(level[2])
  end

  if level then
    message = ("[%s] %s"):format(level[1], message)
  else
    message = ("        %s"):format(message)
  end

  print(message)
  if term and colors then
    term.setTextColor(colors.white)
  end

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
      table.insert(args, prettyPrint(v, 30))
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


local function trapHandler(err)
  M.error("Error called:", err)
  return err
end

M.trap = function(func, ...)
  local args = { ... }
  local stub = function()
    func(table.unpack(args))
  end

  return xpcall(stub, trapHandler)
end

return M

