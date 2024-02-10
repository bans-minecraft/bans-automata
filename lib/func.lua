local Table = require("lib.table")

local Func = {}

Func.bind1 = function(func, arg1)
  return function(...) return func(arg1, ...) end
end

Func.bind2 = function(func, arg2)
  return function(arg1, ...) return func(arg1, arg2, ...) end
end

Func.bind3 = function(func, arg3)
  return function(arg1, arg2, ...) return func(arg1, arg2, arg3, ...) end
end

Func.const = function(value)
  return function()
    return value
  end
end

Func.identity = function(value)
  return value
end

Func.compose = function(...)
  local args = table.pack(...)
  return Table.reduce(args, function(f, g)
    return function(...)
      return f(g(...))
    end
  end)
end

return Func
