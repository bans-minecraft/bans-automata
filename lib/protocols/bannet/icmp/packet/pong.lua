local Assert = require("lib.assert")
local Log = require("lib.log")
local Packet = require("lib.protocols.bannet.packet")
local class = require("lib.class")

local PongPacket = class("PongPacket", Packet)

function PongPacket:init(srcName, destName, id)
  Packet.init(self, srcName, destName, "pong")
  Assert.assertIs(id, "string")

  self.id = id
end

function PongPacket.static.parse(message)
  if message.type ~= "pong" then
    Log.error(("Invalid packet type for PongPacket; expected 'pong', found '%s'"):format(message.type))
    return nil, "invalid packet type"
  end

  local payload = message.payload
  Assert.assertIs(payload, "table")
  Assert.assertIs(payload.id, "string")

  return PongPacket:new(message.src, message.dest, payload.id)
end

function PongPacket:renderPayload()
  return {
    id = self.id,
  }
end

return PongPacket
