local Class = require("lib.class")

local Model = Class("Model")

function Model:init(settings, reactor)
  self.settings = settings
  self.reactor = reactor
end

function Model:step()
end

return Model
