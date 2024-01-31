local Assert = require("lib.assert")
local Log = require("lib.log")
local class = require("lib.class")

local Packet = class("Packet")

function Packet:init(srcName, destName, protocol, packetType)
  Assert.assertIs(srcName, "string")
  Assert.assertIs(protocol, "string")
  Assert.assertIs(packetType, "string")

  if destName ~= nil then
    Assert.assertIs(destName, "string")
  end

  self.src = srcName
  self.dest = destName
  self.protocol = protocol
  self.type = packetType
end

function Packet:isBroadcast()
  return self.dest == nil
end

function Packet:isUnicast()
  return self.dest ~= nil
end

function Packet.static.parse(message)
  Assert.assertIs(message, "table")
  Assert.assertIs(message.protocol, "string")
  Assert.assertIs(message.type, "string")
  Assert.assertIs(message.src, "string")

  local moduleName = ("lib.protocols.%s.packet.%s"):format(message.protocol, message.type)
  local ok, module, _ = pcall(require, moduleName)
  if not ok then
    Log.error(("Failed to load packet module '%s'"):format(moduleName))
    return nil, ("Uknown protocol and packet type '%s' : '%s'"):format(message.protocol, message.type)
  end

  return module.parse(message)
end

function Packet:renderPayload()
  return {}
end

function Packet:render()
  return {
    src = self.src,
    dest = self.dest,
    protocol = self.protocol,
    type = self.type,
    payload = self:renderPayload()
  }
end

return Packet
