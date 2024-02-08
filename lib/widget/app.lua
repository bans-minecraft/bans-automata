local Assert = require("lib.assert")
local Class = require("lib.class")
local Log = require("lib.log")
local RenderContext = require("lib.widget.render.context")

local App = Class("App")

function App:init()
  self.monitors = {}
  self.running = false
  self.tasks = {}
end

function App:bindTerm(window)
  Assert.assert(self.monitors["__term"] == nil, "Terminal monitor already bound to window")
  local monitor = {
    context = RenderContext:new(term),
    window = window,
  }

  self.monitors["__term"] = monitor
  return monitor
end

function App:bindMonitor(nameOrPeripheral, window)
  local name, monitor
  if type(nameOrPeripheral) == "table" then
    monitor = nameOrPeripheral
    name = peripheral.getName(monitor)
  elseif type(nameOrPeripheral) == "string" then
    name = nameOrPeripheral
    monitor = peripheral.wrap(name)
    Assert.assertIs(monitor, "table", ("Unable to wrap monitor peripheral '%s'"):format(name))
  else
    error("Expected either peripheral or name as argument")
  end

  Assert.assert(self.monitors[name] == nil, ("Monitor '%s' already bound to window"):format(name))
  local monitor = {
    context = RenderContext:new(monitor),
    window = window,
  }

  self.monitors[name] = monitor
  return monitor
end

function App:render()
  for _, monitor in pairs(self.monitors) do
    if monitor.window and monitor.window:isRedrawQueued() then
      -- Update the size of the RenderContext region as the monitor might have changed size.
      monitor.context:updateSize()

      -- Clear the entire target
      monitor.context.target.clear()

      -- Perform the size calculations
      monitor.window:getSizeRequest()
      local allocation = monitor.context.region:clone()
      monitor.window:setAllocation(allocation)

      -- Render the window to the render context
      monitor.window:render(monitor.context)

      -- Ensure that the RenderContext was not left degenerate
      Assert.assert(#monitor.context.stack == 0, "RenderContext region underflow")
      monitor.window:clearRedraw()
    end
  end
end

function App:_renderLoop()
  while self.running do
    self:render()
    sleep(0.5)
  end
end

function App:_processEvent(eventData)
  local event = eventData[1]
  if event == "timer" then
    return
  end

  Log.info(eventData)

  if event == "key" or event == "key_up" then
    local keyCode = eventData[2]
    Log.info(event, keyCode, keys.getName(keyCode))
  end

  if event == "char" then
    self.running = false
  end
end

function App:_eventLoop()
  while self.running do
    self:_processEvent({ os.pullEvent() })
  end
end

function App:addTask(task)
  Assert.assertIs(task, "function")
  table.insert(self.tasks, task)
end

function App:run()
  local this = self
  local jobs = {
    function() this:_renderLoop() end,
    function() this:_eventLoop() end
  }

  for _, task in ipairs(self.tasks) do
    table.insert(jobs, task)
  end

  self.running = true
  parallel.waitForAny(table.unpack(jobs))
end

return App
