package.path = "/?.lua;/?/init.lua;" .. package.path
local Log = require("lib.log")
local ReactorApp = require("automata.reactor.app")

Log.setEcho(false)
Log.setLogFile("reactor.log", true)
Log.info(("Start of automata: %dT%s"):format(os.day(), textutils.formatTime(os.time())))

local function main(args)
  local app = ReactorApp:new()
  app:run()
end

local ok, res = xpcall(main, debug.traceback, ...)
print(ok, res)
