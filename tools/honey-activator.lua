local output = redstone.getOutput("top")

function triggerDispenser()
  redstone.setOutput("top", not output)
  output = not output
end

function run()
  while true do
    local level = redstone.getAnalogInput("back")
    if level >= 5 then
      triggerDispenser()
    end
    
    sleep(1)
  end
end

run()
