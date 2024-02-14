local _, pretty = pcall(require, "cc.pretty")
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
M.echo = true
M.indent = 0

M.setEcho = function(echo)
  M.echo = echo
end

M.setIndent = function(indent)
  M.indent = indent
end

M.setLogFile = function(name, fresh)
  M.logfile = name
  if fresh and fs.exists(name) then
    fs.delete(name)
  end
end

local INDENT_STRING = "                                                                                "

M.write = function(level, message)
  if M.echo and term and level then
    term.setTextColor(level[2])
  end

  local indent = string.sub(INDENT_STRING, 1, M.indent * 4)

  if level then
    message = ("[%s] %s%s"):format(level[1], indent, message)
  else
    message = ("        %s%s"):format(indent, message)
  end

  if M.echo then
    print(message)
    if term and colors then
      term.setTextColor(colors.white)
    end
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
      table.insert(args, prettyPrint(v))
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
