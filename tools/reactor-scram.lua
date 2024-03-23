local reactor = peripheral.find("fissionReactorLogicAdapter")
if not reactor then
  error("No fission reactor logic adapter found")
end

print("Monitoring reactor ...")
while true do
  local coolant = reactor.getCoolant()
  if coolant.amount < 17500000 then
    print(("Reactor coolant dropped to: %d"):format(coolant.amount))
    reactor.scram()
    break
  end
  
  local damage = reactor.getDamagePercent()
  if damage > 0 then
    print(("Reactor damage rose to: %d"):format(damage))
    reactor.scram()
    break
  end
  
  sleep(1)
end
