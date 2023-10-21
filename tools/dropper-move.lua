-- dropper-move.lua
--
-- Move items from an inventory into a dropper, and then empty that dropper. This can be used to
-- scan connected inventories and then move items into a dropper and then trigger that dropper. The
-- items can also be filtered.
--
-- This tool takes a configuration file, with the path to the file specified on the command line:
--
--     lua dropper-move.lua my-config.cfg
--
-- If no configuration file is specified, the tool looks for a file called 'dropper-move.cfg' in the
-- current directory. If no configuration file is found, the defaults are used.
--
-- The configuratino file should have the following form, which also shows the defaults:
--
-- {
--   dropper = {
--     side = "bottom",      // The position of the dropper
--     rate = 0.5,           // The rate at which items should be dropped
--   },
--   inventory = {
--     sides = { "top" },    // The side(s) on which we find the inventory to scan
--     only  = {             // The filter for elements to move
--       "minecraft:deepslate",
--       "minecraft:cobbled_deepslate",
--       "minecraft:tuff"
--     }
--   }
-- }

package.path = "/?.lua;" .. package.path
local Log = require("lib/log")
local Utils = require("lib/utils")

local DEFAULT_CONFIG = {
  dropper = {
    side = "bottom",
    rate = 0.5
  },
  inventory = {
    sides = { "top" },
    only  = {
      "minecraft:deepslate",
      "minecraft:cobbled_deepslate",
      "minecraft:tuff"
    }
  }
}

local CONFIG = Utils.cloneTable(DEFAULT_CONFIG)
local function loadConfig(args)
  local config_path = args[1] or (shell.dir() .. "/dropper-move.cfg")
  CONFIG = Utils.loadConfig(config_path)
end

local function shouldMove(name)
  if CONFIG.inventory.only[name] then
    return true
  end

  if Utils.contains(CONFIG.inventory.only, name) then
    return true
  end

  return false
end

local INVENTORIES = {}
local DROPPER

local function createPehirpherals()
  DROPPER = peripheral.wrap(CONFIG.dropper.side)
  for _, side in ipairs(CONFIG.inventory.sides) do
    table.insert(INVENTORIES, peripheral.wrap(side))
  end
end

local function emptyDropper()
  local dir  = peripheral.getName(DROPPER)
  local size = DROPPER.size()

  for _ = 1, 2 do
    for slot = 1, size do
      local info = DROPPER.getItemDetail(slot)
      while info ~= nil do
        redstone.setOutput(dir, true)
        sleep(CONFIG.dropper.rate / 2)
        redstone.setOutput(dir, false)
        sleep(CONFIG.dropper.rate / 2)
        info = DROPPER.getItemDetail(slot)
      end
    end
  end
end

local function dumpSlot(index, slot, info)
  print(("Dumping %d items of %s from slot %i of %s")
    :format(info.count, info.name, slot, CONFIG.inventory.sides[index]))
  INVENTORIES[index].pushItems(peripheral.getName(DROPPER), slot, info.count)
  emptyDropper()
end

local function emptyInventories()
  for index, inventory in ipairs(INVENTORIES) do
    local size = inventory.size()
    for slot = 1, size do
      local info = inventory.getItemDetail(slot)
      if info then
        if shouldMove(info.name) then
          dumpSlot(index, slot, info)
        end
      end
    end
  end
end

local function main(args)
  loadConfig(args)
  createPehirpherals()

  while true do
    emptyInventories()
    sleep(5)
  end
end


main({ ... })
