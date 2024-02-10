local class = require("lib.class")
local Packet = require("lib.protocols.bannet.packet")

local RechargePacket = class("RechargePacket", Packet)

function RechargePacket:init(srcName, destName, packetType)
  Packet.init(self, srcName, destName, "bannet.recharge", packetType)
end

return RechargePacket
