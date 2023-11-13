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

package.path = "/?.lua;/?/init.lua;" .. package.path
local AANode = require("lib.bot.aa.node")
local Bot = require("lib.bot")
local Log = require("lib.log")
local Direction = require("lib.direction")
local Utils = require("lib.utils")
local Vector3 = require("lib.vector")

Log.setLogFile("storage-log.txt")

local STORAGE_SET_WIDTH = 4
local STORAGE_SET_HEIGHT = 3
local STORAGE_SETS_ROWS = 3 -- In the North-South direction
local STORAGE_SETS_COLS = 3 -- In the East-West direction

-----------------------------------------------------------------------------------------------

local Coord = {}
Coord.__index = Coord
Coord.__name = "Coord"

function Coord:create(row, col)
  Log.assertIs(row, "number")
  Log.assertIs(col, "number")
  local coord = { row = row, col = col }
  setmetatable(coord, Coord)
  return coord
end

function Coord:clone()
  return Coord:create(self.row, self.col)
end

function Coord:toIndex(stride)
  Log.assertIs(stride, "number")
  return self.col + (self.row - 1) * stride
end

function Coord:__tostring()
  return ("%d:%d"):format(self.row, self.col)
end

-----------------------------------------------------------------------------------------------

local Drawer = {}
Drawer.__index = Drawer
Drawer.__name = "Drawer"

function Drawer:create(set, side, coord)
  Log.assertClass(set, Coord)
  Log.assertIs(side, "string")
  Log.assertClass(coord, Coord)

  local drawer = {}
  setmetatable(drawer, Drawer)

  drawer.set = set
  drawer.side = side
  drawer.coord = coord
  drawer.pos = Vector3:create()
  drawer.dir = 0
  drawer.size = 0
  drawer.slots = {}

  return drawer
end

function Drawer:__tostring()
  return ("%s/%s/%s"):format(self.set, self.side, self.coord)
end

function Drawer:inspect(side)
  if side == nil then
    side = "front"
  end

  Log.assertIs(side, "string")
  local drawer = peripheral.wrap(side)
  if not drawer then
    Log.error("Unable to wrap peripheral on side:", side)
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

local DrawerSet = {}
DrawerSet.__index = DrawerSet
DrawerSet.__name = "DrawerSet"

function DrawerSet:create(coord)
  Log.assertClass(coord, Coord)

  local set = {}
  setmetatable(set, DrawerSet)

  set.coord = coord
  set.drawers = {
    east = {},
    west = {},
  }

  for row = 1, STORAGE_SET_HEIGHT do
    set.drawers.east[row] = {}
    set.drawers.west[row] = {}

    for col = 1, STORAGE_SET_WIDTH do
      set.drawers.east[row][col] = Drawer:create(set.coord:clone(), "east", Coord:create(row, col))
      set.drawers.west[row][col] = Drawer:create(set.coord:clone(), "west", Coord:create(row, col))
    end
  end

  return set
end

-----------------------------------------------------------------------------------------------

local StoreBot = {}
StoreBot.__index = StoreBot
StoreBot.__name = "StoreBot"

function StoreBot:create()
  local bot = {}
  setmetatable(bot, StoreBot)

  bot.bot = Bot:create(Direction.North)
  bot.drawerSets = {}
  bot.itemLocations = {}
  bot.home = bot.bot.pos:clone()

  for row = 1, STORAGE_SETS_ROWS do
    for col = 1, STORAGE_SETS_COLS do
      table.insert(bot.drawerSets, DrawerSet:create(Coord:create(row, col)))
    end
  end

  return bot
end

function StoreBot:save()
  local file = fs.open("storage-bot.data", "w")
  file.write(textutils.serialize({
    home = self.home,
    bot = {
      pos = self.bot.pos,
      dir = self.bot.dir,
    },
    drawerSets = self.drawerSets,
  }))
  file.close()
end

function StoreBot:getDrawerSet(coord)
  Log.assertClass(coord, Coord)
  Log.assert(coord.row >= 1 and coord.row <= STORAGE_SETS_ROWS, "row out of range")
  Log.assert(coord.col >= 1 and coord.col <= STORAGE_SETS_COLS, "column out of range")
  return self.drawerSets[coord:toIndex(STORAGE_SETS_COLS)]
end

function StoreBot:forgetLocationsForDrawer(drawer)
  Log.assertClass(drawer, Drawer)
  for _, item in pairs(drawer.slots) do
    self.itemLocations[item.name] = nil
  end
end

function StoreBot:addLocationsForDrawer(drawer)
  Log.assertClass(drawer, Drawer)
  local count = 0
  for slot, item in pairs(drawer.slots) do
    if item then
      self.itemLocations[item.name] = {
        set = drawer.set:clone(),
        side = drawer.side,
        coord = drawer.coord:clone(),
        slot = slot,
      }

      count = count + 1
    end
  end

  Log.info(("Stored %d item locations for drawer %s"):format(count, drawer))
end

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

  if fuel_level < Bot.MIN_FUEL then
    Log.info("Bot fuel level is low, attempting to refuel")
    return self:receiveFuel()
  else
    Log.info(("Bot fuel level %d is above minimum %d"):format(fuel_level, Bot.MIN_FUEL))
  end

  return true
end

function StoreBot:up(count)
  count = Utils.numberOrDefault(count, 1)
  while count > 0 do
    local ok, err = self.bot:up()
    if not ok then
      return false, err
    end

    count = count - 1
  end

  return true
end

function StoreBot:down(count)
  count = Utils.numberOrDefault(count, 1)
  while count > 0 do
    local ok, err = self.bot:down()
    if not ok then
      return false, err
    end

    count = count - 1
  end

  return true
end

function StoreBot:forward(count)
  count = Utils.numberOrDefault(count, 1)
  while count > 0 do
    local ok, err = self.bot:forward()
    if not ok then
      return false, err
    end

    count = count - 1
  end

  return true
end

function StoreBot:backward(count)
  count = Utils.numberOrDefault(count, 1)
  while count > 0 do
    local ok, err = self.bot:backward()
    if not ok then
      return false, err
    end

    count = count - 1
  end

  return true
end

function StoreBot:move(steps)
  local ok, err

  Log.assertIs(steps, "table")
  if steps.__index == Direction.DirSeq then
    steps = steps:finish()
  end

  for _, step in ipairs(steps) do
    if step.direction == Direction.Up then
      ok, err = self:up(step.count)
      if not ok then
        Log.error(("Unable to move up %d steps: %s"):format(step.count, err))
        return false, "Unable to move up: " .. err
      end
    elseif step.direction == Direction.Down then
      ok, err = self:down(step.count)
      if not ok then
        Log.error(("Unable to move down %d steps: %s"):format(step.count, err))
        return false, "Unable to move down: " .. err
      end
    else
      ok, err = self.bot:face(step.direction)
      if not ok then
        Log.error(("Unable to turn to face direction %s: %s"):format(Direction.dirName(step.direction), err))
        return false, "Unable to turn: " .. err
      end

      if step.count > 0 then
        ok, err = self:forward(step.count)
        if not ok then
          Log.error(("Unable to move forward %d steps: %s"):format(step.count, err))
          return false, "Unable to move: " .. err
        end
      end
    end
  end

  return true
end

local COLSCAN_DIR = {
  { StoreBot.forward, 1, 1 },
  { StoreBot.backward, STORAGE_SET_WIDTH, -1 },
}

function StoreBot:scanDrawers(side, set_coord)
  local ok, err

  local start = self.bot.pos:clone()
  local drawer_set = self:getDrawerSet(set_coord)
  Log.assertClass(drawer_set, DrawerSet)

  local face_dir
  if side == "east" then
    face_dir = Direction.West
  elseif side == "west" then
    face_dir = Direction.East
  end

  local dir = 1

  for row = 1, STORAGE_SET_HEIGHT do
    -- Move down to the next row
    ok, err = self:down()
    if not ok then
      Log.error("Unable to move down to next row:", err)
      return false, "Unable to move row"
    end

    local colscan = COLSCAN_DIR[dir]
    local count = STORAGE_SET_WIDTH
    local col = colscan[2]

    while count > 0 do
      ok, err = self.bot:face(face_dir)
      if not ok then
        Log.error("Unable to face drawer:", err)
        return false, "Unable to face drawer"
      end

      local drawer = drawer_set.drawers[side][row][col]
      Log.assertClass(drawer, Drawer)
      self:forgetLocationsForDrawer(drawer)
      ok, err = drawer:inspect("front")
      if not ok then
        Log.error(("Failed to inspect storage at %d:%d on side %s in set %s"):format(row, col, side, set_coord))
        return false, "Failed to inspect storage"
      end

      drawer.pos = self.bot.pos:clone()
      drawer.dir = self.bot.dir
      self:addLocationsForDrawer(drawer)

      -- Turn back away from the drawer
      self.bot:face(Direction.North)

      if count > 1 then
        ok, err = colscan[1](self)
        if not ok then
          Log.error(
            ("Failed to move %s after inspecting storage at %d:%d on side %s in set %s: %s"):format(
              dir,
              row,
              col,
              side,
              set_coord
            )
          )
        end
      end

      count = count - 1
      col = col + colscan[3]
    end

    dir = 1 + dir % 2
  end

  -- -- Move back to the start location
  ok, err = self.bot:pathFind(start, 200)
  if not ok then
    Log.error("Failed to path find back to start:", err)
    return false, "Failed to return to start"
  end

  return true
end

function StoreBot:scanDrawerSet(coord)
  local start = self.bot.pos:clone()
  local ok, err

  -- Scan all the drawers on the right (west)
  ok, err = self:scanDrawers("west", coord)
  if not ok then
    Log.error("Failed to scan west drawers:", err)
    return false, "Failed to scan west drawers"
  end

  -- Move to the other side
  ok, err = self:move(Direction.seq():south(1):east(3):north(1))
  if not ok then
    Log.error("Failed to move to east side of drawer set:", err)
    return false, "Failed to move to east drawers"
  end

  -- Scan all the drawers on the left (east)
  ok, err = self:scanDrawers("east", coord)
  if not ok then
    Log.error("Failed to scan east drawers:", err)
    return false, "Failed to scan east drawers"
  end

  -- Move back to the start location
  ok, err = self.bot:pathFind(start, 200)
  if not ok then
    Log.error("Failed to path find back to start:", err)
    return false, "Failed to return to start"
  end

  return true
end

local STORAGE_SETS_SCAN = {
  {
    coord = Coord:create(1, 1),
    move = Direction.seq():up(4):north(2):west(3):north(1):finish(),
  },
  {
    coord = Coord:create(1, 2),
    move = Direction.seq():north(6):finish(),
  },
  {
    coord = Coord:create(1, 3),
    move = Direction.seq():north(6):finish(),
  },
  {
    coord = Coord:create(2, 3),
    move = Direction.seq():south(1):east(5):north(1):finish(),
  },
  {
    coord = Coord:create(2, 2),
    move = Direction.seq():south(6):north(0):finish(),
  },
  {
    coord = Coord:create(2, 1),
    move = Direction.seq():south(6):north(0):finish(),
  },
  {
    coord = Coord:create(3, 1),
    move = Direction.seq():south(1):east(5):north(1):finish(),
  },
  {
    coord = Coord:create(3, 2),
    move = Direction.seq():north(6):finish(),
  },
  {
    coord = Coord:create(3, 3),
    move = Direction.seq():north(6):finish(),
  },
}

function StoreBot:scan()
  local ok, err

  -- Make sure that we have enough fuel
  ok, err = self:refuelIfNeeded()
  if not ok then
    return false, "Failed to refuel bot"
  end

  self.itemLocations = {}
  for _, set in ipairs(STORAGE_SETS_SCAN) do
    Log.info("Scanning drawer set", set.coord)

    ok, err = self:move(set.move)
    if not ok then
      Log.error("Failed to move to storage drawer set", set.coord)
      return false, "Failed to move to storage drawer set"
    end

    ok, err = self:scanDrawerSet(set.coord)
    if not ok then
      Log.error("Failed to scan drawer set:", err)
      return false, "Failed to scan drawer set"
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

function StoreBot:run()
  local ok, err

  -- Make sure that we have enough fuel
  ok, err = self:refuelIfNeeded()
  if not ok then
    Log.error("Encountered error refueling:", err)
    return false, "Failed to refuel bot"
  end

  return true
end

local function main(...)
  local args = { ... }
  local bot = StoreBot:create()
  local ok, err

  if #args == 0 then
    ok, err = bot:run()
  elseif #args == 1 then
    if args[1] == "run" then
      ok, err = bot:run()
    elseif args[1] == "scan" then
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
