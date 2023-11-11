-- [2023-11-10] Makes the white dye

local pretty = require "cc.pretty"

local function log(...)
  local args = { ... }
  local output = {}
  
  for _, arg in ipairs(args) do
    local arg_pp = pretty.render(pretty.pretty(arg))
    table.insert(output, arg_pp)
  end
  
  output = table.concat(output, " ")
  log_file = fs.open("log.txt", "a")
  log_file.writeLine(output)
  log_file.close()
  print(output)  
end

local function takeLily()
    local ok, err
    
    turtle.select(1)
    while true do
        ok, err = turtle.suck(64)
        if not ok then
            log("No more items to take")
            return true
        end
        
        local n = turtle.getItemCount()
        log("Received", n, "Lily")
        
        -- Put one lily back in the machine
        turtle.transferTo(2, 1)
        turtle.select(2)
        
        turtle.turnLeft()
        turtle.forward()
        turtle.turnRight()
        turtle.forward()
        turtle.turnRight()
        turtle.forward()
        turtle.turnRight()
        
        turtle.place()
        turtle.select(1)
        
        ok, err = turtle.craft()
        if not ok then
            log("Failed to craft white dye:", err)
            return false, err
        end
        
        turtle.turnLeft()
        turtle.forward()
        turtle.turnRight()
        turtle.forward()
        turtle.forward()
        turtle.turnRight()
        
        turtle.place()
        
        turtle.turnRight()
        turtle.forward()
        turtle.forward()
        turtle.turnLeft()
        turtle.forward()
        turtle.turnLeft()
        return false
    end
end

local function loop()
    while true do
        local has_block, data = turtle.inspect()
        if not has_block then
            log("No block infront of turtle")
            return
        end
        
        if not data.state.active then
            print("Insolator has finished")
            if not takeLily() then
                return
            end
        else
            sleep(1)
        end
    end
end

loop() 
