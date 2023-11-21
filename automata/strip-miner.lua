--
--    _____ _        _       __  __ _
--   / ____| |      (_)     |  \/  (_)
--  | (___ | |_ _ __ _ _ __ | \  / |_ _ __   ___ _ __
--   \___ \| __| '__| | '_ \| |\/| | | '_ \ / _ \ '__|
--   ____) | |_| |  | | |_) | |  | | | | | |  __/ |
--  |_____/ \__|_|  |_| .__/|_|  |_|_|_| |_|\___|_|
--                    | |
--                    |_|
--
-- strip-miner.lua
-- Copyright (C) 2023, Blake Rain.
-- Licensed under the BSD3 License. See LICENSE for details.
--
-- A simple strip miner implementation.
--
-- This strip miner expects to start at a location where above it is a chest containing a block used
-- for fuel, and below it is a chest/inventory into which it can deposit what it mined. This deposit
-- chest can be hooked up to a hopper and a series of chest, or whatever.
--
-- The bot will start to create a strip mine. The mine extends forwards from the bots home position.
-- Branches will be taken from the main strip, every three blocks (there will be a gap of three
-- blocks between each branch, or as configured).
--
-- When the bot encounters ores, it will excavate all ores it can find in the vein. Once it has done
-- so, it will return to it's location in the branch, and then continue mining the branch. Once the
-- branch is complete, the bot will return to the home location to deposit any blocks it mined and
-- optionally gather more fuel. The bot will traverse the branch on the upper row to detect any
-- ores, and excavate them.
--
-- [2023-06-15] Initial version
-- [2023-06-15] A* algorithm using AA built during movement/mining
-- [2023-06-16] Add scanning during mining to build better AA image
-- [2023-06-16] Clear AA after returned home to deposit blocks
-- [2023-06-16] Excavation exploration code
-- [2023-06-16] Excavation task checks AA after pop to avoid repeated mining
-- [2023-06-16] Added backtrace to log.error calls
-- [2023-06-16] Fixed issue with A* using incorrect AA node status
-- [2023-06-17] Added AANode class to better encapsulate AA node data
-- [2023-06-17] Moved to Vector type to simplify more code
-- [2023-06-17] Removed fuel-slot test in depositBlocks to avoid clogged fuel slot after mining
-- [2023-06-18] Simplify ores lookup to use table rather than list
-- [2023-11-21] Add function to drop unwanted items

package.path = "/?.lua;/?/init.lua;" .. package.path
local AANode = require("lib.bot.aa.node")
local Bot = require("lib.bot")
local Direction = require("lib.direction")
local Log = require("lib.log")
local Ores = require("lib.bot.ores")
local Utils = require("lib.utils")
local Vector = require("lib.vector")

Log.setLogFile("bot-log.txt")

local BRANCH_GAP = 3 -- Number of blocks between branches (default: 3)
local MAX_BRANCHES = 200 -- Maximum number of branches (default: 200)
local MAX_DEPTH = 200 -- Maximum branch depth (default: 200)

local Miner = {}
Miner.__index = Miner
Miner.__name = "Miner"

function Miner:create(dir)
  local miner = {}
  setmetatable(miner, Miner)

  miner.bot = Bot:create(dir)
  miner.branchIndex = -1
  miner.branchSide = ""

  return miner
end

function Miner:receiveFuel()
  -- Check to see if we need fuel
  local level = turtle.getFuelLevel()
  if level == "unlimited" then
    return true
  end

  -- See what is above us, using the AA
  local up = self.bot:queryUp()
  if up.state ~= AANode.FULL then
    Log.error("Unable to find block for fuel inventory above bot")
    return false
  end

  -- Make sure that what we found above us is something that has an inventory
  if up.info.name ~= "minecraft:chest" and up.info.name ~= "minecraft:hopper" then
    Log.error("Unknown fiel source block above bot:", up.info)
    return false
  end

  -- Select the bot's fuel slot
  turtle.select(self.bot.fuelSlot)
  -- Receive up to a stack of fuel from the inventory placed above us.
  turtle.suckUp()

  -- Examine what we have in our fuel slot
  local info = turtle.getItemDetail(self.bot.fuelSlot)
  if info == nil then
    Log.error("No items found in fuel slot (" .. self.bot.fuelSlot .. ") after refueling")
    turtle.select(1)
    return false
  end

  if info.name ~= "minecraft:coal" then
    Log.error("Unknown fuel " .. info.name .. " found in fuel slot (" .. self.bot.fuelSlot .. ")")
    turtle.select(1)
    return false
  end

  -- Use the fuel to refuel the bot
  local ok, err = turtle.refuel()
  if not ok then
    Log.error("Failed to refuel bot: " .. err)
    turtle.select(1)
    return false
  end

  local new_level = turtle.getFuellevel()
  Log.info(("Refuelled bot %d (current level: %d)"):format(new_level - level, new_level))
  return true
end

function Miner:depositBlocks()
  -- Check the block below us
  local below = self.bot:queryDown()
  if below.state ~= AANode.FULL then
    Log.error("Unable to find block below bot")
    return false
  end

  if below.info.name ~= "minecraft:chest" and below.info.name ~= "minecraft:hopper" then
    Log.error("Unknown inventory block below bot: " .. below.info.name)
    return false
  end

  Log.info("Emptying inventory ...")
  local dropped = 0
  for slot = 1, 16 do
    local info = turtle.getItemDetail(slot)
    if info ~= nil and info.count > 0 then
      Log.info(("Dropping %d block(s): %s"):format(info.count, info.name))
      turtle.select(slot)
      turtle.dropDown(info.count)
      dropped = dropped + info.count
    end
  end

  Log.info(("Dropped %d items"):format(dropped))
  return true
end

function Miner:homeProcesses()
  if not self:depositBlocks() then
    return false
  end

  local fuel_level = turtle.getFuelLevel()
  if fuel_level < Bot.MIN_FUEL then
    Log.info("Bot fuel level is low, attempting to refuel ...")
    if not self:receiveFuel() then
      return false
    end
  end

  return true
end

function Miner:moveUp(count, dig)
  local moved = 0
  while moved < count do
    while true do
      local ok, err = self.bot:up()
      if ok then
        break
      end

      if not dig then
        Log.error("Bot was unable to move: blocked, unable to dig")
        return false, "unable to dig"
      end

      ok, err = self.bot:mineUp()
      if not ok then
        Log.error("Bot was unable to mine up: " .. err)
        return false, err
      end
    end

    moved = moved + 1
  end

  return true
end

function Miner:moveDown(count, dig)
  local moved = 0
  while moved < count do
    while true do
      local ok, err = self.bot:down()
      if ok then
        break
      end

      if not dig then
        Log.error("Bot was unable to move: blocked, unable to dig")
        return false, "unable to dig"
      end

      ok, err = self.bot:mineDown()
      if not ok then
        Log.error("Bot was unable to mine down: " .. err)
        return false, err
      end
    end

    moved = moved + 1
  end

  return true
end

function Miner:moveForwards(count, dig, digUp)
  local moved = 0
  while moved < count do
    while true do
      local ok, err = self.bot:forward()
      if ok then
        break
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

    -- If we're digging up, then we want to mine up. This might cause some blocks (like gravel) to
    -- descend onto the bot. In which case we want to mine up repeatedly until the block above us
    -- is empty.
    if digUp then
      while true do
        local up = self.bot:queryUp(true)
        if up.state ~= AANode.FULL then
          break
        end

        self.bot:mineUp()
      end
    end

    moved = moved + 1
  end

  return true
end

function Miner:findBranch()
  -- Reset our branch state variables
  self.branchIndex = -1
  self.branchSide = ""

  while self.branchIndex < MAX_BRANCHES do
    -- Move forwards to the next branch position, allow mining forwards and up for main corridor.
    local ok, err = self:moveForwards(BRANCH_GAP, true, true)
    if not ok then
      return false, err
    end

    self.branchIndex = 1 + self.branchIndex

    -- Inspect the block on our left, using the AA
    local left = self.bot:queryLeft()
    if left.state == AANode.FULL then
      -- We have a block on our left, so we can start branch mining there
      Log.info("Found block " .. left.info.name .. " on the left")
      self.branchSide = "left"
      return true
    end

    -- Inspect the block on our right, using the AA
    local right = self.bot:queryRight()
    if right.state == AANode.FULL then
      -- We have a block on our right, so we can start branch mining there
      Log.info("Found block " .. right.info.name .. " on the right")
      self.branchSide = "right"
      return true
    end
  end

  Log.warn(("Reached branch limit of %d"):format(MAX_BRANCHES))
  return false, "Branch limit reached"
end

local DROP = {
  ["minecraft:tuff"] = true,
  ["minecraft:deepslate"] = true,
  ["minecraft:cobbled_deepslate"] = true,
}

function Miner:dropUnwanted()
  -- Go through the bots inventory and check to see if we should keep each item. If the item is
  -- something that we want to reject, then drop it.
  for slot = 1, 16 do
    local info = turtle.getItemDetail(slot)
    if info and DROP[info.name] == true then
      Log.info(("Dropping unwanted %ix %s"):format(info.count, info.name))
      turtle.select(slot)
      turtle.drop()
    end
  end
end

function Miner:excavationScan()
  local result = {}

  local queries = {
    { self.bot:queryForward(), self.bot.dir },
    { self.bot:queryLeft(), self.bot:leftDirection() },
    { self.bot:queryRight(), self.bot:rightDirection() },
    { self.bot:queryUp(), Direction.Up },
    { self.bot:queryDown(), Direction.Down },
  }

  for _, query in ipairs(queries) do
    if query[1].state == AANode.FULL and Ores.isOre(query[1].info) then
      table.insert(result, { self.bot.pos:clone(), query[2] })
    end
  end

  return result
end

function Miner:excavate()
  -- We maintain a stack of mining locations to visit. These are locations in our AA in which we've
  -- found ores that we want to mine. Each entry in the stack is the location of the bot when it
  -- discovered the ore, and the direction in which the ore was located.
  local stack = {}
  local total = 0

  -- Push the first excavation scan onto the stack
  Utils.concat(stack, self:excavationScan())

  while #stack > 0 do
    -- Get the position and direction of the ore that we found from the top of the stack.
    local target_pos, target_dir = table.unpack(table.remove(stack, #stack))

    -- Check the AA to see if the block still contains a valid ore. If we've mined the ore already,
    -- then the AA will be updated to indicate the block is vacant.
    local target_block_node = self.bot.aa:query(Direction.offsetDirection(target_pos, target_dir))
    if target_block_node.state == AANode.FULL then
      -- Move the bot to the target bot position using the AA path finding.
      local ok, err = self.bot:pathFind(target_pos, 200)
      if not ok then
        Log.error(("Failed to path find to ore at %s: %s"):format(target_pos, err))
        return false, err
      end

      -- If the ore is on a side (not up or down), then turn to face the block that we want to mine.
      if target_dir ~= Direction.Up and target_dir ~= Direction.Down then
        self.bot:face(target_dir)
      end

      -- Try and mine in the given direction. We do this repeatedly as we might expose gravel that
      -- would shift downwards onto the bot, or into the location that we've mined. We want the
      -- space to end up clear.
      local mined = false
      while not mined do
        -- Perform our mining action
        if target_dir == Direction.Up then
          ok, err = self.bot:mineUp()
        elseif target_dir == Direction.Down then
          ok, err = self.bot:mineDown()
        else
          ok, err = self.bot:mineForward()
        end

        -- If we couldn't mine, then we want to abandon this excavation: something is wrong
        if not ok then
          Log.error(
            ("Failed to mine block in direction %s of bot position %s"):format(
              Direction.dirName(target_dir),
              target_pos
            )
          )
          break
        end

        -- Increment the number of blocks we've mined
        total = total + 1

        -- Get information about the block that we've just mined. This should have been updated by
        -- the `mine` function that we called.
        target_block_node = self.bot.aa:query(Direction.offsetDirection(self.bot.pos, target_dir))
        if target_block_node.state == AANode.EMPTY then
          mined = true
        end
      end

      -- If we didn't end up managing any mining, then we abandon the excavation
      if not mined then
        break
      end

      -- Move into the location that we have just mined.
      if target_dir == Direction.Up then
        ok, err = self:moveUp(1, true)
      elseif target_dir == Direction.Down then
        ok, err = self:moveDown(1, true)
      else
        -- We're already facing the block we just mined
        ok, err = self:moveForwards(1, true, false)
      end

      if not ok then
        Log.error("Failed to move bot into mined location: " .. err)
        return false, err
      end

      -- Perform an excavation scan and place the results onto the excavation stack.
      Utils.concat(stack, self:excavationScan())
    end
  end

  if total > 0 then
    Log.info("Excavated " .. total .. " blocks")
  end
  return true
end

function Miner:mineBranch(returning)
  local depth = 0

  Log.info(
    ("Mining %d blocks %s branch %d on the %s"):format(
      MAX_DEPTH,
      returning and "back up" or "down",
      self.branchIndex + 1,
      self.branchSide
    )
  )

  while depth < MAX_DEPTH do
    -- Move the bot forwards, doing our mining (dig forwards and up)
    local ok, err = self:moveForwards(1, true, not returning)
    if not ok then
      return false, err
    end

    depth = depth + 1

    -- We want to excavate any ores we find. First we want to store the current location of the bot
    -- so we can return here when we're done.
    local start_pos, start_dir = self.bot.pos:clone(), self.bot.dir

    ok, err = self:excavate()
    if not ok then
      return false, "Excavation failed"
    end

    if self.bot.pos:neq(start_pos) then
      -- Return to the original location before we started excavation
      Log.info("Returning to location before excavation")
      ok, err = self.bot:pathFind(start_pos, 200)
      if not ok then
        Log.error("Bot failed to return after excavating: " .. err)
        return false, "Failed to return from excavating"
      end
    end

    if self.bot.dir ~= start_dir then
      Log.info(
        ("Returning to original direction %s (was %s)"):format(
          Direction.dirName(self.bot.dir),
          Direction.dirName(start_dir)
        )
      )
      self.bot:face(start_dir)
    end

    self:dropUnwanted()
  end

  return true
end

function Miner:loop()
  -- Store our "forwards" direction, which is where the bot starts
  local forward_dir = self.bot.dir

  while true do
    -- Erase the bots AA so we start with a fresh view of the world
    self.bot:clearAA()

    -- Perform our home processes
    if not self:homeProcesses() then
      Log.error("Failed to perform home processes (depositing blocks and refuelling)")
      return
    end

    -- Make sure that we sufficient fuel to perform our mining
    local fuel_level = turtle.getFuelLevel()
    if fuel_level < Bot.MIN_FUEL then
      Log.error(("Fuel level %d is below minimum of %d"):format(fuel_level, Bot.MIN_FUEL))
      return
    else
      Log.info(("Bot has %d fuel, which is at least minimum of %d"):format(fuel_level, Bot.MIN_FUEL))
    end

    -- Move forwards to the start position. This is one block forwards of our home position (no digging).
    Log.info("Moving to start position")
    local ok, err = self:moveForwards(1, false, false)
    if not ok then
      Log.error("Unable to move to start position: " .. err)
      return
    end

    -- Find the branch that we want to mine down
    Log.info("Finding branch")
    ok, err = self:findBranch()
    if not ok then
      -- Turn the bot back around and proceed back to the home position
      ok, err = self.bot:pathFind(Vector:create(0, 0, 0), 400)
      if not ok then
        Log.error("Unable to return to home position: " .. err)
        return
      end

      -- Turn back to our original direction
      self.bot:face(forward_dir)
      -- The bot couldn't find a branch, so we're done. Do some home processes anyway.
      self:homeProcesses()
      return
    end

    -- We have found our branch (on either the "left" or "right"). Now the bot can proceed to
    -- perform the mining down the branch.
    if self.branchSide == "left" then
      self.bot:turnLeft()
    elseif self.branchSide == "right" then
      self.bot:turnRight()
    else
      Log.error("Unrecognized branch side: " .. self.branchSide)
      return
    end

    ok, err = self:mineBranch(false)
    if not ok then
      Log.error("Failed to mine along branch: " .. err)
      return
    end

    -- We've successfully mined a branch. We now want to return. However, we might have missed
    -- blocks on the top row of the branch whilst mining, as we only scan left and right. We move
    -- the bot up, and then use `mineBranch` to return back along the branch.

    -- Move up and turn around
    self.bot:up()
    self.bot:turnRight()
    self.bot:turnRight()

    -- Mine the branch backwards
    ok, err = self:mineBranch(true)
    if not ok then
      Log.error("Failed to return along branch: " .. err)
      return
    end

    -- We've succesfully mined the branch forwards and back. Return to the home position
    ok, err = self.bot:pathFind(Vector:create(), 400)
    if not ok then
      Log.error("Unable to return to home position: " .. err)
      return
    end

    -- Turn back to our original dorection
    self.bot:face(forward_dir)
  end
end

local function main(args)
  local dir = Direction.North
  if #args > 0 then
    local found, arg_dir = false, args[1]
    for key, val in pairs(Direction) do
      if string.lower(key) == string.lower(arg_dir) then
        dir = val
        found = true
        break
      end
    end

    if not found then
      error("Unrecognized direction '" .. arg_dir .. "'")
    end
  end

  local miner = Miner:create(dir)
  miner:loop()
end

main({ ... })
