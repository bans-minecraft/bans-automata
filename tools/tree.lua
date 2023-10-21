local BEAMS = {}

local function beams()
  return table.concat(BEAMS)
end

local function list(path)
  local files = fs.list(path)
  for i = 1, #files do
    local path = fs.combine(path, files[i])
    local dir = fs.isDir(path)
    if i == #files then
      print(beams() .. "└─ " .. files[i])
    else
      print(beams() .. "├─ " .. files[i])
    end

    if dir then
      if i == #files then
        table.insert(BEAMS, "   ")
      else
        table.insert(BEAMS, "│  ")
      end

      list(path)
    end
  end
end

local function main(args)
  if #args == 0 then
    list(shell.dir())
  else
    for _, path in ipairs(args) do
      list(path)
    end
  end
end

main({ ... })
