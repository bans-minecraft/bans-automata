local Assert = require("lib.assert")
local Class = require("lib.class")
local Log = require("lib.log")
local RechargePacket = require("lib.protocols.bannet.recharge.packet")

local RechargeSendPacket = Class("RechargeSendPacket", RechargePacket)

function RechargeSendPacket:init(srcName, destName, id)
  RechargePacket.init(self, srcName, destName, "send")
  Assert.assertIsString(id)
  self.id = id
end

function RechargeSendPacket.static.parse(message)
  if message.type ~= "send" then
    Log.error(("Invalid packet type for RechargeSendPacket; expected 'send' found '%s'"):format(message.type))
    error("Invalid packet type")
  end

  local payload = message.payload
  Assert.assertIsTable(payload)
  Assert.assertIsString(payload.id)

  return RechargeSendPacket:new(message.src, message.dest, payload.id)
end

function RechargeSendPacket:renderPayload()
  return {
    id = self.id
  }
end

function RechargeSendPacket:createReturn(id)
  local RechargeReturnPacket = require("lib.protocols.bannet.recharge.packet.return")
  return RechargeReturnPacket:new(self.dest, self.src, self.id, id)
end

return RechargeSendPacket
