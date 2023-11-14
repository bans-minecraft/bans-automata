--    _____ _                             ____        _
--   / ____| |                           |  _ \      | |
--  | (___ | |_ ___  _ __ __ _  __ _  ___| |_) | ___ | |_
--   \___ \| __/ _ \| '__/ _` |/ _` |/ _ \  _ < / _ \| __|
--   ____) | || (_) | | | (_| | (_| |  __/ |_) | (_) | |_
--  |_____/ \__\___/|_|  \__,_|\__, |\___|____/ \___/ \__|
--                              __/ |
--                             |___/
-- sstorage-bot.lua
-- Copyright (C) 2023, Blake Rain.
-- Licensed under BSD3 License. See LICENSE for details.
--
-- A simple storage bot that works with the Storage Drawers mod.
--
-- This was created after I found that the Starbuncles (from Ars Nouveau mod) were not really able
-- to deal with my storage situation.
--
-- [2023-11-12] Initial version
-- [2023-11-14] Optimize (and simplify) initial area scanning
-- [2023-11-14] Improve scanning of area by not turning to storage drawers

package.path = "/?.lua;/?/init.lua;" .. package.path
local AANode = require("lib.bot.aa.node")
local AAUtils = require("lib.bot.aa.utils")
local AABB = require("lib.aabb")
local Bot = require("lib.bot")
local Log = require("lib.log")
local Direction = require("lib.direction")
local Utils = require("lib.utils")
local Vector = require("lib.vector")

Log.setLogFile("storage-bot.log", true)

-----------------------------------------------------------------------------------------------

local Drawer = {}
Drawer.__index = Drawer
Drawer.__name = "Drawer"

function Drawer:create(index, pos, dir, side)
  Log.assertIs(index, "number")
  Log.assertClass(pos, Vector)
  Direction.assertDir(dir)

  local drawer = {}
  setmetatable(drawer, Drawer)

  drawer.index = index
  drawer.pos = pos
  drawer.dir = dir

  local p = peripheral.wrap(side)
  if not p then
    Log.error(("Unable to wrap peripheral on side %s of bot"):format(side))
    return false, "Unable to wrap peripheral on " .. side
  end

  drawer.size = p.size()
  drawer.slots = {}
  for slot, item in pairs(p.list()) do
    drawer.slots[slot] = item.name
  end

  return drawer
end

function Drawer:deserialize(data)
  Log.assertIs(data, "table")
  Log.assertIs(data.index, "number")
  Log.assertIs(data.dir, "number")
  Log.assertIs(data.size, "number")
  Log.assertIs(data.slots, "table")

  local drawer = {}
  setmetatable(drawer, Drawer)

  drawer.index = data.index
  drawer.pos = Vector:deserialize(data.pos)
  drawer.dir = data.dir
  drawer.size = data.size
  drawer.slots = data.slots

  return drawer
end

function Drawer:serialize()
  return {
    index = self.index,
    pos = self.pos:serialize(),
    dir = self.dir,
    size = self.size,
    slots = self.slots,
  }
end

function Drawer:__tostring()
  return ("%s"):format(self.pos)
end

function Drawer:getBotCoord()
  -- Get the opposite direction that the bot faces for this drawer, then move in that direction
  -- by one block. This gives us the location the bot should pathfind to for the drawer.
  return Direction.offsetDirection(self.pos, Direction.opposite(self.dir), 1)
end

function Drawer:inspect()
  local drawer = peripheral.wrap("front")
  if not drawer then
    Log.error("Unable to wrap peripheral infront of bot")
    return false, "Unable to wrap peripheral"
  end

  self.size = drawer.size()
  self.slots = {}
  for slot, item in pairs(drawer.list()) do
    self.slots[slot] = item
  end

  return true
end

-----------------------------------------------------------------------------------------------

local function createArea()
  local area = AABB:create()
  area:addPoint(-4, 1, -19)
  area:addPoint(11, 3, -1)
  return area
end

-----------------------------------------------------------------------------------------------

local StoreBot = {}
StoreBot.__index = StoreBot
StoreBot.__name = "StoreBot"

StoreBot.MIN_FUEL = 2000

function StoreBot:create()
  local bot = {}
  setmetatable(bot, StoreBot)

  bot.area = createArea()
  bot.bot = Bot:create(Direction.North)
  bot.home = bot.bot.pos:clone()
  bot.drawers = {}
  bot.items = {}

  return bot
end

-----------------------------------------------------------------------------------------------

function StoreBot:save()
  local drawers = {}
  for _, drawer in ipairs(self.drawers) do
    table.insert(drawers, drawer:serialize())
  end

  local file = fs.open(".storage-bot.data", "w")

  file.write(textutils.serialize({
    bot = self.bot:serialize(),
    home = self.home:serialize(),
    drawers = drawers,
  }))

  file.close()
end

function StoreBot:load()
  local file = fs.open(".storage-bot.data", "r")
  local text = file.readAll()
  local data = textutils.unserialize(text)
  file.close()

  if not data then
    Log.error("Failed to read storage bot data")
    return nil, "Failed to read storage bot data"
  end

  Log.assertIs(data, "table")

  local bot = {}
  setmetatable(bot, StoreBot)

  bot.area = createArea()
  bot.bot = Bot:deserialize(data.bot)
  bot.home = Vector:deserialize(data.home)
  bot.drawers = {}
  bot.items = {}

  local ndrawers = 0
  local nitems = 0

  for index, drawer_spec in ipairs(data.drawers) do
    local drawer = Drawer:deserialize(drawer_spec)
    for _, item in pairs(drawer.slots) do
      if item then
        bot.items[item] = index
        nitems = nitems + 1
      end
    end

    table.insert(bot.drawers, drawer)
    ndrawers = ndrawers + 1
  end

  Log.info(("Loaded %d drawers with %d items"):format(ndrawers, nitems))
  return bot
end

-----------------------------------------------------------------------------------------------

function StoreBot:forgetLocationsForDrawer(drawer)
  Log.assertClass(drawer, Drawer)
  for _, item in pairs(drawer.slots) do
    self.items[item] = nil
  end
end

function StoreBot:addLocationsForDrawer(drawer)
  Log.assertClass(drawer, Drawer)
  for _, item in pairs(drawer.slots) do
    if item then
      self.items[item] = drawer.index
    end
  end
end

-----------------------------------------------------------------------------------------------

function StoreBot:receiveFuel()
  -- Check to see if we need fuel
  local level = turtle.getFuelLevel()
  if level == "unlimited" then
    Log.info("Bot is a creative bot that has unlimited fuel")
    return true
  end

  -- See what is in front of us using the AA
  local infront = self.bot:queryForward()
  if infront.state ~= AANode.FULL then
    Log.error("Unable to find block for fuel inventory infront of bot")
    return false, "No fuel inventory"
  end

  -- Make sure that what is in front of us is something that has an inventory
  if not Utils.stringStartsWith(infront.info.name, "storagedrawers:") then
    Log.error("Unknown field inventory infront of block:", infront.info.name)
    return false, "Unknown fuel inventory"
  end

  -- Select the bot's fuel slot and then receive up to a stack of fuel from the inventory.
  turtle.select(self.bot.fuelSlot)
  turtle.suck()

  -- Examine what we received in our fuel slot
  local info = turtle.getItemDetail(self.bot.fuelSlot)
  if info == nil then
    Log.error("No items found in fuel slot after refueling")
    turtle.select(1)
    return false, "No fuel received"
  end

  -- Use the fuel to refuel the bot
  local ok, err = turtle.refuel()
  if not ok then
    Log.error("Failed to refuel bot:", err)
    turtle.select(1)
    return false, "Unable to refuel bot"
  end

  local new_level = turtle.getFuelLevel()
  Log.info(("Refuelled bot by %d (current level: %d)"):format(new_level - level, new_level))
  return true
end

function StoreBot:refuelIfNeeded()
  local fuel_level = turtle.getFuelLevel()
  if fuel_level == "unlimited" then
    Log.info("Bot is a creative bot that has unlimited fuel")
    return true
  end

  if fuel_level < StoreBot.MIN_FUEL then
    Log.info("Bot fuel level is low, attempting to refuel")
    return self:receiveFuel()
  else
    Log.info(("Bot fuel level %d is above minimum %d"):format(fuel_level, StoreBot.MIN_FUEL))
  end

  return true
end

-----------------------------------------------------------------------------------------------

function StoreBot:targetBlockInRange(block)
  return self.area:contains(block.x, block.y, block.z)
end

function StoreBot:scanSurrounding()
  local result = {}

  local queries = {
    { self.bot:queryForward(false), self.bot.dir },
    { self.bot:queryLeft(false), self.bot:leftDirection() },
    { self.bot:queryRight(false), self.bot:rightDirection() },
    { self.bot:queryUp(), Direction.Up },
    { self.bot:queryDown(), Direction.Down },
  }

  for _, query in ipairs(queries) do
    local node, direction = table.unpack(query)
    if node.state == AANode.EMPTY then
      local target = Direction.offsetDirection(self.bot.pos, direction, 1)
      if self:targetBlockInRange(target) then
        table.insert(result, target)
      end
    end
  end

  return result
end

local function isStorageDrawer(item)
  return Utils.stringStartsWith(item.name, "storagedrawers:")
end

function StoreBot:scan()
  local ok, err

  -- Make sure that we have enough fuel
  ok, err = self:refuelIfNeeded()
  if not ok then
    return false, "Failed to refuel bot"
  end

  -- Move up from our starting position
  ok, err = self.bot:up(2)
  if not ok then
    return false, "Failed to move up"
  end

  -- We maintain a stack of empty locations to visit. These are the locations in our AA in
  -- which we've found air (or whatever) into which the bot can move. Each entry in the
  -- stack is the location of the block.
  local stack = {}
  local visited = {}
  local found = {}

  -- Push the initial scan onto the stack
  Utils.concat(stack, self:scanSurrounding())

  while #stack > 0 do
    -- Get the target block from the top of the stack.
    local target = table.remove(stack, #stack)

    -- Move the bot into the target block
    ok, err = self.bot:pathFind(target, 200)
    if not ok then
      Log.error(("Failed to pathfind to block at %s: %s"):format(target, err))
      return false, err
    end

    -- Record this block in the "visited" set
    visited[AAUtils.positionKey(target)] = true

    for _, direction in ipairs({ Direction.East, Direction.West }) do
      -- See if there is a node there that looks like a storage drawer
      local node = self.bot:query(direction)
      if node.state == AANode.FULL and isStorageDrawer(node.info) then
        local drawer_pos = self.bot:relativePosition(direction)
        local drawer_key = AAUtils.positionKey(drawer_pos)

        -- See if we have already seen this drawer
        if found[drawer_key] == nil then
          -- Create the new drawer and add it to the set of drawers
          local side = Direction.directionSide(self.bot.dir, direction)
          local drawer = Drawer:create(#self.drawers + 1, drawer_pos, direction, side)
          table.insert(self.drawers, drawer)

          -- Record that we have seen this drawer
          found[drawer_key] = true

          -- Report that we found a drawer
          Log.info(("Discovered drawer at %s with %i slots:"):format(drawer.pos, #drawer.slots))
          for index, item in pairs(drawer.slots) do
            if item then
              Log.info(("    slot[%d] = %s"):format(index, item))
            end
          end
        end
      end
    end

    -- Perform a new scan of the blocks around us to find empty blocks
    local scan = self:scanSurrounding()

    -- Add the new scanned blocks if they're not present in the visited set
    for _, block in ipairs(scan) do
      if visited[AAUtils.positionKey(block)] == nil then
        table.insert(stack, block)
      end
    end
  end

  -- Return to the home location
  ok, err = self.bot:pathFind(self.home, 200)
  if not ok then
    Log.error("Failed to path find back to start:", err)
    return false, "Failed to return to start"
  end

  ok, err = self.bot:face(Direction.North)
  if not ok then
    Log.error("Failed to face north:", err)
    return false, "Failed to face north"
  end

  self:save()
  return true
end

-----------------------------------------------------------------------------------------------

function StoreBot:fetchInput()
  local ok, err = self.bot:face(Direction.West)
  if not ok then
    Log.error("Unable to turn to input chest:", err)
    return nil, "Unable to turn to input chest"
  end

  local chest = peripheral.wrap("front")
  if not chest then
    Log.error("Failed to wrap peripheral for input chest")
    return nil, "Failed to wrap peripheral for input chest"
  end

  local size = chest.size()
  Log.info(("Input chest has %d slots"):format(size))

  local received = 0
  local slot = 1

  while true do
    turtle.select(slot)
    ok, err = turtle.suck(64)
    if not ok then
      break
    end

    local info = turtle.getItemDetail()
    Log.info(("Bot received %dx %s"):format(info.count, info.name))
    received = received + info.count

    slot = slot + 1
    if slot > 16 then
      Log.info("Turtle is full of items (input may have more)")
      break
    end
  end

  Log.info(("Bot has received %d items from input"):format(received))

  ok, err = self.bot:face(Direction.North)
  if not ok then
    Log.error("Unable to turn back to home direction:", err)
    return nil, "Unable to turn back to home direction"
  end

  return received
end

function StoreBot:loop()
  local count, ok, err

  -- Make sure that we have enough fuel
  ok, err = self:refuelIfNeeded()
  if not ok then
    Log.error("Encountered error refueling:", err)
    return false, "Failed to refuel bot"
  end

  -- Turn to our input chest and see what's going on
  count, err = self:fetchInput()
  if count == nil then
    Log.error("Failed to fetch input:", err)
    return false, "Failed to fetch input"
  end

  -- If we didn't receive anything, wait for a bit and then try again
  if count == 0 then
    sleep(60)
    return true
  end

  -- Go through all our inventory and place the items
  for slot = 1, 16 do
    local info = turtle.getItemDetail(slot)
    if info then
      local loc = self.items[info.name]
      if type(loc) == "number" then
        local drawer = self.drawers[loc]
        Log.info(("Storing %dx %s in drawer %s"):format(info.count, info.name, drawer.pos))

        -- Move the bot over to the block infront of the drawer
        ok, err = self.bot:pathFind(drawer:getBotCoord())
        if not ok then
          Log.error("Failed to pathfind to storage drawer:", err)
          return false, "Failed to pathfind to storage drawer"
        end

        -- Turn the bot to face the drawer so we can interact with it
        ok, err = self.bot:face(drawer.dir)
        if not ok then
          Log.error("Failed to face storage drawer:", err)
          return false, "Failed to face storage drawer"
        end

        -- Drop the items in this slot into the drawer
        turtle.select(slot)
        turtle.drop()
      else
        Log.info(("Unable to store %dx %s (unknown item)"):format(info.count, info.name))
      end
    end
  end

  -- Return to the home location
  ok, err = self.bot:pathFind(self.home, 200)
  if not ok then
    Log.error("Failed to path find back to start:", err)
    return false, "Failed to return to start"
  end

  ok, err = self.bot:face(Direction.North)
  if not ok then
    Log.error("Failed to face north:", err)
    return false, "Failed to face north"
  end

  return true
end

function StoreBot:run()
  while true do
    local ok, err = self:loop()
    if not ok then
      Log.error("Main bot loop failed:", err)
      return false, "Main bot loop failed"
    end
  end
end

local function main(...)
  local args = { ... }
  local ok, err

  if #args == 0 then
    local bot = StoreBot:load()
    ok, err = bot:run()
  elseif #args == 1 then
    if args[1] == "run" then
      local bot = StoreBot:load()
      ok, err = bot:run()
    elseif args[1] == "scan" then
      local bot = StoreBot:create()
      ok, err = bot:scan()
    else
      error("Unknown command: " .. args[1])
    end
  else
    error("Usage: storage-bot.lua [run | scan]")
  end

  if not ok then
    error("Bot failed to complete task: " .. err)
  end
end

Log.trap(main, ...)
