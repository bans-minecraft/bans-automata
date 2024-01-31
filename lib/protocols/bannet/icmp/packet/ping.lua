local Assert = require("lib.assert")
local Log = require("lib.log")
local IcmpPacket = require("lib.protocols.bannet.icmp.packet")
local class = require("lib.class")

local PingPacket = class("PingPacket", IcmpPacket)

function PingPacket:init(srcName, destName, id)
  IcmpPacket.init(self, srcName, destName, "ping")
  Assert.assertIs(id, "string")

  self.id = id
end

function PingPacket.static.parse(message)
  if message.type ~= "ping" then
    Log.error(("Invalid packet type for PingPacket; expected 'ping', found '%s'"):format(message.type))
    return nil, "invalid packet type"
  end

  local payload = message.payload
  Assert.assertIs(payload, "table")
  Assert.assertIs(payload.id, "string")

  return PingPacket:new(message.src, message.dest, payload.id)
end

function PingPacket:renderPayload()
  return {
    id = self.id,
  }
end

return PingPacket
