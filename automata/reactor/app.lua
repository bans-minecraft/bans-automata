local Class = require("lib.class")
local App = require("lib.widget.app")
local Settings = require("automata.reactor.settings")
local Model = require("automata.reactor.model")

local ReactorApp = Class("ReactorApp", App)

function ReactorApp:init()
  App.init(self)

  self.settings = Settings:new()
  self.settings:load()

  self.model = Model:new(self.ettings)

  self.statusWindows = {}
  local StatusWindow = require("automata.reactor.windows.status")

  local window = StatusWindow:new(self.model)
  self:bindTerm(window)
  table.insert(self.statusWindows, window)

  local monitor = peripheral.find("monitor")
  if monitor ~= nil then
    monitor.setTextScale(0.5)
    window = StatusWindow:new(self.model)
    self:bindMonitor(monitor, window)
    table.insert(self.statusWindows, window)
  end

  self:addTask(function()
    while true do
      self.model:update()
      self:updateStatusWindows()
      sleep(0.500)
    end
  end)
end

function ReactorApp:updateStatusWindows()
  for _, window in ipairs(self.statusWindows) do
    window:update()
  end
end

return ReactorApp
