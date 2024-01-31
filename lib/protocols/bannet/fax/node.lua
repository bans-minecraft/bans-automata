local class = require("lib.class")
local Node = require("lib.protocol.node")

local FaxNode = class("FaxNode", Node)

function FaxNode:init(address, timeout)
  Node.init(self, address, { "bannet.fax" }, timeout)
end

return FaxNode
