local Assert = require("lib.assert")
local Log = require("lib.log")
local FaxPacket = require("lib.protocols.bannet.fax.packet")
local Utils = require("lib.utils")
local class = require("lib.class")

local HelloFaxPacket = class("HelloFaxPacket", FaxPacket)

function HelloFaxPacket:init(srcName, destName, name, features)
  FaxPacket.init(self, srcName, destName, "hello")
  Assert.assertIs(name, "string")

  if features == nil then
    features = {}
  else
    Assert.assertIs(features, "table")
  end

  self.name = name
  self.features = features
end

function HelloFaxPacket.static.parse(message)
  if message.type ~= "hello" then
    Log.error(("Invalid packet type for HelloFaxPacket; expected 'hello', found '%s'"):format(message.type))
    return nil, "invalid packet type"
  end

  local payload = message.payload
  Assert.assertIs(payload, "table")
  Assert.assertIs(payload.name, "string")


  if payload.features ~= nil then
    Assert.assertIs(payload.features, "table")
  end

  return HelloFaxPacket:new(message.src, message.dest, payload.name, payload.features)
end

function HelloFaxPacket:renderPayload()
  return {
    name = self.name,
    features = Utils.clone(self.features)
  }
end

return HelloFaxPacket
