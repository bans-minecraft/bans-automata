local Assert = require("lib.assert")
local Box = require("lib.widget.container.box")
local Class = require("lib.class")
local Label = require("lib.widget.display.label")
local Separator = require("lib.widget.display.separator")
local StatusBar = require("lib.widget.display.statusbar")
local Window = require("lib.widget.display.window")
local Widget = require("lib.widget")

local StatusWindow = Class("StatusWindow", Window)

function StatusWindow:init(model)
  Window.init(self)
  self.model = model

  local status = StatusBar:new()
  self.statusLeft = status:addLabelStart("Reactor Status")
  self.statusRight = status:addLabelEnd()

  self.updaters = {}

  local reactorGroup = self:createStatusGroup("Reactor Status", {
    {
      field = "burnRate",
      name = "Fuel Burn Rate",
      unit = "mB/T",
      format = "%.2f",
      color = function(value)
        local v = value.current:get()
        if v < value.max / 2 then
          return colors.green
        else
          return colors.red
        end
      end
    },
    {
      field = "fuel",
      name = "Fuel",
      unit = "mB",
      format = "%.2f",
      color = function(value)
        local v = value.current:get()
        if v < value.max / 2 then
          return colors.red
        elseif v < value.max then
          return colors.orange
        else
          return colors.green
        end
      end
    },
    {
      field = "fuelWaste",
      name = "Fuel Waste",
      unit = "B",
      format = "%.2f",
      color = function(value)
        local v = value.current:get()
        if v > value.max / 2 then
          return colors.red
        elseif v > 0 then
          return colors.orange
        else
          return colors.green
        end
      end
    },
    Separator:new("horizontal"),
    {
      field = "boilEfficiency",
      name = "Boil Efficiency",
      format = "%.2f",
      color = function(value)
        local v = value.current:get()
        if v > 0.75 then
          return colors.green
        elseif v > 0.5 then
          return colors.orange
        else
          return colors.red
        end
      end
    },
    {
      field = "temperature",
      name = "Temperature",
      unit = "K",
      format = "%.2f"
    },
    {
      field = "heating",
      name = "Heating Rate",
      unit = "mB/T",
      format = function(value)
        local current = value.current:get()
        return string.format("%d (%.2f %%)", current, (current / value.max) * 100.0)
      end
    },
    {
      field = "coolant",
      name = "Coolant",
      unit = "B",
      format = function(value)
        local current = value.current:get() / 1000
        local max = value.max / 1000
        return string.format("%d (%.2f %%)", current, (current / max) * 100.0)
      end,
      color = function(value)
        local current = value.current:get()
        if current < value.max * 0.5 then
          return colors.red
        elseif current < value.max * 0.75 then
          return colors.orange
        else
          return colors.green
        end
      end
    },
    {
      field = "heatedCoolant",
      name = "Heated Coolant",
      unit = "mB",
      format = "%d",
      color = function(value)
        local v = value.current:get()
        if v > value.max / 2 then
          return colors.red
        elseif v > 0 then
          return colors.orange
        else
          return colors.green
        end
      end
    },
    Separator:new("horizontal"),
    {
      field = "damage",
      name = "Damage",
      unit = "%",
      format = "%.2f",
      color = function(value)
        local v = value.current:get()
        if v > 0 then
          return colors.red
        else
          return colors.green
        end
      end
    },
  })


  local powerGroup = self:createStatusGroup("Power Status", {})

  local row = Box:new("horizontal")
  row:setSpacing(1)
  row:addChild(reactorGroup, "start", true, true)
  row:addChild(Separator:new("horizontal", colors.gray), "start", false, false)
  row:addChild(powerGroup, "start", true, true)


  local box = Box:new("vertical")
  box:addChild(row, "start", true, true)
  box:addChild(status, "start", false, false)
  self:setChild(box)
end

function StatusWindow:createStatusGroup(title, fields)
  local vbox1 = Box:new("vertical")
  local vbox2 = Box:new("vertical")

  for _, field in ipairs(fields) do
    if Widget:isInstance(field) then
      vbox1:addChild(field)
      vbox2:addChild(Label:new(""))
    else
      Assert.assertIsTable(field)
      Assert.assertIsString(field.field)
      local row = Box:new("horizontal")

      local gradient = Label:new("  ")
      row:addChild(gradient, "start", false, false, 0)

      local name = Label:new(field.name or field.field)
      row:addChild(name, "start", true, true)

      local render
      if field.format then
        if type(field.format) == "function" then
          render = field.format
        elseif type(field.format) == "string" then
          render = function(value)
            return string.format(field.format, value.current:get())
          end
        else
          error(("Field formatter must be a string or a function; found '%s'"):format(type(field.format)))
        end
      else
        render = function(value)
          return tostring(value.current:get())
        end
      end

      local value = Label:new(render(self.model[field.field]))

      if field.color then
        local color = field.color(self.model[field.field])
        if color then
          name:setForeground(color)
          value:setForeground(color)
        end
      end

      row:addChild(value)

      table.insert(self.updaters, function(model)
        local v = model[field.field]

        if field.color then
          local new_color = field.color(v)
          if new_color then
            name:setForeground(new_color)
            value:setForeground(new_color)
          else
            name:setForeground(colors.white)
            value:setForeground(colors.white)
          end
        end

        local rate = v.current:getRate()
        if rate == nil then
          gradient:setText("  ")
        elseif rate > 0 then
          gradient:setText("+ ")
        elseif rate < 0 then
          gradient:setText("- ")
        else
          gradient:setText("  ")
        end

        value:setText(render(v))
      end)

      vbox1:addChild(row, "start", false, false)

      if field.unit then
        Assert.assertIsString(field.unit)
        vbox2:addChild(Label:new(field.unit))
      else
        vbox2:addChild(Label:new(""))
      end
    end
  end

  local group = Box:new("vertical")
  group:addChild(Label:new(title, nil, nil, "center"), "start", false, false)
  group:setChildPadding(1, 1)

  local data = Box:new("horizontal")
  data:addChild(vbox1, "start", true, true)
  data:addChild(Separator:new("vertical"), "start", false, false)
  data:addChild(vbox2, "start", false, false)

  group:addChild(data, "start", true, true)
  return group
end

function StatusWindow:updateStatusString()
  self.statusLeft:setText(("Reactor Status"))

  local time = os.time()
  local hour = math.floor(time)
  local minute = math.floor(60 * (time - hour))

  self.statusRight:setText(("%02d:%02d"):format(hour, minute))
end

function StatusWindow:update()
  self:updateStatusString()

  for _, updater in ipairs(self.updaters) do
    updater(self.model)
  end
end

return StatusWindow
