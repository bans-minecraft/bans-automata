local Assert = require("lib.assert")
local Log = require("lib.log")
local Utils = require("lib.utils")
local FaxNode = require("lib.protocols.bannet.fax.node")
local FaxSendPacket = require("lib.protocols.bannet.fax.packet.send")
local FaxAckPacket = require("lib.protocols.bannet.fax.packet.ack")
local class = require("lib.class")

Log.setLogFile("fax.log")

local Fax = class("Fax", FaxNode)

function Fax:init(options)
  FaxNode.init(self, options.address or FaxNode.getDefaultAddress("fax"), 1)

  self.options = options

  if not self:setupModem() then
    error("Failed to create fax")
  end

  if not self:findDigitizer() then
    error("Failed to create fax")
  end

  if not self:findInventory() then
    error("Failed to create fax")
  end
end

function Fax:setupModem()
  local modems = { peripheral.find("modem") }
  if #modems == 0 then
    Log.error(("Failed to find modem peripheral"))
    return false
  end

  self.modem = modems[1]
  self.opened = false
  if not rednet.isOpen(self.modem) then
    Log.info(("Opening rednet on modem '%s'"):format(peripheral.getName(self.modem)))
    rednet.open(self.modem)
  else
    Log.info(("Rednet already open on modem '%s'"):format(peripheral.getName(self.modem)))
  end

  return true
end

function Fax:shutdown()
  self:shutdownModem()
end

function Fax:shutdownModem()
  if self.modem and self.opened then
    Log.info(("Closing rednet on modem '%s'"):format(peripheral.getName(self.modem)))
    rednet.close(self.modem)
  end

  self.modem = nil
  self.opened = nil
end

function Fax:findDigitizer()
  if type(self.options.digitizer) == "string" then
    self.digitizer = peripheral.wrap(self.options.digitizer)
    if not self.digitizer then
      Log.error(("Failed to find digitizer peripheral with name '%s'"):format(self.options.digitizer))
      return false
    end

    local typeName = peripheral.getName(self.digitizer)
    if typeName ~= "digitizer" and typeName ~= "digitizier" then
      Log.error(("Peripheral '%s' has type '%s'; expected 'digitizer'"):format(self.options.digitizer, typeName))
      return false
    end
  else
    self.digitizer = peripheral.find("digitizer")
    if not self.digitizer then
      self.digitizer = peripheral.find("digitizier")
      if not self.digitizer then
        Log.error("Failed to find 'digitizer' peripheral")
        return false
      end
    end
  end

  Log.info(("Found digitizer '%s'"):format(peripheral.getName(self.digitizer)))
  return true
end

function Fax:waitForDigitizerCharge(charge)
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

function Fax:findInventory()
  if type(self.options.inventory) == "string" then
    self.inventory = peripheral.wrap(self.options.inventory)
    if not self.inventory then
      Log.error(("Failed to find inventory peripheral with name '%s'"):format(self.options.inventory))
      return false
    end

    local slots = self.inventory.size()
    Log.info(("Using attached inventory '%s' with %d slot(s)"):format(peripheral.getName(self.inventory), slots))
  else
    Assert.assertIs(self.digitizer, "table")
    self.inventory = self.digitizer
    Log.info(("Using digitizer inventory with %d slot(s)"):format(self.inventory.size()))
  end
end

---------------------------------------------------------------------------------------------------

local FaxSender = class("FaxSender", Fax)

function FaxSender:init(options)
  Fax.init(self, options)
  self.digitized = {}
  self.stats = {
    stacks = 0,
    items = 0,
    cost = 0
  }
end

function FaxSender.static.parseOptions(args)
  local invalid = false
  local options = {}

  for option, value in pairs(args) do
    if option == "as" then
      options.address = value
    elseif option == "to" then
      options.recipient = value
    elseif option == "with" then
      options.digitizer = value
    elseif option == "from" then
      options.inventory = value
    else
      Log.error(("Unrecognized argument '%s %s' for fax sender"):format(option, value))
      invalid = true
    end
  end

  if invalid then
    return nil, "invalid arguments"
  else
    return options
  end
end

function FaxSender.static.validateOptions(options)
  if options.receipient == nil then
    Log.error("Expected recipient with 'to <recipient>' argument")
    return false
  end

  return true
end

function FaxSender:digitize(slot, count)
  -- If the source is not the digitizer, then make sure that the digitizer is empty and then move
  -- the items from the source into the digitizer.
  if self.inventory ~= self.digitizer then
    local info = self.digitizer.getItemDetail(1)
    if info then
      Log.error(("Digitizer '%s' already has %dx %s in it's inventory"):format(peripheral.getName(self.digitizer),
        info.count, info.name))
      return false
    end

    self.inventory.pushItems(peripheral.getName(self.digitizer), slot, count, 1)
  end

  -- Run a simulation of the digitization so we know how much it'll cost.
  local sim, err = self.digitizer.digitize(count, true)
  if not sim then
    Log.error(("Failed to simulate digitization: %s"):format(err))
    return false
  end

  -- Make sure that the digitizer has enough energy to perform the digitization
  if not self:waitForDigitizerCharge(sim.cost) then
    Log.error(("Digitizer never reached required energy level of %d FE"):format(sim.cost))
    return false
  end

  -- Perform the actual digitization
  local result
  result, err = self.digitizer.digitize(count, false)
  if not result then
    Log.error(("Failed to digitize item stack: %s"):format(err))
    return false
  end

  self.stats.stacks = self.stats.stacks + 1
  self.stats.items = self.stats.items + result.item.count
  self.stats.cost = self.stats.cost + result.item.cost
  table.insert(self.digitized, result.item)
  return true
end

function FaxSender:digitizeInventory()
  local slots = self.inventory.size()
  Log.info(("Digitizing inventory with %d slot(s)"):format(slots))

  for slot, info in pairs(self.inventory.list()) do
    if info and info.count > 0 then
      Log.info(("Digitizing %dx %s in slot %d"):format(info.count, info.name, slot))
      if not self:digitize(slot, info.count) then
        return false
      end
    end
  end

  Log.info(("Digitized %d items(s) over %d stack(s) at a cost of %d FE"):format(self.stats.items, self.stats.stacks,
    self.stats.cost))
  return true
end

function FaxSender:waitForAck(id)
  Log.info(("Waiting for acknowledgement of message '%s'"):format(id))

  local count = 0
  while count < 30 do
    sleep(1)

    if self.ack then
      break
    end

    count = count + 1
  end

  if self.ack then
    if self.ack.id == id then
      Log.info(("Received acknowledgement of message '%s' from '%s'"):format(id, self.ack.src))
      return true
    else
      Log.error(("Received acknowledgement from '%s' for message '%s'; expected message ID '%s'"):format(self.ack.src,
        self.ack.id, id))
    end
  else
    Log.error(("Never received acknowledgement for message '%s' from '%s'"):format(id, self.options.recipient))
  end

  return false
end

function FaxSender:sendDigitizedItems()
  local id = Utils.generateId(16)

  local content = {
    {
      type = "digitized",
      uuids = {}
    }
  }

  for _, item in ipairs(self.digitized) do
    table.insert(content.uuids, item.id)
  end

  local subject = ("Fax of %d item stack(s)"):format(#self.digitized)
  local packet = FaxSendPacket:new(self.address, self.options.recipient, id, subject, nil, content)

  Log.info(("Sending fax packet '%s' from '%s' to '%s' ..."):format(id, packet.src, packet.dest))
  local ok, err = self:send(packet)
  if not ok then
    Log.error(("Failed to send packet: %s"):format(err))
    return false
  end

  return self:waitForAck(id)
end

function FaxSender:handlePacket(packet)
  if FaxAckPacket:isInstance(packet) then
    self.ack = packet
  else
    Log.error(("Received unrecognized packet: %s"):format(packet))
  end
end

function FaxSender:cli()
  if not self:digitizeInventory() then
    return
  end

  if not self:sendDigitizedItems() then
    return
  end
end

---------------------------------------------------------------------------------------------------

local FaxReceiver = class("FaxReceiver", Fax)

function FaxReceiver:init(options)
  Fax.init(self, options)
end

function FaxReceiver.static.parseOptions(args)
  local invalid = false
  local options = {}

  for option, value in pairs(args) do
    if option == "as" then
      options.address = value
    elseif option == "into" then
      options.inventory = value
    elseif option == "with" then
      options.digitizer = value
    else
      Log.error(("Unrecognized argument '%s %s' for fax receiver"):format(option, value))
      invalid = true
    end
  end

  if invalid then
    return nil, "invalid arguments"
  else
    return options
  end
end

function FaxReceiver.static.validateOptions(options)
  return true
end

function FaxReceiver:materializeStack(uuid)
  local sim, err = self.digitizer.materialize(uuid, nil, true)
  if not sim then
    Log.error(("Failed to simulate materialization of '%s': %s"):format(uuid, err))
    return false
  end

  -- Make sure that the digitizer has enough energy to perform the materialization
  if not self:waitForDigitizerCharge(sim.cost) then
    Log.error(("Digitizer never reached required energy level of %d FE"):format(sim.cost))
    return false
  end

  local result
  result, err = self.digitizer.materialize(uuid)
  if not result then
    Log.error(("Failed to materialize '%s': %s"):format(uuid, err))
    return false
  end

  return true
end

function FaxReceiver:moveToInventory()
  self.inventory.pullItems(peripheral.getName(self.digitizer), 1)
end

function FaxReceiver:materalizeStacks(uuids)
  Log.info(("Materializing %d stack(s) of items"):format(#uuids))
  if self.inventory == self.digitizer then
    if #uuids > 0 then
      Log.warn(("Unable to digitize %d items without separate inventory"):format(#uuids))
    end

    self:materializeStack(uuids[1])

    for index, uuid in ipairs(uuids) do
      if index > 1 then
        Log.warn(("Unmaterialized UUID: %s"):format(uuid))
      end
    end
  else
    local info = self.digitizer.getItemDetail(1)
    if info and info.count > 0 then
      Log.warn(("Digitizer contains %dx %s; moving to inventory before materializing"):format(info.count, info.name))
      self:moveToInventory()
    end

    for _, uuid in ipairs(uuids) do
      if self:materializeStack(uuid) then
        self:moveToInventory()
      end
    end
  end
end

function FaxReceiver:handleFax(packet)
  Log.info(("Received fax from '%s': %s"):format(packet.src, packet.subject))
  for index, content in ipairs(packet.content) do
    if content.type == "digitized" then
      local uuids = content.digitized or {}
      if #uuids > 0 then
        self:materializeStacks(uuids)
      else
        Log.warn(("Ignoring digitized fax content at %d with no items"):format(index))
      end
    else
      Log.warn(("Ignoring unrecognized fax content '%s' at %d"):format(content.type, index))
    end
  end
end

function FaxReceiver:handlePacket(packet)
  if FaxSendPacket:isInstance(packet) then
    self:handleFax(packet)
  else
    Log.error(("Received unrecognized packet: %s"):format(packet))
  end
end

function FaxReceiver:cli()
  Log.info("Fax running in receive mode; press 'q' to quit")
  repeat
    local _, key = os.pullEvent("key")
  until key == keys.q
end

---------------------------------------------------------------------------------------------------

local function printHelp()
  print("usage: fax receive <option> ...")
  print("       fax send <option> ...")
  print("")
  print("Options for receiving (can be in any order):")
  print("")
  print("    as <address>           Specify receiver address (optional)")
  print("    into <inventory>       Specify recipient peripheral (optional)")
  print("    with <name>            Specify digitizer peripheral (optional)")
  print("")
  print("Options for sending (can be in any order):")
  print("")
  print("    as <address>           Specify sender address (optional)")
  print("    to <recipient>         Specify recipient address (required)")
  print("    with <name>            Specify digitizer peripheral (optional)")
  print("    from <inventory>       Specify the source peripheral (optional)")
  print("")
  print("If the sender address is not specified with 'sender ...' it is computed")
  print("as the computer label or computer ID suffixed with '.fax'. For example,")
  print("a computer label like 'label.fax' or the ID like '123.fax'.")
  print("")
  print("If the digitizer is not specified using 'with ...', this application will")
  print("search for a suitable digitizer peripheral to use.")
  print("")
  print("If the source peripheral is not specified with 'source ...', this application")
  print("will digitize and transmit the contents of the digitizer's inventory. If an")
  print("inventory is selected, all contents will be transmitted after digitizing.")
end

local function pairOptions(args)
  local name
  local pairs = {}

  for _, arg in ipairs(args) do
    if name == nil then
      name = arg
    else
      if pairs[name] ~= nil then
        Log.warn(("Duplicate option '%s' (new value '%s', old value '%s')"):format(name, pairs[name], arg))
      end

      pairs[name] = arg
      name = nil
    end
  end

  if name ~= nil then
    error(("Found option '%s' that has no argument"):format(name))
  end

  return pairs
end

local function parseOptions(args)
  if #args == 0 then
    error("No arguments found; try running 'fax help'")
  end

  local mode
  if args[1] == "help" then
    printHelp()
    return nil
  elseif args[1] == "send" or args[1] == "receive" then
    mode = args[1]
    table.remove(args, 1)
  else
    error(("Uknnown mode '%s'; expected 'help', 'send' or 'receive'"):format(args[1]))
  end

  args = pairOptions(args)
  local fax
  if mode == "send" then
    local options = FaxSender.parseOptions(pairOptions(args))
    if not FaxSender.validateOptions(options) then
      return nil
    end

    fax = FaxSender:new(options)
  elseif mode == "receive" then
    local options = FaxReceiver.parseOptions(pairOptions(args))
    if not FaxReceiver.validateOptions(options) then
      return nil
    end

    fax = FaxReceiver:new(options)
  end

  return fax
end

local function main(args)
  local fax = parseOptions(args)
  if fax == nil then
    return
  end

  parallel.waitForAny(fax.run, fax.cli)
end

main({ ... })
