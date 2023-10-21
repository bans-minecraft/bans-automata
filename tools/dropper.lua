local DROPPER_PERIOD = 1
local DROPPER_WAIT   = 5

local SIDE           = "right"
local DROPPER        = peripheral.wrap(SIDE)

local function getDropperItems()
  local count = 0

  for _, item in pairs(DROPPER.list()) do
    count = count + item.count
  end

  return count
end

local function dropItems(count)
  print(("Dropping %d items"):format(count))
  while count > 0 do
    redstone.setOutput(SIDE, true)
    sleep(DROPPER_PERIOD / 2)
    redstone.setOutput(SIDE, false)
    sleep(DROPPER_PERIOD / 2)
    count = count - 1
  end

  print("Done. Waiting for more items.")
end

local function loop()
  while true do
    local count = getDropperItems()
    if count > 0 then
      dropItems(count)
    end

    sleep(DROPPER_WAIT)
  end
end

local function main()
  if #args > 0 then
    SIDE = table.remove(args, 1)
    DROPPER = peripheral.wrap(SIDE)
  end

  loop()
end

main({ ... })
