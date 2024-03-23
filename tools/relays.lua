local modem = peripheral.find("modem")
if not modem then error("Unable to find modem peripheral") end
modem = peripheral.getName(modem)

local function send(message)
  rednet.open(modem)
  local hosts = { rednet.lookup("bannet.lab.power") }
  if #hosts == 0 then
    rednet.close(modem)
    error("Unable to find 'bannet.lab.power' host")
  end
  
  local host = hosts[1]
  if not rednet.send(host, message, "bannet.lab.power") then
    rednet.close(modem)
    error("Failed to send message on 'bannet.lab.power' protocol")
  end
  
  local sender, reply = rednet.receive("bannet.lab.power")
  rednet.close(modem)
  
  if not send then
    error("Failed to receive reply on 'bannet.lab.power' protocol")
  end
  
  if reply.result == "error" then
    error(("Received error: %s"):format(reply.reply or "<unknown error>"))
  end
  
  if reply.result ~= "ok" then
    error(("Received unknown result '%s'; expected either 'ok' or 'error'"):format(reply.result))
  end
  
  return reply.reply
end

local function list()
  local result = send({ kind = "get", relay = "all" })
  for id, state in pairs(result) do
    print(("%10s: %s"):format(id, state))
  end
end

local function setRelay(relay, state)
  local result = send({ kind = "set", relay = relay, state = state })
  if relay == "all" then
    for id, info in pairs(result) do
      print(("%10s: %6s -> %6s"):format(id, result.previous, result.current))
    end
  else
    print(("%10s: %6s -> %6s"):format(relay, result.previous, result.current))
  end
end

local function help()
  print("usage; relays <command>")
  print("")
  print("Commands:")
  print("")
  print("  help           Show this help message")
  print("  list           List relay states")
  print("  open all       Open all relays")
  print("  open <relay>   Set a relay to open")
  print("  close all      Close all relays")
  print("  close <relay>  Set a relay to closed")
end

local function main(...)
  local args = {...}
  if #args == 0 then return help() end
  
  local command = table.remove(args, 1)
  if command == "help" then
    help()
  elseif command == "list" then
    list()
  elseif command == "open" then
    if #args ~= 1 then error("Expected argument to 'open' command") end
    setRelay(table.remove(args, 1), "open")
  elseif command == "close" then
    if #args ~= 1 then error("Expected argument to 'close' command") end
    setRelay(table.remove(args, 1), "closed")
  else
    error(("Unrecognized command '%s'"):format(command))
  end
end

main(...)
