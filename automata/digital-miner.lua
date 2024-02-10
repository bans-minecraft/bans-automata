--
-- digital-miner.lua
--
-- A shepherd for the Digital Miner from Mekanism.
--
-- The bot works through the following states:
--
-- 1. BUILDING
-- 2. WAITING
-- 3. CHECKING_POWER
-- 4. AWAITING_POWER
-- 5. DISMANTLING
-- 6. MOVING
--
-- When in

package.path = "/?.lua;/?/init.lua;" .. package.path
local Assert = require("lib.assert")
local Bot = require("lib.bot")
local Class = require("lib.class")
local Direction = require("lib.direction")
local Enum = require("lib.enum")
local Log = require("lib.log")
local String = require("lib.string")
local Table = require("lib.table")
local Vector = require("lib.vector")

Log.setLogFile("digital-miner.log", true)

local State = Enum("BUILDING", "WAITING", "CHECKING_POWER", "AWAITING_POWER", "DISMANTLING", "MOVING")

local Shepherd = Class("Shepherd", Bot)

function Shepherd:init()
  Bot.init(self)
  self.state = State.BUILDING
end

function Shepherd:expectInventorySlot(slot, name, count)
  Assert.assertIsNumber(slot)
  Assert.assertIsString(name)
  Assert.assertIsNumber(count)
  local info = turtle.getItemDetail(slot)
  if not info then
    error(("Expected turtle inventory slot %d to contains %dx %s"):format(slot, count, name))
  end

  if info.name ~= name then
    error(("Expected turtle inventory slot %d to contain %dx %s; found %s instead"):format(slot, count, name, info.name))
  end

  if info.count ~= count then
    error(("Expected turtle inventory slot %d to contain %dx %s; found %d instead"):format(slot, count, name, info.count))
  end
end

function Shepherd:mineForward()
  local current = turtle.getSelectedSlot()
  turtle.select(16)

  local ok, err = Bot.mineForward(self)
  if not ok then
    turtle.select(current)
    error("Failed to mine forward: " .. err)
  end

  turtle.drop()
  turtle.select(current)
end

function Shepherd:mineUp()
  local current = turtle.getSelectedSlot()
  turtle.select(16)

  local ok, err = Bot.mineUp(self)
  if not ok then
    turtle.select(current)
    error("Failed to mine up: " .. err)
  end

  turtle.drop()
  turtle.select(current)
end

function Shepherd:mineDown()
  local current = turtle.getSelectedSlot()
  turtle.select(16)

  local ok, err = Bot.mineDown(self)
  if not ok then
    turtle.select(current)
    error("Failed to mine down: " .. err)
  end

  turtle.drop()
  turtle.select(current)
end

function Shepherd:moveForward(count)
  local moved = 0
  while moved < count do
    while true do
      local ok, _ = self:forward()
      if ok then
        break
      end

      self:mineForward()
    end

    moved = moved + 1
  end
end

function Shepherd:moveUp(count)
  local moved = 0
  while moved < count do
    while true do
      local ok, _ = self:up()
      if ok then
        break
      end

      self:mineUp()
    end

    moved = moved + 1
  end
end

function Shepherd:moveDown(count)
  local moved = 0
  while moved < count do
    while true do
      local ok, _ = self:down()
      if ok then
        break
      end

      self:mineDown()
    end

    moved = moved + 1
  end
end

function Shepherd:clearBuildArea()
  -- The area that we want to clear infront of the bot looks like the following, and takes up three
  -- layers.
  --
  --            c.....b
  --     Bot -> X.....a
  --            d.....e

  for _ = 1, 3 do
    self:moveForward(6) -- Move/mine to a
    self:turnLeft()
    self:moveForward(1) -- Move/mine to b
    self:turnLeft()
    self:moveForward(6) -- Move/mine to c
    self:turnLeft()
    self:moveForward(2) -- Move/mine to d
    self:turnLeft()
    self:moveForward(6) -- Move/mine to e
    self:turnLeft()
    self:moveForward(1) -- Move back to a
    self:turnLeft()
    self:moveForward(6) -- Move back to X
    self:turnLeft()
    self:turnLeft()
    self:moveUp(1)
  end

  self:moveDown(3)
end

function Shepherd:building()
  -- Check that our inventory slots are what we expect
  self:expectInventorySlot(1, "mekanism:digital_miner", 1)
  self:expectInventorySlot(2, "mekanism:ultimate_energy_cube", 1)
  self:expectInventorySlot(3, "mekanism:ultimate_energy_cube", 1)
  self:expectInventorySlot(4, "mekanism:ultimate_energy_cube", 1)
  self:expectInventorySlot(5, "mekanism:ultimate_universal_cable", 1)
  self:expectInventorySlot(6, "utamacraft:digitizer", 1)

  -- Clear the build area for the digital miner
  self:clearBuildArea()

  -- Move to the end and place the batteries and then the cable
  self:moveUp(1)
  self:moveForward(5)
  turtle.select(2)
  turtle.place()
  self:backward(1)
  turtle.select(3)
  turtle.place()
  self:backward(1)
  turtle.select(5)
  turtle.place()

  -- Move down and back and place the digital miner
  self:backward(1)
  self:moveDown(1)
  self:turnRight()
  turtle.select(1)
  turtle.placeUp()
  self:turnLeft()

  -- Move to the socket position
  self:backward(2)
  self:moveUp(1)
end

function Shepherd:run()
  self:building()
end

local function main()
  local shepherd = Shepherd:new()
  shepherd:run()
end

local ok, res = xpcall(main, debug.traceback, ...)
if not ok then
  Log.error(res)
  print(res)
end
