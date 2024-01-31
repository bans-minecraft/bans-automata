local class = require("lib.class")
local Packet = require("lib.protocols.bannet.packet")

local FaxPacket = class("FaxPacket", Packet)

function FaxPacket:init(srcName, destName, packetType)
  Packet.init(self, srcName, destName, "bannet.fax", packetType)
end

return FaxPacket
