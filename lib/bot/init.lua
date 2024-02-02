local AA = require("lib.bot.aa")
local AANode = require("lib.bot.aa.node")
local Assert = require("lib.assert")
local Direction = require("lib.direction")
local Log = require("lib.log")
local Utils = require("lib.utils")
local Vector = require("lib.vector")
local class = require("lib.class")

-- The Bot class
--
-- This class provides the functionality for diving the bot, performing mining actions, and
-- maintaining the AA.
--
-- The `Bot` class extneds the `Actor` class to allow events, state and actions
local Bot = class("Bot")

function Bot:init(dir)
  -- We keep track of the slot into which we should pace fuel, and the minimum amount of fuel that
  -- we need to operate.
  self.fuelSlot = 16
  self.minFuel = 1000

  -- The current position and direction of the bot. The position is typically relative to the start
  -- of the bot's process (often referred to as the "home" position). The direction should be the
  -- global (world) direction, as seen in the F3 debug overlay. if no direction is given in the
  -- `dir` argument to this constructor, we default to North.
  self.pos = Vector:new()
  self.start = Vector:new()
  self.dir = dir or Direction.North

  -- Create the Area Awareness system
  self.aa = AA:new()

  -- When the bot is created, perform a scan around our immediate environment to initialize the AA.
  self:cacheAround()
end

function Bot.static.deserialize(data)
  Assert.assertIs(data, "table")
  Assert.assertIs(data.fuelSlot, "number")
  Assert.assertIs(data.minFuel, "number")
  Assert.assertIs(data.dir, "number")

  local bot = Bot:new(data.dir)
  bot.fuelSlot = data.fuelSlot
  bot.minFuel = data.minFuel
  bot.pos = Vector.deserialize(data.pos)
  bot.start = Vector.deserialize(data.start)
  bot.aa = AA.deserialize(data.aa)

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
  self.aa:update(self.pos, AANode.createEmpty())
  self:cacheBlockFront()
  self:cacheBlockUp()
  self:cacheBlockDown()
end

function Bot:query(dir, refresh)
  local v = self:relativePosition(dir)
  local node = refresh and AANode.createUnknown() or self.aa:query(v)

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

function Bot:up(count)
  count = Utils.numberOrDefault(count, 1)

  local move = 0
  while move < count do
    local ok, err = turtle.up()
    if not ok then
      self:cacheBlockUp()
      return false, err, move, count
    end

    self.pos = Direction.offsetDirection(self.pos, Direction.Up)
    self:cacheBlocks()
    move = move + 1
  end

  return true
end

function Bot:down(count)
  count = Utils.numberOrDefault(count, 1)

  local move = 0
  while move < count do
    local ok, err = turtle.down()
    if not ok then
      self:cacheBlockDown()
      return false, err, move, count
    end

    self.pos = Direction.offsetDirection(self.pos, Direction.Down)
    self:cacheBlocks()
    move = move + 1
  end

  return true
end

function Bot:forward(count)
  count = Utils.numberOrDefault(count, 1)

  local move = 0
  while move < count do
    local ok, err = turtle.forward()
    if not ok then
      self:cacheBlockFront()
      return false, err, move, count
    end

    self.pos = Direction.offsetDirection(self.pos, self.dir)
    self:cacheBlocks()
    move = move + 1
  end

  return true
end

function Bot:backward(count)
  count = Utils.numberOrDefault(count, 1)

  local move = 0
  while move < count do
    local ok, err = turtle.back()
    if not ok then
      self:cacheBlockFront()
      return false, err, move, count
    end

    self.pos = Direction.offsetDirection(self.pos, self.dir, -1)
    self:cacheBlocks()
    move = move + 1
  end

  return true
end

function Bot:move(steps)
  local ok, err, move, count

  Assert.assertIs(steps, "table")
  if Direction.DirSeq:isInstance(steps) then
    steps = steps:finish()
  end

  for index, step in ipairs(steps) do
    if step.direction == Direction.Up then
      ok, err, move, count = self:up(step.count)
      if not ok then
        return false, ("Unable to move up in step %d (moved %d of %d): %s"):format(index, move, count, err)
      end
    elseif step.direction == Direction.Down then
      ok, err, move, count = self:down(step.count)
      if not ok then
        return false, ("Unable to move down in step %d (moved %d of %d): %s"):format(index, move, count, err)
      end
    else
      ok, err = self:face(step.direction)
      if not ok then
        return false,
            ("Unable to turn to face direction %s in step %d: %s"):format(Direction.dirName(step.direction), index, err)
      end

      if step.count > 0 then
        ok, err, move, count = self:forward(step.count)
        if not ok then
          return false, ("Unable to move forward in step %d (moved %d of %d): %s"):format(index, move, count, err)
        end
      end
    end
  end

  return true
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

function Bot:groupInventory()
  for target = 1, 16 do
    local target_info = turtle.getItemDetail(target)
    if target_info then
      local target_remaining = turtle.getItemSpace(target)

      for source = 1, 16 do
        if source ~= target then
          local source_info = turtle.getItemDetail(source)
          if source_info and source_info.name == target_info.name then
            local transfer = math.min(target_remaining, source_info.count)
            if transfer > 0 then
              turtle.select(source)
              turtle.transferTo(target, transfer)
              target_remaining = target_remaining - transfer
            end
          end
        end

        if target_remaining <= 0 then
          break
        end
      end
    end
  end
end

function Bot:sortInventory()
  for target = 1, 16 do
    local target_info = turtle.getItemDetail(target)
    if not target_info then
      for source = target + 1, 16 do
        if turtle.getItemDetail(source) then
          turtle.select(source)
          turtle.transferTo(target)
          break
        end
      end
    end
  end
end

return Bot
