local Direction = require("lib.direction")
local Vector = require("lib.vector")
local Log = require("lib.log")
local AA = require("lib.bot.aa")
local AANode = require("lib.bot.aa.node")

-- The Bot class
--
-- This class provides the functionality for diving the bot, performing mining actions, and
-- maintaining the AA.

local Bot = {}
Bot.__index = Bot
Bot.__name = "Bot"

Bot.FUEL_SLOT = 16 -- Inventory slot in which fuel is stored (default: 16)
Bot.MIN_FUEL = 1000 -- Minimum fiel required for operation (default: 1000)

function Bot:create(dir)
  local bot = {}
  setmetatable(bot, Bot)

  -- We keep track of the slot into which we should pace fuel, and the minimum amount of fuel that
  -- we need to operate.
  bot.fuelSlot = Bot.FUEL_SLOT
  bot.minFuel = Bot.MIN_FUEL

  -- The current position and direction of the bot. The position is typically relative to the start
  -- of the bot's process (often referred to as the "home" position). The direction should be the
  -- global (world) direction, as seen in the F3 debug overlay. if no direction is given in the
  -- `dir` argument to this constructor, we default to North.
  bot.pos = Vector:create()
  bot.start = Vector:create()
  bot.dir = dir or Direction.North

  -- Create the Area Awareness system
  bot.aa = AA:create()

  -- When the bot is created, perform a scan around our immediate environment to initialize the AA.
  bot:cacheAround()
  return bot
end

function Bot:deserialize(data)
  Log.assertIs(data, "table")
  Log.assertIs(data.fuelSlot, "number")
  Log.assertIs(data.minFuel, "number")
  Log.assertIs(data.dir, "number")

  local bot = Bot:create(data.dir)
  bot.fuelSlot = data.fuelSlot
  bot.minFuel = data.minFuel
  bot.pos = Vector:deserialize(data.pos)
  bot.start = Vector:deserialize(data.start)
  bot.aa = AA:deserialize(data.aa)

  return bot
end

function Bot:serialize()
  return {
    fuelSlot = self.fuelSlot,
    minFuel = self.minFuel,
    pos = self.pos:serialize(),
    start = self.start:serialize(),
    dir = self.dir,
    aa = self.aa:serialize(),
  }
end

function Bot:clearAA()
  self.aa:clear()
  self:cacheAround()
end

function Bot:relativePosition(dir)
  return Direction.offsetDirection(self.pos, dir)
end

function Bot:forwardPosition()
  return self:relativePosition(self.dir)
end

function Bot:leftDirection()
  return (self.dir + 1) % 4
end

function Bot:rightDirection()
  return (self.dir + 3) % 4
end

function Bot:leftPosition()
  return self:relativePosition(self:leftDirection())
end

function Bot:rightPosition()
  return self:relativePosition(self:rightDirection())
end

function Bot:cacheBlockFront()
  local v = self:forwardPosition()
  local node = self.aa:getNodeForward()
  self.aa:update(v, node)
end

function Bot:cacheBlockUp()
  local v = self:relativePosition(Direction.Up)
  local node = self.aa:getNodeUp()
  self.aa:update(v, node)
end

function Bot:cacheBlockDown()
  local v = self:relativePosition(Direction.Down)
  local node = self.aa:getNodeDown()
  self.aa:update(v, node)
end

function Bot:cacheBlocks()
  self.aa:update(self.pos, AANode:createEmpty())
  self:cacheBlockFront()
  self:cacheBlockUp()
  self:cacheBlockDown()
end

function Bot:query(dir, refresh)
  local v = self:relativePosition(dir)
  local node = refresh and AANode:createUnknown() or self.aa:query(v)

  if node.state == AANode.UNKNOWN then
    if dir == Direction.Up then
      self:cacheBlockUp()
    elseif dir == Direction.Down then
      self:cacheBlockDown()
    else
      local old_dir = self.dir
      self:face(dir)
      self:cacheBlockFront()
      self:face(old_dir)
    end

    node = self.aa:query(v)
  end

  return node
end

function Bot:queryForward(refresh)
  return self:query(self.dir, refresh)
end

function Bot:queryUp(refresh)
  return self:query(Direction.Up, refresh)
end

function Bot:queryDown(refresh)
  return self:query(Direction.Down, refresh)
end

function Bot:queryLeft(refresh)
  return self:query(self:leftDirection(), refresh)
end

function Bot:queryRight(refresh)
  return self:query(self:rightDirection(), refresh)
end

function Bot:cacheAround()
  for _ = 0, 3 do
    local ok, err = self:turnLeft()
    if not ok then
      return false, err
    end
  end

  return true
end

function Bot:cacheSides()
  local ok, err = self:turnLeft()
  if not ok then
    return false, err
  end

  ok, err = self:turnRight()
  if not ok then
    return false, err
  end

  ok, err = self:turnRight()
  if not ok then
    return false, err
  end

  ok, err = self:turnLeft()
  if not ok then
    return false, err
  end

  return true
end

function Bot:mineForward()
  if not turtle.detect() then
    return false, "nothing to mine"
  end

  local ok, err = turtle.dig()
  if not ok then
    Log.error("Unable to dig: " .. err)
    return false, err
  end

  self:cacheBlockFront()
  return true
end

function Bot:mineUp()
  if not turtle.detectUp() then
    return false, "nothing to mine"
  end

  local ok, err = turtle.digUp()
  if not ok then
    Log.error("Unable to dig up: " .. err)
    return false, err
  end

  self:cacheBlockUp()
  return true
end

function Bot:mineDown()
  if not turtle.detectDown() then
    return false, "nothing to mine"
  end

  local ok, err = turtle.digDown()
  if not ok then
    Log.error("Unable to dig down: " .. err)
    return false, err
  end

  self:cacheBlockDown()
  return true
end

function Bot:turnLeft()
  local ok, err = turtle.turnLeft()
  if not ok then
    Log.error("unable to turn left: " .. err)
    return false, err
  end

  self.dir = (self.dir + 1) % 4
  self:cacheBlocks()
  return true
end

function Bot:turnRight()
  local ok, err = turtle.turnRight()
  if not ok then
    Log.error("unable to turn right: " .. err)
    return false, err
  end

  self.dir = (self.dir + 3) % 4
  self:cacheBlocks()
  return true
end

function Bot:turn(side)
  if side == "left" then
    return self:turnLeft()
  elseif side == "right" then
    return self:turnRight()
  else
    Log.error(" ")
  end
end

function Bot:face(dir)
  if dir == self.dir then
    return true
  end

  if dir == Direction.Up or dir == Direction.Down then
    Log.error("Cannot face up or down (received " .. Direction.dirName(dir) .. ")")
    return false, "cannot face up or down"
  end

  if ((dir - self.dir + 4) % 4) == 1 then
    return self:turnLeft()
  end

  if ((self.dir - dir + 4) % 4) == 1 then
    return self:turnRight()
  end

  local ok, err = self:turnRight()
  if not ok then
    return false, err
  end

  ok, err = self:turnRight()
  if not ok then
    return false, err
  end

  return true
end

function Bot:up()
  local ok, err = turtle.up()
  if ok then
    self.pos = Direction.offsetDirection(self.pos, Direction.Up)
    self:cacheBlocks()
    return true
  end

  self:cacheBlockUp()
  return false, err
end

function Bot:down()
  local ok, err = turtle.down()
  if ok then
    self.pos = Direction.offsetDirection(self.pos, Direction.Down)
    self:cacheBlocks()
    return true
  end

  self:cacheBlockDown()
  return false, err
end

function Bot:forward()
  local ok, err = turtle.forward()
  if ok then
    self.pos = Direction.offsetDirection(self.pos, self.dir)
    self:cacheBlocks()
    return true
  end

  self:cacheBlockFront()
  return false, err
end

function Bot:backward()
  local ok, err = turtle.back()
  if ok then
    self.pos = Direction.offsetDirection(self.pos, self.dir, -1)
    self:cacheBlocks()
    return true
  end

  self:cacheBlockFront()
  return false, err
end

function Bot:pathFind(target, limit)
  local path = self.aa:buildPath(self.pos, target, limit)
  if path then
    for _, dir in ipairs(path) do
      if dir == Direction.Up then
        local ok, err = self:up()
        if not ok then
          return false, err
        end
      elseif dir == Direction.Down then
        local ok, err = self:down()
        if not ok then
          return false, err
        end
      else
        self:face(dir)
        local ok, err = self:forward()
        if not ok then
          return false, err
        end
      end
    end

    return true
  end

  return false, "unable to find path"
end

return Bot
