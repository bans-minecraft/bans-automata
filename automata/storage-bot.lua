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
-- The bot is configured with a storage area: a bounding-box in which there should be one or more
-- storage drawers. A constraint is placed on these storage drawers that they should be accessible
-- from either the east or west sides.
--
-- The bot resides next to both its input and fuel inventories. The input inventory is placed on
-- the left of the bot, and the fuel inventory is placed infront. Every minute, the bot checks the
-- input inventory for items and, if there are any, extracts as much as it can carry. The bot will
-- then visit the corresponding storage drawer for each item, placing the items into storage. Once
-- completed, the bot will return to its resting location and check the input inventory. If there
-- are more items the process of placing the items into storage will begin again; otherwise the
-- bot will go back to sleep for another minute.
--
-- In order to build a map of all the stoarge drawers in the region, the bot can be run with the
-- "scan" argument. This will cause the bot to walk through the entire area, noting down the
-- location and contents of any storage drawers it finds. Note that this process can take a very
-- long time for larger areas, as the bot needs to be thorough.
--
-- Whilst the bot is looking around for storage drawers, it is also building a mantal map of the
-- area, which is stored in the AA graph. This is then used along with the A* algorithm to allow
-- the bot to pathfind to each storage drawer.
--
-- The bot can also be run with the "update" argument. This will cause the bot to revisit all the
-- storage drawers it knows about and update its knowledge of their contents. This is useful if
-- you rearrange the contents of the storage drawers, but do not change their spacial
-- configuration such that a new "scan" needs to be run. It is much more efficient to just visit
-- all the known storage drawers and check their contents.
--
-- The bot creates to files:
--
-- - storage-bot.log which contains all the log output from the bot. Any errors and so on will
--   be recorded here.
-- - .storage-bot.data contains a Lua-serialized dump of the bot's AA and other internals that
--   were constructed during the "scan" process. This file, which can get quite large, contains
--   all the bots memories.
--
-- [2023-11-12] Initial version
-- [2023-11-14] Optimize (and simplify) initial area scanning
-- [2023-11-14] Improve scanning of area by not turning to storage drawers
-- [2023-11-15] Added the "update" command
-- [2024-01-20] Now uses Utamacraft area awareness block to scan for drawers on 'update'

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
  drawer.size = 0
  drawer.slots = {}

  local ok, err = drawer:update(side)
  if not ok then
    return nil, err
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

function Drawer:update(side)
  local drawer = peripheral.wrap(side)
  if not drawer then
    Log.error(("Unable to wrap peripheral on %s side of bot"):format(side))
    return false, "Unable to wrap peripheral on " .. side
  end

  self.size = drawer.size()
  self.slots = {}
  for slot, item in pairs(drawer.list()) do
    self.slots[slot] = item.name
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
  bot.digitized = {}

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
  bot.digitized = {}

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

function StoreBot:addLocationsForDrawer(drawer)
  Log.assertClass(drawer, Drawer)
  local nitems = 0
  for _, item in pairs(drawer.slots) do
    if item then
      self.items[item] = drawer.index
      nitems = nitems + 1
    end
  end

  return nitems
end

function StoreBot:selectNextFreeSlot(start)
  local slot = start or 1
  while slot <= 16 do
    local info = turtle.getItemDetail(slot)
    if info == nil then
      turtle.select(slot)
      return slot
    end

    slot = slot + 1
  end

  return 0
end

function StoreBot:remainingFreeSlots()
  local remaining = 0
  for slot = 1, 16 do
    local info = turtle.getItemDetail(slot)
    if not info then
      remaining = remaining + 1
    end
  end

  return remaining
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
    -- else
    --   Log.info(("Bot fuel level %d is above minimum %d"):format(fuel_level, StoreBot.MIN_FUEL))
  end

  return true
end

-----------------------------------------------------------------------------------------------

function StoreBot:update()
  -- Move to the awareness block, situated in the midst of our storage
  self.bot:move(Direction.DirSeq:create():up(3):north(8):east(5):north(2):up(1):west(0))

  -- Perform a scan using the awareness block. This will return to us a load of blocks.
  local scanner = peripheral.wrap("front")
  local scan, err = scanner.scan(8, "down")
  if not scan then
    Log.error(("Failed to perform scan: %s"):format(err))
    return false, err
  end

  Log.info(("Scan returned %d blocks and cost %d energy"):format(#scan.blocks, scan.energy.cost))

  -- Build a dictionary of our drawers, indexed by their coordinates
  local drawers = {}
  for _, drawer in ipairs(self.drawers) do
    drawers[tostring(drawer.pos)] = drawer
  end

  local function relative(block)
    block.x = block.x + 4
    block.y = block.y + 4
    block.z = block.z - 10
  end

  local updated = 0
  for _, block in ipairs(scan.blocks) do
    if block.name:match("storagedrawers:.*") then
      -- Make the block's coordinates relative to our home position, as per the AA
      relative(block)

      -- Get the drawer at this coordinate
      local pos = Vector:create(block.x, block.y, block.z)
      local drawer = drawers[tostring(pos)]
      if drawer then
        drawer.size = block.inventory.size
        drawer.slots = {}

        for slot = 2, block.inventory.size do
          local info = block.inventory.slots[slot]
          if info.name ~= "minecraft:air" and info.count > 0 then
            drawer.slots[slot] = info.name
          end
        end

        updated = updated + 1
      else
        Log.error(("Failed to find drawer at %d:%d:%d"):format(block.x, block.y, block.z))
      end
    end
  end

  Log.info(("Updated %d drawers"):format(updated))

  -- Move back to our home location
  self.bot:move(Direction.DirSeq:create():down(1):south(2):west(5):south(8):down(3):north(0))

  self:save()
  return true
end

-----------------------------------------------------------------------------------------------

function StoreBot:getMaterializedItems(uuids)
  -- Wrap the peripheral of the digitizer
  local digitizer = peripheral.wrap("front")
  if not digitizer then
    return false, "Failed to wrap digitizer peripheral"
  end

  local slot = 1
  while #uuids > 0 and slot <= 16 do
    local uuid = uuids[1]

    -- Find the next free inventory slot in the turtle.
    slot = self:selectNextFreeSlot(slot)
    if slot == 0 then
      break
    end

    -- Simulate the materialization of the item stack associated with this UUID.
    local sim, err = digitizer.materialize(uuid, nil, true)
    if not sim then
      Log.error(("Failed to simulate materialization of '%s': %s"):format(uuid, err))
      return nil, "Failed to simulate item stack materialization"
    end

    -- Make sure that the digitizer has enough energy to perform the materialization
    local delayed = 0
    while delayed < 10 do
      if digitizer.getEnergy() > sim.cost then
        break
      end

      sleep(0.5)
      delayed = delayed + 1
    end

    -- Make sure that the digitizer reached our required energy level
    if delayed >= 10 and digitizer.getEnergy() < sim.cost then
      Log.error(("Digitizer never reached required energy %d FE"):format(sim.cost))
      return nil, "Digitizer never reached required energy to materialize item stack"
    end

    -- Perform the actual materialization
    local result
    result, err = digitizer.materialize(uuid)
    if not result then
      Log.error(("Failed to materialize '%s': %s"):format(uuid, err))
      return nil, "Failed to materialize item stack"
    end

    Log.info(("Materialized %dx %s"):format(result.materialized, result.item.name))

    -- Try and take the items from the digitizer
    result, err = turtle.suck(result.materialized)
    if not result then
      Log.error("")
    end

    -- Pop the UUID from the list of UUIDs
    table.remove(uuids, 1)
  end

  return true
end

function StoreBot:handleMaterialized(uuids)
  -- Move the bot to the digitizer block
  self.bot:move(Direction.DirSeq:create():up(1):east(1))

  -- Record this location as the location of the digitizer
  local digitizerLoc = self.bot.pos:clone()

  local ok, err
  while #uuids > 0 do
    -- Try and get an inventory full of items from the digitizer.
    ok, err = self:getMaterializedItems(uuids)
    if not ok then
      -- We couldn't retrieve anything
      Log.error(("Failed to retrieve %d digitized items: %s"):format(#uuids, err))
      for _, uuid in ipairs(uuids) do
        Log.info(("Remaining UUID: %s"):format(uuid))
      end

      return false, "Failed to materialize items"
    end

    -- Go through all our inventory and place the items
    self:putAway()

    -- Path find back to the digitizer if we have any more UUIDs
    if #uuids > 0 then
      ok, err = self.bot:pathFind(digitizerLoc, 200)
      if not ok then
        Log.error("Failed to path find back to digitizer:", err)
        return false, "Failed to return to digitizer"
      end

      ok, err = self.bot:face(Direction.East)
      if not ok then
        Log.error("Failed to face east:", err)
        return false, "Failed to face east"
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

-----------------------------------------------------------------------------------------------

function StoreBot:targetBlockInRange(block)
  return self.area:contains(block.x, block.y, block.z)
end

function StoreBot:scanSurrounding()
  local result = {}

  local queries = {
    { self.bot:queryForward(false), self.bot.dir },
    { self.bot:queryLeft(false),    self.bot:leftDirection() },
    { self.bot:queryRight(false),   self.bot:rightDirection() },
    { self.bot:queryUp(),           Direction.Up },
    { self.bot:queryDown(),         Direction.Down },
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

          -- Add the items from the drawer into our memory
          self:addLocationsForDrawer(drawer)

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

  -- local size = chest.size()
  -- Log.info(("Input chest has %d slots"):format(size))

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

  if received > 0 then
    Log.info(("Bot has received %d items from input"):format(received))
  end

  ok, err = self.bot:face(Direction.North)
  if not ok then
    Log.error("Unable to turn back to home direction:", err)
    return nil, "Unable to turn back to home direction"
  end

  return received
end

function StoreBot:putAway()
  for slot = 1, 16 do
    local info = turtle.getItemDetail(slot)
    if info then
      local loc = self.items[info.name]
      if type(loc) == "number" then
        local drawer = self.drawers[loc]
        Log.info(("Storing %dx %s in drawer %s"):format(info.count, info.name, drawer.pos))

        -- Move the bot over to the block infront of the drawer
        local ok, err = self.bot:pathFind(drawer:getBotCoord())
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
end

function StoreBot:handleInput()
  local count, ok, err

  -- Turn to our input chest and see what's going on
  count, err = self:fetchInput()
  if count == nil then
    Log.error("Failed to fetch input:", err)
    return -1, "Failed to fetch input"
  end

  -- If we didn't receive anything, wait for a bit and then try again
  if count == 0 then
    return 0
  end

  -- Go through all our inventory and place the items
  self:putAway()

  -- Return to the home location
  ok, err = self.bot:pathFind(self.home, 200)
  if not ok then
    Log.error("Failed to path find back to start:", err)
    return -1, "Failed to return to start"
  end

  ok, err = self.bot:face(Direction.North)
  if not ok then
    Log.error("Failed to face north:", err)
    return -1, "Failed to face north"
  end

  return count
end

function StoreBot:receiveRednet()
  while true do
    local sender, message = rednet.receive("bannet:storagebot.digitizer")
    if sender and message then
      Log.info(("Received %d digitized items"):format(#message))
      Utils.concat(self.digitized, message)
    end
  end
end

function StoreBot:loop()
  local ok, err
  while true do
    -- Make sure that we have enough fuel
    ok, err = self:refuelIfNeeded()
    if not ok then
      Log.error("Encountered error refueling:", err)
      return false, "Failed to refuel bot"
    end

    -- See if we have any rednet items to process
    if #self.digitized > 0 then
      -- Take the digitized items from the bot
      local digitized = self.digitized
      self.digitized = {}

      -- Rematerialize and then file the items
      ok, err = self:handleMaterialized(digitized)
      if not ok then
        Log.error(("Failed to handle digitized items: %s"):format(err))
        return false
      end

      -- If we have any remaining UUIDs, put them back into the bot
      Utils.concat(self.digitized, digitized)
    end

    -- See if we have anything to handle in our input
    ok, err = self:handleInput()
    if ok == -1 then
      Log.error(("Failed to handle input: %s"):format(err))
      return false
    end

    -- Wait for a bit if we didn't process anything
    if ok == 0 then
      sleep(10)
    end
  end
end

function StoreBot:run()
  rednet.open("right")

  local function receive()
    self:receiveRednet()
  end

  local function loop()
    self:loop()
  end

  parallel.waitForAny(receive, loop)
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
    elseif args[1] == "update" then
      local bot = StoreBot:load()
      ok, err = bot:update()
    else
      error("Unknown command: " .. args[1])
    end
  else
    error("Usage: storage-bot.lua [run | scan]")
  end

  if not ok then
    error("Bot failed to complete task: " .. (err or "<no error>"))
  end
end

Log.trap(main, ...)
