local Assert = require("lib.assert")

local M = {}

M.eraseAll = function(ts)
  for i = 1, #ts do
    table.remove(ts, i)
  end

  for i in pairs(ts) do
    ts[i] = nil
  end
end

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

M.indexOf = function(ts, value, start)
  start = start or 1
  if start < 0 then
    start = #ts + start + 1
  end

  for index = start, #ts do
    if ts[index] == value then
      return index
    end
  end

  return nil
end

M.clone = function(ts)
  local result = {}
  for key, value in pairs(ts) do
    result[key] = value
  end

  return result
end

M.isEmpty = function(ts)
  for _, value in pairs(ts) do
    if value ~= nil then
      return false
    end
  end

  return true
end

M.map = function(ts, func, ...)
  Assert.assertIsIndexable(ts)
  Assert.assertIsCallable(func)

  local result = {}
  for key, value in pairs(ts) do
    result[key] = func(value, ...)
  end

  return result
end

M.imap = function(ts, func, ...)
  Assert.assertIsIndexable(ts)
  Assert.assertIsCallable(func)

  local result = {}
  for index = 1, #ts do
    result[index] = func(ts[index], ...) or false
  end

  return result
end

M.mapn = function(func, ...)
  Assert.assertIsCallable(func)
  local result = {}
  local tables = { ... }

  local min_count = 1e40
  for index = 1, #tables do
    min_count = math.min(min_count, #(tables[index]))
  end

  for i = 1, min_count do
    local args = {}
    local k = 1

    for j = 1, #tables do
      args[k] = tables[j][i]
      k = k + 1
    end

    result[#result + 1] = func(table.unpack(args))
  end

  return result
end

M.transform = function(ts, func, ...)
  Assert.assertIsIndexable(ts)
  Assert.assertIsCallable(func)

  for key, value in pairs(ts) do
    ts[key] = func(value, ...)
  end
end

M.zip = function(...)
  return M.mapn(function(...) return { ... } end, ...)
end

M.zipWith = function(as, bs, func, ...)
  Assert.assertIsIndexable(as)
  Assert.assertIsIndexable(bs)
  Assert.assertIsCallable(func)

  local result = {}
  local limit = math.min(#as, #bs)

  for index = 1, limit do
    result[index] = func(as[index], bs[index], ...)
  end

  return result
end

M.reduce = function(ts, func, init, ...)
  Assert.assertIsIndexable(ts)
  Assert.assertIsCallable(func)

  local count = #ts
  if count == 0 then
    return init
  end

  local result = init and func(init, ts[1]) or ts[1]
  for index = 2, count do
    result = func(result, ts[index], ...)
  end

  return result
end

M.filter = function(ts, func, ...)
  Assert.assertIsIndexable(ts)
  Assert.assertIsCallable(func)

  local result = {}
  for key, value in pairs(ts) do
    if func(value, ...) then
      result[key] = value
    end
  end

  return result
end

return M
