local Assert = require("lib.assert")
local Class = require("lib.class")
local Log = require("lib.log")
local RechargePacket = require("lib.protocols.bannet.recharge.packet")

local RechargeReturnPacket = Class("RechargeReturnPacket", RechargePacket)

function RechargeReturnPacket:init(srcName, destName, chargeId, status, returnId)
  RechargePacket.init(self, srcName, destName, "return")
  Assert.assertIsString(chargeId)
  Assert.assertIsString(status)
  self.chargeId = chargeId
  self.status = status
  self.returnId = returnId
end

function RechargeReturnPacket.static.parse(message)
  if message.type ~= "return" then
    Log.error(("Invalid packet type for RechargeReturnPacket; expected 'return' found '%s'"):format(message.type))
    error("Invalid packet type")
  end

  local payload = message.payload
  Assert.assertIsTable(payload)
  Assert.assertIsString(payload.chargeId)
  Assert.assertIsString(payload.status)

  return RechargeReturnPacket:new(message.src, message.dest, payload.chargeId, payload.status, payload.returnId)
end

function RechargeReturnPacket:renderPayload()
  return {
    chargeId = self.chargeId,
    status = self.status,
    returnId = self.returnId
  }
end

return RechargeReturnPacket
