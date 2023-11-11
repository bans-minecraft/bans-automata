-- [2023-11-10] Makes the white dye

package.path = "/?.lua;/?/init.lua;" .. package.path
local Log = require("lib.log")
Log.setLogFile("concrete.log")

local Location = {
	Home = "Home",
	InsolatorInput = "InsolatorInput",
	InsolatorOutput = "InsolatorOutput",
	SandStorage = "SandStorage",
}

local Maker = {}
Maker.__index = Maker
Maker.__name = "Maker"

function Maker:create()
	local maker = {}
	setmetatable(maker, Maker)

	maker.location = Location.Home

	return maker
end

function Maker:turnLeft()
	turtle.turnLeft()
	return self
end

function Maker:turnRight()
	turtle.turnRight()
	return self
end

function Maker:turn180()
	turtle.turnLeft()
	turtle.turnLeft()
	return self
end

function Maker:forward(n)
	if type(n) ~= "number" then
		n = 1
	end

	if n == 0 then
		return self
	end

	while n > 0 do
		local ok, err = turtle.forward()
		if not ok then
			Log.error("Failed to move forward:", err)
			error("Failed to move forward: " .. err)
		end

		n = n - 1
	end

	return self
end

function Maker:backward(n)
	if type(n) ~= "number" then
		n = 1
	end

	if n == 0 then
		return self
	end

	while n > 0 do
		local ok, err = turtle.back()
		if not ok then
			Log.error("Failed to move backward:", err)
			error("Failed to move backward: " .. err)
		end

		n = n - 1
	end

	return self
end

function Maker:setLocation(location)
	Log.assertIs(location, "string")
	self.location = location
	return self
end

function Maker:goHome()
	if self.location == Location.Home then
		return self
	elseif self.location == Location.InsolatorInput then
		return self:turnRight():forward():turnLeft():forward():turnLeft():backward():setLocation(Location.Home)
	elseif self.location == Location.InsolatorOutput then
		return self:turnLeft():forward():turnRight():forward():turnRight():backward():setLocation(Location.Home)
	elseif self.location == Location.SandStorage then
		return self:backward():turnRight():backward():setLocation(Location.Home)
	else
		Log.error("Unrecognized location:", self.location)
		return nil, "Unrecognized location"
	end
end

function Maker:gotoInsolatorInput()
	if self.location == Location.Home then
		return self:forward()
			:turnLeft()
			:forward()
			:turnRight()
			:forward()
			:turnRight()
			:setLocation(Location.InsolatorInput)
	elseif self.location == Location.InsolatorInput then
		return self
	elseif self.location == Location.InsolatorOutput then
		return self:turnLeft()
			:forward()
			:turnRight()
			:forward(2)
			:turnRight()
			:forward()
			:turnRight()
			:setLocation(Location.InsolatorInput)
	elseif self.location == Location.SandStorage then
		return self:turnRight():forward():turnRight():setLocation(Location.InsolatorInput)
	else
		Log.error("Unrecognized location:", self.location)
		return nil, "Unrecognized location"
	end
end

function Maker:gotoInsolatorOutput()
	if self.location == Location.Home then
		return self:forward()
			:turnRight()
			:forward()
			:turnLeft()
			:forward()
			:turnLeft()
			:setLocation(Location.InsolatorOutput)
	elseif self.location == Location.InsolatorInput then
		return self:turnRight()
			:forward()
			:turnLeft()
			:forward(2)
			:turnLeft()
			:forward()
			:turnLeft()
			:setLocation(Location.InsolatorOutput)
	elseif self.location == Location.InsolatorOutput then
		return self
	elseif self.location == Location.SandStorage then
		return self:backward(2):turnRight():forward():turnLeft():setLocation(Location.InsolatorOutput)
	else
		Log.error("Unrecognized location:", self.location)
		return nil, "Unrecognized location"
	end
end

function Maker:gotoSandStorage()
	if self.location == Location.Home then
		return self:forward():turnLeft():forward():setLocation(Location.SandStorage)
	elseif self.location == Location.InsolatorOutput then
		return self:turnLeft():forward():turnRight():forward(2):setLocation(Location.SandStorage)
	elseif self.location == Location.InsolatorInput then
		return self:turnRight():forward():turnRight():setLocation(Location.SandStorage)
	else
		Log.error("Unrecognized location:", self.location)
		return nil, "Unrecognized location"
	end
end

function Maker:getInsolatorOutput()
	local has_block, data = turtle.inspect()
	if not has_block then
		Log.error("No block infront of turtle (expected Insolator)")
		return nil, "Missing Insolator"
	end

	if data.state.active then
		Log.info("Waiting for Insolator to finish")

		while data.state.active do
			sleep(1)

			has_block, data = turtle.inspect()
			if not has_block then
				Log.error("No block infront of turtle (expected Insolator)")
				return nil, "Missing Insolator"
			end
		end

		Log.info("Seems the Insolator has finished")
	else
		Log.info("Seems the Insolator is not running (or has finished)")
	end

	Log.info("Extracting results of Insolator")
	turtle.select(1)
	turtle.suck(64)

	local info = turtle.getItemDetail()
	if not info then
		Log.error("Failed to receive anything from Insolator")
		return nil, "Nothing received from Insolator"
	end

	Log.info(("Received %dx %s from Insolator"):format(info.count, info.name))

	if info.name ~= "minecraft:lily_of_the_valley" then
		Log.error("Did not receive Lily of the Valley from Insolator; received", info)
		return nil, "Did not receive Lily of the Valley from Involator"
	end

	return self
end

function Maker:checkSlot(slot, expected)
	local info = turtle.getItemDetail(slot)
	if not info then
		Log.error(("Failed to find anything in inventory slot %d (expected '%s')"):format(slot, expected))
		return nil, "Did not find anything in slot " .. slot
	end

	Log.info(("Found %dx %s in slot %d"):format(info.count, info.name, slot))
	if info.name ~= expected then
		Log.error(("Found '%s' in slot %d; expected '%s'"):format(info.name, slot, expected))
		return nil, "Found " .. info.name .. " in slot " .. slot .. ", expected " .. expected
	end

	return self
end

function Maker:loop()
	local ok, err

	while true do
		-- We need to get a Lily from the Insolator
		ok, err = self:gotoInsolatorOutput()
		if not ok then
			error("Failed to move to Insolator: " .. err)
		end

		ok, err = self:getInsolatorOutput()
		if not ok then
			error("Failed to get Insolator output: " .. err)
		end

		-- Go home so we can interact with our storage
		ok, err = self:goHome()
		if not ok then
			error("Failed to go home: " .. err)
		end

		-- Move one of the Lily of the Valley to our second slot then drop it into our storage.
		turtle.transferTo(2, 1)
		turtle.select(2)
		turtle.turnLeft()
		turtle.drop()
		turtle.turnRight()
		turtle.select(1)

		-- Turn the rest of Lily that we've received into dye
		ok, err = turtle.craft()
		if not ok then
			Log.error("Failed to craft white dye:", err)
			error("Failed to craft white dye: " .. err)
		end

		-- Make sure that what we've crafted is white dye
		ok, err = self:checkSlot(1, "minecraft:white_dye")
		if not ok then
			error("Did not end up crafting white dye: " .. err)
		end

		-- Extract the Lily of the Valley from our storage into our second slot. Then store our white dye.
		turtle.turnLeft()
		turtle.select(2)
		turtle.suck()
		ok, err = self:checkSlot(2, "minecraft:lily_of_the_valley")
		if not ok then
			error("Failed to extract Lily of the Valley from storage")
		end

		turtle.select(1)
		turtle.drop()
		turtle.turnRight()

		-- Now go to the Insolator input and deposit the Lily of the Valley
		ok, err = self:gotoInsolatorInput()
		if not ok then
			error("Failed to go to Insolator input: " .. err)
		end

		-- Select the second slot (which contains our Lily of the Valley) and push it out to the Insolator
		turtle.select(2)
		turtle.drop()

		-- Now go back home
		ok, err = self:goHome()
		if not ok then
			error("Failed to go home: " .. err)
		end

		-- Turn to our storage and pull our the white dye into our first slot
		turtle.turnLeft()
		turtle.select(1)
		turtle.suck()
		turtle.turnRight()
		ok, err = self:checkSlot(1, "minecraft:white_dye")
		if not ok then
			error("Failed to extract white dye from storage")
		end

		-- Go to the sand storage
		ok, err = self:gotoSandStorage()
		if not ok then
			error("Failed to go to sand storage: " .. err)
		end

		-- Extract sand into our slots
		local SAND = { 2, 3, 5, 6 }
		for _, slot in ipairs(SAND) do
			turtle.select(slot)
			turtle.suck(1)
			ok, err = self:checkSlot(slot, "minecraft:sand")
			if not ok then
				error("Failed to extract sand from storage")
			end
		end

		-- Go back home and turn to our gravel storage
		ok, err = self:goHome()
		if not ok then
			error("Failed to go home: " .. err)
		end

		-- Turn to the gravel storage
		turtle.turnRight()

		-- Extract gravel into our slots
		local GRAVEL = { 7, 9, 10, 11 }
		for _, slot in ipairs(GRAVEL) do
			turtle.select(slot)
			turtle.suck(1)
			ok, err = self:checkSlot(slot, "minecraft:gravel")
			if not ok then
				error("Failed to extract gravel from storage")
			end
		end

		-- Turn back to the front and select our first slot
		turtle.turnLeft()
		turtle.select(1)

		-- Craft white concrete
		ok, err = turtle.craft()
		if not ok then
			Log.error("Failed to craft white concrete:", err)
			error("Failed to craft white concrete: " .. err)
		end

		-- Push the concrete into our output storage
		turtle.dropUp()
	end
end

local function main(args)
	local maker = Maker:create()
	maker:loop()
end

main({ ... })
