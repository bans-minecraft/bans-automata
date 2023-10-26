local function copy(target, path)
  if fs.isDir(path) then
    if not fs.isDir(target) then
      print("Creating directory: " .. target)
      fs.makeDir(target)
    end

    local files = fs.list(path)
    for _, inner in ipairs(files) do
      copy(fs.combine(target, inner), fs.combine(path, inner))
    end
  else
    print("Creating file: " .. target)
    fs.copy(path, target)
  end
end

local args = { ... }
if #args < 1 then
  local prog = args[0] or fs.getName(shell.getRunningProgram())
  print("usage: " .. prog .. " <destination>")
  return
end

local SOURCES = { "automata", "lib", "tools" }
for _, source in ipairs(SOURCES) do
  copy(fs.combine(args[1], source), source)
end