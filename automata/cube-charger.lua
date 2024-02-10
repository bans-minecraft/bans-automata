--
-- cube-charger.lua
--
-- A bot that recharges cubes.
--
-- This bot listens on Rednet for a message telling it the UUID of an item stack, just like a fax
-- receiver. However, when it has successfully materialized the stack it checks that the stack is
-- Mekanism energy cubes. If it is, it places each cube next to the cable, waits for it to charge
-- and, once all the cubes are charged, sends them back to the sender.

package.path = "/?.lua;/?/init.lua;" .. package.path
local Assert = require("lib.assert")
local Class = require("lib.class")
local Log = require("lib.log")
local Node = require("lib.protocols.node")
local RechargeSendPacket = require("lib.protocols.bannet.recharge.packet.send")

Log.setLogFile("cube-charger.lua")

local Charger = Class("Charger", Node)

function Charger:init()
  Node.init(self, "charge-station", { "bannet.recharge" }, 1)

  if not self:setupModem() then
    error("Failed to setup modem")
  end
end

function Charger:setupModem()
  local modems = { peripheral.find("modem") }
  if #modems == 0 then
    Log.error(("Failed to find modem peripheral"))
    return false
  end

  self.modem = modems[1]
  self.opened = false

  local name = peripheral.getName(self.modem)
  if not rednet.isOpen(name) then
    Log.info(("Opening rednet on modem '%s'"):format(name))
    rednet.open(name)
    self.opened = true
  else
    Log.info(("Rednet already open on modem '%s'"):format(name))
  end

  return true
end

function Charger:shutdownModem()
  if self.modem and self.opened then
    local name = peripheral.getName(self.modem)
    Log.info(("Closing rednet on modem '%s'"):format(name))
    rednet.close(name)
  end

  self.modem = nil
  self.opened = nil
end

function Charger:findDigitizer()
  self.digitizer = peripheral.find("digitizer")
  if not self.digitizer then
    Log.error("Failed to find 'digitizer' peripheral")
    return false
  end

  Log.info(("Found digitizer '%s'"):format(peripheral.getName(self.digitizer)))
  return true
end

function Charger:waitForDigitizerCharge(charge)
  local count = 0
  while count < 15 do
    local current = self.digitizer.getEnergy()
    if current >= charge then
      break
    end

    if count % 5 == 0 then
      Log.info(("Waiting for digitizer charge to reach %d FE (current: %d FE)"):format(charge, current))
    end

    sleep(1)
    count = count + 1
  end

  return self.digitizer.getEnergy() >= charge
end

function Charger:digitizeStack(slot)
  local info = turtle.getItemDetail(slot)
  if not info then
    Log.error(("No item stack to digitize in slot %d"):format(slot))
    return nil
  end

  Log.info(("Digitizing %dx %s in slot %d"):format(info.name, info.count, slot))

  turtle.select(slot)
  turtle.drop(info.count)

  local sim, err = self.digitizer.digitizer(info.count, true)
  if not sim then
    Log.error(("Failed to simulate digitization: %s"):format(err))
    return nil
  end

  if not self:waitForDigitizerCharge(sim.cost) then
    Log.error(("Digitizer never reached required energy level of %d FE"):format(sim.cost))
    return nil
  end

  local result
  result, err = self.digitizer.digitize(info.count, false)
  if not result then
    Log.error(("Failed to digitize item stack: %s"):format(err))
    return nil
  end

  return result.item
end

function Charger:materializeStack(slot, id)
  local info = turtle.getItemDetail(slot)
  if info ~= nil then
    Log.error(("Inventory slot %d already contains %dx %s"):format(slot, info.count, info.name))
    return nil
  end

  Log.info(("Materializing '%s' into slot %d"):format(id, slot))

  local sim, err = self.digitizer.materialize(id, nil, true)
  if not sim then
    Log.error(("Failed to simulate materialization of '%s': %s"):format(id, err))
    return nil
  end

  if not self:waitForDigitizerCharge(sim.cost) then
    Log.error(("Digitizer never reached required energy level of %d FE"):format(sim.cost))
    return nil
  end

  local result
  result, err = self.digitizer.materialize(id)
  if not result then
    Log.error(("Failed to materialize '%s': %s"):format(id, err))
    return nil
  end

  Log.info(("Materialized %dx %s"):format(result.materialized, sim.item.name))

  return result.materialized
end

function Charger:handleRecharge(packet)
  Log.info(("Received recharge request from '%s': %s"):format(packet.src, packet.id))
  local count = self:materializeStack(1, packet.id)
  if count == nil then
    self:sendReturn(packet.id, "failed", false)
  end

  -- Take the item(s) from the digitizer
  turtle.select(1)
  turtle.suck()

  -- Turn to the charge point
  turtle.turnLeft()

  -- TODO: Place each cube to charge
end

function Charger:handlePacket(packet)
  if RechargeSendPacket:isInstance(packet) then
    self:handleRecharge(packet)
  else
    Log.error(("Received unrecognized packet: %s"):format(packet))
  end
end
