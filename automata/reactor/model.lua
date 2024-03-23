local Class = require("lib.class")
local EMA = require("lib.data.ema")
local Peripherals = require("automata.reactor.peripherals")

local Model = Class("Model")

function Model:init(settings)
  self.settings = settings
  self.peripherals = Peripherals:new()

  self.burnRate = {
    current = EMA:new(0.1, self.peripherals.reactor.getBurnRate()),
    max = self.peripherals.reactor.getMaxBurnRate()
  }

  self.damage = {
    current = EMA:new(0.1, self.peripherals.reactor.getDamagePercent())
  }

  self.temperature = {
    current = EMA:new(0.1, self.peripherals.reactor.getTemperature()),
  }

  self.heating = {
    current = EMA:new(0.1, self.peripherals.reactor.getHeatingRate()),
    max = self.peripherals.reactor.getHeatCapacity()
  }

  self.boilEfficiency = {
    current = EMA:new(0.1, self.peripherals.reactor.getBoilEfficiency())
  }

  self.coolant = {
    current = EMA:new(0.1, self.peripherals.reactor.getCoolant().amount),
    max = self.peripherals.reactor.getCoolantCapacity(),
  }

  self.heatedCoolant = {
    current = EMA:new(0.1, self.peripherals.reactor.getHeatedCoolant().amount),
    max = self.peripherals.reactor.getHeatedCoolantCapacity()
  }

  self.fuel = {
    current = EMA:new(0.1, self.peripherals.reactor.getFuel().amount),
    max = self.peripherals.reactor.getFuelCapacity(),
  }

  self.fuelWaste = {
    current = EMA:new(0.1, self.peripherals.reactor.getWaste().amount),
    max = self.peripherals.reactor.getWasteCapacity()
  }

  self.coolantReturn = {
    current = EMA:new(0.1, self.peripherals.coolantReturn.getBuffer().amount),
    max = self.peripherals.coolantReturn.getCapacity()
  }
end

function Model:updateReactor()
  self.burnRate.current:push(self.peripherals.reactor.getBurnRate())
  self.damage.current:push(self.peripherals.reactor.getDamagePercent())
  self.temperature.current:push(self.peripherals.reactor.getTemperature())
  self.heating.current:push(self.peripherals.reactor.getHeatingRate())
  self.boilEfficiency.current:push(self.peripherals.reactor.getBoilEfficiency())
  self.coolant.current:push(self.peripherals.reactor.getCoolant().amount)
  self.heatedCoolant.current:push(self.peripherals.reactor.getHeatedCoolant().amount)
  self.fuel.current:push(self.peripherals.reactor.getFuel().amount)
  self.fuelWaste.current:push(self.peripherals.reactor.getWaste().amount)
end

function Model:updateCoolantReturn()
  self.coolantReturn.current:push(self.peripherals.coolantReturn.getBuffer().amount)
end

function Model:update()
  self:updateReactor()
  self:updateCoolantReturn()
end

return Model
