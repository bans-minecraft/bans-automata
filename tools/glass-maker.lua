-- [2023-11-10] Invert signal from top due to redstone candle
-- [2023-11-01] Intial commit

local BLOCK_READER

local function init()
  print("Initializing redstone signals and peripherals")
  redstone.setOutput("left", false)
  redstone.setOutput("right", false)
  redstone.setOutput("top", true)
  BLOCK_READER = peripheral.find("blockReader")
  if not BLOCK_READER then
    error("Unable to create block reader")
  end
end

local function signal(side)
  local mode = true
  if side == "top" then
    mode = not mode
  end
  
  redstone.setOutput(side, mode)
  sleep(0.25)
  redstone.setOutput(side, not mode)
end

local function placeSand()
  signal("top")
end

local function smeltSand()
  signal("left")
end

local function breakGlass()
  signal("right")
end

local function dispatchBlock(block)
  if block == "none" then
    placeSand()
    sleep(0.125)
  elseif block == "minecraft:sand" then
    smeltSand()
  elseif block == "minecraft:glass" then
    breakGlass()
  else
    print("Ignoring unknown block: " .. block)
  end
end

local function main()
  init()
  
  local stop = false
  local last, lastCount = 0
  
  while not stop do
    local block = BLOCK_READER.getBlockName()
    if block then
      if block == last and lastCount > 10 then
        print(("Tried to process block '%s' %d times"):format(block, lastCount))
        stop = true
      else
        dispatchBlock(block)
        last = block
        lastCount = 0
      end
    end
    
    sleep(0.25)
  end
end


main()
