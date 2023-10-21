--
--  ______         __         _______                                __
-- |   __ \.-----.|  |.--.--.|    ___|.--.--.----.---.-.--.--.---.-.|  |_.-----.----.
-- |    __/|  _  ||  ||  |  ||    ___||_   _|  __|  _  |  |  |  _  ||   _|  _  |   _|
-- |___|   |_____||__||___  ||_______||__.__|____|___._|\___/|___._||____|_____|__|
--                    |_____|
--
-- Given a file containing some configuration and a list of points, this program will excavate the
-- region enclosed by those points, down to the configured depth.
--
-- The configuration file should have the following form:
--
-- {
--   dir   = "north",       // The direction in which the bot is initially facing (default: "north")
--   start = { 150, 150 },  // Start position of the bot
--   depth = 10,            // The depth (relative to the start position) the bot should mine to
--   region = {             // A list of points defining a polygon to excavate
--     { 100, 200 },
--     { 100, 100 },
--     { 200, 100 },
--     { 200, 200 }
--   }
-- }
--

package.path      = "/?.lua;" .. package.path
local AANode      = require("lib.bot.aa.node");
local Bot         = require("lib.bot");
local Direction   = require("lib.direction");
local Log         = require("lib.logging");
local Vector      = require("lib.vector");

local Excavator   = {}
Excavator.__index = Excavator
Excavator.__name  = "Excavator"

function Excavator:create(config)
  local excavator = {}
  setmetatable(excavator, Excavator)

  excavator.config    = config
  excavator.bot       = Bot:create(config.dir)
  excavator.depth     = 0
  excavator.minZ      = math.huge
  excavator.maxZ      = -math.huge
  excavator.lines     = {}

  excavator.bot.pos.x = config.start.x
  excavator.bot.pos.z = config.start.z

  excavator:findExtents()
  excavator:scanlines()

  return excavator
end

function Excavator:findExtents()
  local minZ, maxZ = math.huge, -math.huge
  for _, coord in ipairs(self.config.region) do
    minZ = math.min(minZ, coord.z)
    maxZ = math.max(maxZ, coord.z)
  end

  self.minZ = minZ
  self.maxZ = maxZ
end

function Excavator:intersections(z)
  local intersections = {}
  for i = 1, #self.config.region do
    local v1, v2 = self.config.region[i], self.config.region[(i % #self.config.region) + 1]
    if (v1.z <= z and v2.z > z) or (v1.z > z and v2.z <= z) then
      local x = v1.x + (z - v1.z) * (v2.x - v1.x) / (v2.z - v1.z)
      table.insert(intersections, x)
    end
  end

  table.sort(intersections)
  return intersections
end

function Excavator:scanlines()
  self.lines = {}
  for z = self.minZ, self.maxZ do
    local intersections = self:intersections(z)
    for i = 1, #intersections, 2 do
      local x1 = math.ceil(intersections[i])
      local x2 = math.floor(intersections[i + 1])
      table.insert(self.lines, { z = z, x1 = x1, x2 = x2 })
    end
  end
end

function Excavator:moveForwards(count, dig)
  local moved = 0
  while moved < count do
    while true do
      local ok, err = self.bot:forward()
      if ok then break end

      if turtle.getFuelLevel() == 0 then
        Log.error("Ran out of fuel")
        return false, "out of fuel"
      end

      if not dig then
        Log.error("Bot was unable to move: blocked, unable to dig")
        return false, "unable to dig"
      end

      ok, err = self.bot:mineForward()
      if not ok then
        Log.error("Bot was unable to mine: " .. err)
        return false, err
      end
    end

    moved = moved + 1
  end

  return true
end

-- function Excavator:moveToSliceStart()
--   local x1 = self.lines[1].x1
--   local dx = x1 - self.bot.pos.x
--   Log.info(("Slice start X %.0f, bot is at %.0f; moving %.0f"):format(x1, self.bot.pos.x, dx))
--
--   if dx > 0 then
--     self.bot:face(Direction.East)
--     self:moveForwards(dx, true)
--   elseif dx < 0 then
--     self.bot:face(Direction.West)
--     self:moveForwards(-dx, true)
--   end
--
--   local z1 = self.minZ
--   local dz = z1 - self.bot.pos.z
--   Log.info(("Slice start Z %.0f, bot is at %.0f; moving %.0f"):format(z1, self.bot.pos.z, dz))
--
--   if dz > 0 then
--     self.bot:face(Direction.South)
--     self:moveForwards(dz, true)
--   elseif dz < 0 then
--     self.bot:face(Direction.North)
--     self:moveForwards(-dz, true)
--   end
-- end

function Excavator:moveZ(target)
  local dz = target - self.bot.pos.z
  if dz > 0 then
    self.bot:face(Direction.South)
    self:moveForwards(dz, true)
  elseif dz < 0 then
    self.bot:face(Direction.North)
    self:moveForwards(-dz, true)
  end
end

function Excavator:moveX(target)
  local dx = target - self.bot.pos.x
  if dx > 0 then
    self.bot:face(Direction.East)
    self:moveForwards(dx, true)
  elseif dx < 0 then
    self.bot:face(Direction.West)
    self:moveForwards(-dx, true)
  end
end

function Excavator:slice()
  self.bot:mineDown()
  self.bot:down()

  for i = 1, #self.lines do
    Log.info(("Line %d/%d"):format(i, #self.lines))
    local line = self.lines[i]
    Log.info("  Moving to Z " .. line.z)
    self:moveZ(line.z)
    Log.info("  Moving to x1 " .. line.x1)
    self:moveX(line.x1)
    self.bot:face(Direction.East)
    Log.info("  Mining to x2 " .. line.x2)
    self:moveForwards(line.x2 - line.x1, true)
  end

  -- for z = self.minZ, self.maxZ do
  --   self:moveZ(z)
  --   for i = 1, #self.lines do
  --     local line = self.lines[i]
  --     self:moveX(line.x1)
  --     self.bot:face(Direction.East)
  --     self:moveForwards(line.x2 - line.x1, true)
  --   end
  -- end
end

function Excavator:loop()
  self:slice()
end

---------------------------------------------------------------------------------------------------

local function main(args)
  local config_path = args[1] or (shell.dir() .. "/poly-excavator.cfg")
  if not fs.exists(config_path) then
    Log:error("Configuration file does not exist: " .. config_path)
    return
  end

  local file = fs.open(config_path, "r")
  local contents = file.readAll()
  file.close()

  local config = textutils.unserialize(contents)
  Log.assertIs(config, "table")

  if type(config.dir) == "string" then
    local dir = Direction.parseDirection(config.dir)
    if dir == nil then
      Log.error("Unrecognized direction in 'dir' with value '" .. config.dir .. "'")
      return
    end

    config.dir = dir
  elseif type(config.dir) == "number" then
    Direction.assertDir(config.dir)
  else
    Log.info("Missing 'dir' in config; assuming 'North'")
    config.dir = Direction.North
  end

  if type(config.start) ~= "table" then
    Log.error("Expected start to be a table, found " .. type(config.start))
    return
  end

  if #config.start ~= 2 then
    Log.error("Expected start to have 2 elements, found " .. #config.start)
    return
  end

  local x, z = config.start[1], config.start[2]
  if type(x) ~= "number" then
    Log.error("Expected start[1] to be a number, found " .. type(x))
    return
  end

  if type(z) ~= "number" then
    Log.error("Expected start[2] to be a number, found " .. type(z))
    return
  end

  config.start = Vector:create(x, 0, z)

  if type(config.depth) ~= "number" then
    Log.error("Expected depth to be a number, found " .. type(config.depth))
    return
  end

  if type(config.region) ~= "table" then
    Log.error("Expected region to be a table, found " .. type(config.region))
    return
  end

  local region = {}
  for index, point in ipairs(config.region) do
    if type(point) ~= "table" then
      Log.error("Expected region[" .. index .. "] to be a table, found " .. type(point))
      return
    end

    if #point ~= 2 then
      Log.error("Expected region[" .. index .. "] to have 2 elements, found " .. #point)
      return
    end

    x, z = point[1], point[2]

    if type(x) ~= "number" then
      Log.error("Expected region[" .. index .. "][1] to be a number, found " .. type(x))
      return
    end

    if type(z) ~= "number" then
      Log.error("Expected region[" .. index .. "][2] to be a number, found " .. type(z))
      return
    end

    table.insert(region, Vector:create(x, 0, z))
  end

  config.region = region

  local excavator = Excavator:create(config)
  excavator:loop()
end

main({ ... })
