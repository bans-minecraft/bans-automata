local class = require("lib.class")
local Packet = require("lib.protocols.bannet.packet")

local IcmpPacket = class("IcmpPacket", Packet)

function IcmpPacket:init(srcName, destName, packetType)
  Packet.init(self, srcName, destName, "bannet.icmp", packetType)
end

return IcmpPacket
