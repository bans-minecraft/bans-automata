local chest = peripheral.wrap("right")
local dropper = peripheral.wrap("front")

local function emptyDropper()
  local dir  = peripheral.getName(dropper)
  local size = dropper.size()
  for round = 1, 2 do
    for slot = 1, size do
      local info = dropper.getItemDetail(slot)
      while info ~= nil do
        redstone.setOutput(dir, true)
        sleep(0.25)
        redstone.setOutput(dir, false)
        sleep(0.25)
        info = dropper.getItemDetail(slot)
      end
    end
  end
end

local function dumpSlot(slot, info)
  print(("Dumping %d items of %s from slot %i"):format(info.count, info.name, slot))
  chest.pushItems(peripheral.getName(dropper), slot, info.count)
  emptyDropper()
end

local GARBAGE = {
  ["minecraft:deepslate"] = true,
  ["minecraft:cobbled_deepslate"] = true,
  ["minecraft:tuff"] = true
}

local function clearChest()
  local size = chest.size()
  for slot = 1, size do
    local info = chest.getItemDetail(slot)
    if info then
      if GARBAGE[info.name] == true then
        dumpSlot(slot, info)
      end
    end
  end
end

local function main()
  while true do
    clearChest()
    sleep(5)
  end
end

main()
