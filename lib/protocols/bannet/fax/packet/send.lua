local Assert = require("lib.assert")
local Log = require("lib.log")
local FaxPacket = require("lib.protocols.bannet.fax.packet")
local Utils = require("lib.utils")
local class = require("lib.class")

local FaxSendPacket = class("FaxSendPacket", FaxPacket)

function FaxSendPacket:init(srcName, destName, id, subject, replay, content)
  FaxPacket.init(self, srcName, destName, "send")

  Assert.assertIs(id, "string")
  Assert.assertIs(subject, "string")
  Assert.assertIs(content, "table")

  if replay ~= nil then
    Assert.assertIs(replay, "string")
  end

  self.id = id
  self.subject = subject
  self.replay = replay
  self.content = content
end

function FaxSendPacket.static.parse(message)
  if message.type ~= "fax" then
    Log.error(("Invalid packet type for FaxSendPacket; expected 'fax' found '%s'"):format(message.type))
    return nil, "invalid packet type"
  end

  local payload = message.payload
  Assert.assertIs(payload, "table")
  Assert.assertIs(payload.id, "string")
  Assert.assertIs(payload.subject, "string")
  Assert.assertIs(payload.content, "table")

  if payload.replay ~= nil then
    Assert.assertis(payload.replay, "string")
  end

  return FaxSendPacket:new(message.src, message.dest, payload.id, payload.subject, payload.replay, payload.content)
end

function FaxSendPacket:renderPayload()
  return {
    id = self.id,
    subject = self.subject,
    replay = self.replay,
    content = Utils.clone(self.content)
  }
end

return FaxSendPacket
