local Assert = require("lib.assert")
local Log = require("lib.log")
local FaxPacket = require("lib.protocols.bannet.fax.packet")
local class = require("lib.class")

local FaxAckPacket = class("FaxAckPacket", FaxPacket)

function FaxAckPacket:init(srcName, destName, id)
  FaxPacket.init(self, srcName, destName, "ack")
  Assert.assertIs(id, "string")
  self.id = id
end

function FaxAckPacket.static.parse(message)
  if message.type ~= "ack" then
    Log.error(("Invalid packet type for FaxAckPacket; expected 'ack' found '%s'"):format(message.type))
    return nil, "invalid packet type"
  end

  local payload = message.payload
  Assert.assertIs(payload, "table")
  Assert.assertIs(payload.id, "string")

  return FaxAckPacket:new(message.src, message.dest, payload.id)
end

function FaxAckPacket:renderPayload()
  return {
    id = self.id,
  }
end

return FaxAckPacket
