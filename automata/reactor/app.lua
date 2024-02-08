local Class = require("lib.class")
local App = require("lib.widget.app")

local ReactorApp = Class("ReactorApp", App)

function ReactorApp:init()
  App.init(self)

  self.controlWindow = require("automata.reactor.windows.control"):new()
  local term = self:bindTerm(self.controlWindow)
  term.context.debug = true

  local monitor = peripheral.find("monitor")
  if monitor ~= nil then
    self.statusWindow = require("automata.reactor.windows.status"):new()
    self:bindMonitor(monitor, self.statusWindow)
  end

  self:addTask(function()
    while true do
      self.controlWindow:update()
      self.statusWindow:update()
      sleep(0.5)
    end
  end)
end

return ReactorApp
