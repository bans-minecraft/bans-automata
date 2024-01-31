local Assert = require("lib.assert")
local Log = require("lib.log")
local class = require("lib.class")
local Packet = require("lib.protocols.packet")
local IcmpPongPacket = require("lib.protocols.bannet.icmp.packet.pong")

local Node = class("Node")

Node.static.State = {
  Idle = 0,
  Running = 1,
  Stopping = 2
}

function Node.static.getDefaultAddress(protocol)
  Assert.assertIs(protocol, "string")
  local label = os.getComputerLabel()
  if label then
    return ("%s.%s"):format(label, protocol)
  else
    return ("%d.%s"):format(os.getComputerID(), protocol)
  end
end

function Node:init(address, protocols, timeout)
  Assert.assertIs(address, "string")

  if protocols ~= nil then
    Assert.assertIs(protocols, "table")
  end

  if timeout ~= nil then
    Assert.assertIs(timeout, "number")
  end

  self.address = address
  self.state = Node.State.Idle
  self.protocols = protocols or {}
  self.timeout = timeout
end

function Node:addProtocol(protocol)
  Assert.assertIs(protocol, "string")
  table.insert(self.protocols, protocol)
end

function Node:stop()
  Assert.assert(self.state == Node.State.Running, ("Expected running state; found %i"):format(self.state))
  self.state = Node.State.Stopping
end

function Node:run()
  -- Make sure that the node is idle before we try and run
  Assert.assert(self.state == Node.State.Idle, ("expected idle state; found %i"):format(self.state))

  -- Ensure that rednet is open: we should have at least one modem peripheral active.
  if not rednet.isOpen() then
    error("rednet is not open")
  end

  -- Change the state of the node to "Running".
  self.state = Node.State.Running

  -- For all the registered protocols, tell rednet that we now host that protocol at our address.
  for _, protocol in ipairs(self.protocols) do
    rednet.host(protocol, self.address)
  end

  -- Register for the ICMP protocol with rednet too. All nodes will respond to the ICMP by default.
  rednet.host("bannet.icmp", self.address)

  local packet, ok, err
  while self.state == Node.State.Running do
    -- Receive a packet from rednet. We do this in a separate method for our sins.
    packet, _, _, err = self:receivePacket(self.timeout)

    -- If we got a packet, route it to one of the two protocol handlers.
    if packet then
      if packet.protocol == "bannet.icmp" then
        self:handleIcmp(packet)
      else
        ok, _, err = pcall(self.handlePacket, self, packet)
        if not ok then
          Log.error(("Failed to process packet: %s"):format(err))
        end
      end
    else
      Log.error(("host '%s' failed to receive packet: %s"):format(self.address, err))
    end
  end

  -- Unregister from the ICMP protocol
  rednet.unhost("bannet.icmp")

  -- For all the registered protocols, tell rednet that we no longer host them.
  for _, protocol in ipairs(self.protocols) do
    rednet.unhost(protocol)
  end

  -- As we've exited our listening loop, we want to make sure that we are in the correct state.
  Assert.assert(self.state == Node.State.Stopping, ("expected stopping state; found %i"):format(self.state))
  self.state = Node.State.Idle
end

function Node:recievePacket(timeout)
  local sender, message, protocol, result, packet, ok, err

  -- Receive a rednet packet.
  sender, message, protocol = rednet.receive(nil, timeout)
  if not sender then
    -- If we did not get a packet, then either there was a problem or we timed out.
    return nil, nil, nil, "no message received or timed out"
  end

  -- We should have received a table. That table should have a `protocol` field. We'll make sure
  -- that they match the expectation.
  if type(message) ~= "table" then
    return nil, protocol, sender, "message was not a table"
  end

  if type(message.protocol) ~= "string" then
    return nil, protocol, sender, "message had no string 'protocol' field"
  end

  if message.protocol ~= protocol then
    Log.error(("Mismatched packet protocol '%s' and rednet protocol '%s' in packet from '%s'"):format(message.protocol,
      protocol, message.sender))
    return nil, protocol, sender, "message was sent on incorrect protocol"
  end

  -- Try and parse the packet. Our generic `Packet` type will use module search to find correct
  -- packet for given protocol and payload type.
  ok, result, err = pcall(Packet.parse, message)
  if not ok then
    return nil, protocol, sender, err
  end

  packet, err = table.unpack(result)
  return packet, protocol, sender, err
end

function Node:handleIcmp(packet)
  Assert.assert(packet.protocol == "bannet.icmp")

  if packet.type == "ping" then
    self:send(IcmpPongPacket:new(self.name, packet.src, packet.id))
  elseif packet.type == "pong" then
    -- handle it
  end
end

function Node:send(packet)
  Assert.assertInstance(packet, Packet)

  if not packet:isUnicast() then
    return false, "packet is not unicast"
  end

  -- Look up the destination computer ID from rednet for the given protocol and destination address.
  local dest = rednet.lookup(packet.protocol, packet.dest)
  if not dest then
    Log.error(("Failed to find '%s' host with address '%s'"):format(packet.protocol, packet.dest))
    return false, "failed to find host"
  end

  if not rednet.send(dest, packet:render(), packet.protocol) then
    Log.error(("Failed to send packet to '%s' on protocol '%s': rednet error"):format(packet.dest, packet.protocol))
    return false, "rednet error"
  end

  return true
end

function Node:broadcast(packet)
  Assert.assertInstance(packet, Packet)

  if not packet:isBroadcast() then
    return false, "packet is not broadcast"
  end

  rednet.broadcast(packet:render(), packet.protocol)
  return true
end

function Node:handlePacket(packet)
  Log.error(("Node:handlePacket() not implemented"))
end

return Node
