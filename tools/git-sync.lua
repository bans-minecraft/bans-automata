local Base64 = require("lib.base64")

local HOST = "git.blakerain.com"
local REPO = "BlakeRain/bans-automata"

local function getJson(path)
  local url = ("https://%s/api/v1/%s"):format(HOST, path)
  local response = http.get(url, nil, false)
  if not response then
    print("Failed to get response from " .. url)
    return nil
  end

  local json = response.readAll()
  response.close()
  return textutils.unserializeJSON(json)
end

local function isLuaFile(path)
  return path:sub(-4) == ".lua"
end

local function getLuaPaths(path)
  local url = ("%s/contents"):format(REPO);
  if path then
    url = ("%s/%s"):format(url, path)
  end

  local found = {}
  local response = getJson(url)
  for _, obj in ipairs(response) do
    if obj.type == "file" and isLuaFile(obj.name) then
      table.insert(found, obj.path)
    end

    if obj.type == "dir" then
      local sub = getLuaContents(obj.path)
      for _, file in ipairs(sub) do
        table.insert(found, file)
      end
    end
  end

  return found
end

local function downloadLuaFiles(dest)
  local paths = getLuaPaths()
  for _, path in ipairs(paths) do
    local url = ("%s/contents/%s"):format(REPO, path)
    local response = getJson(url)
    local file = fs.open(fs.combine(dest, path), "w")
    file.write(Base64.decode(response.content))
    file.close()
  end
end

local function main(args)
  local args = args or {}
  local dest = args[1] or "."
  downloadLuaFiles(dest)
end

main({ ... })
