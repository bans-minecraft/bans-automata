local Class = require("lib.class")
local Log = require("lib.log")

local Settings = Class("Settings")
local REACTOR_SETTINGS_FILE = "reactor.settings"

function Settings:init()
  self.minReserve = 0.01 * 10 ^ 9
  self.maxReserve = 1.30 * 10 ^ 9
  self.startBurnRate = 2.5
  self.maxBurnRate = 10
  self.incBurnRate = 0.1
  self.minWater = 16 * 10 ^ 6
  self.scramWater = 15 * 10 ^ 6
end

function Settings:load()
  if not fs.exists(REACTOR_SETTINGS_FILE) then
    return false
  end

  Log.info(("Loading reactor settings from: %s"):format(REACTOR_SETTINGS_FILE))
  local file = fs.open(REACTOR_SETTINGS_FILE, "r")
  local text = file.readAll()
  local data = textutils.unserialize(text)
  file.close()

  self.minReserve = data.minReserve
  self.maxReserve = data.maxReserve
  self.startBurnRate = data.startBurnRate
  self.maxBurnRate = data.maxBurnRate
  self.incBurnRate = data.incBurnRate
  self.minWater = data.minWater
  self.scramWater = data.scramWater

  Log.info(("Min. Reserve: %d"):format(self.minReserve))
  Log.info(("Max. Reserve: %d"):format(self.maxReserve))
  Log.info(("Start Burn Rate: %d"):format(self.startBurnRate))
  Log.info(("Max. Burn Rate: %d"):format(self.maxBurnRate))
  Log.info(("Inc. Burn Rate: %d"):format(self.incBurnRate))
  Log.info(("Min. Water: %d"):format(self.minWater))
  Log.info(("Scram Water: %d"):format(self.scramWater))
end

function Settings:save()
  Log.info(("Writing reactor settings to: %s"):format(REACTOR_SETTINGS_FILE))
  local file = fs.open(REACTOR_SETTINGS_FILE, "w")

  file.write(textutils.serialize({
    minReserve = self.minReserve,
    maxReserve = self.maxReserve,
    startBurnRate = self.startBurnRate,
    maxBurnRate = self.maxBurnRate,
    incBurnRate = self.incBurnRate,
    minWater = self.minWater,
    scramWater = self.scramWater
  }))

  file.close()
end

return Settings
