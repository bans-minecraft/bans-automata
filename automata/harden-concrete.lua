-- harden-concrete.lua
--
-- A bot that harderns concrete powder into concrete.
--
-- [2023-11-11] Initial version

package.path = "/?.lua;/?/init.lua;" .. package.path
local Log = require("lib.log")
Log.setLogFile("concrete.log")

local Location = {
	Output = "Output",
	Input = "Input",
	Water = "Water",
}

local Maker = {}
Maker.__index = Maker
Maker.__name = "Maker"

function Maker:create()
	local maker = {}
	setmetatable(maker, Maker)

	maker.location = Location.Output

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

function Maker:up()
	local ok, err = turtle.up()
	if not ok then
		Log.error("Failed to move up:", err)
		error("Failed to move up: " .. err)
	end

	return self
end
function Maker:down()
	local ok, err = turtle.down()
	if not ok then
		Log.error("Failed to move down:", err)
		error("Failed to move down: " .. err)
	end

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

function Maker:gotoOutput()
	if self.location == Location.Output then
		return self
	elseif self.location == Location.Input then
		return self:backward(1)
			:turnLeft()
			:backward()
			:up()
			:backward()
			:turnRight()
			:backward()
			:down()
			:setLocation(Location.Output)
	elseif self.location == Location.Water then
		return self:backward():turnLeft():backward():down():setLocation(Location.Output)
	else
		Log.error("Unrecognized location:", self.location)
		return nil, "Unrecognized location"
	end
end

function Maker:gotoInput()
	if self.location == Location.Output then
		return self:up():forward():turnLeft():forward(2):down():turnRight():forward(1):setLocation(Location.Input)
	elseif self.location == Location.Input then
		return self
	elseif self.location == Location.Water then
		return self:backward(2):down():backward():turnLeft():forward(1):setLocation(Location.Input)
	else
		Log.error("Unrecognized location:", self.location)
		return nil, "Unrecognized location"
	end
end

function Maker:gotoWater()
	if self.location == Location.Output then
		return self:up():forward():turnRight():forward():setLocation(Location.Water)
	elseif self.location == Location.Input then
		return self:backward(1):turnRight():up():forward(3):setLocation(Location.Water)
	elseif self.location == Location.Water then
		return self
	else
		Log.error("Unrecognized location:", self.location)
		return nil, "Unrecognized location"
	end
end

function Maker:takeConcretePowder()
	turtle.select(1)
	turtle.suck(64)

	local info = turtle.getItemDetail()
	if not info then
		Log.info("Didn't get anything from our input; waiting for some input")

		while not info do
			sleep(1)
			turtle.suck(64)
			info = turtle.getItemDetail()
		end

		Log.info("Seems we now have some items from our input")
	else
		Log.info("Seems we have some items from our input")
	end

	Log.info(("Received %dx %s from input chest"):format(info.count, info.name))

	if info.name ~= "minecraft:white_concrete_powder" then
		Log.error("Did not receive white concrete powder from input chest; received", info)
		return nil, "Did not receive white concrete powder from input chest"
	end

	return self
end

function Maker:makeConcrete()
	local ok, err, info

	while true do
		-- Go to the slot that contains our concrete powder and count
		turtle.select(1)
		info = turtle.getItemDetail()
		if not info or info.count == 0 then
			Log.info("Bot has no more concrete powder to process")
			return self
		end

		Log.info(("Bot has %dx %s in slot 1"):format(info.count, info.name))
		if info.name ~= "minecraft:white_concrete_powder" then
			Log.error("Expected white concrete powder in slot 1; found", info)
			return nil, "incorrect block in slot 1"
		end

		-- Place a single block of concrete powder underneath the bot; this should turn into concrete.
		ok, err = turtle.placeDown()
		if not ok then
			Log.error("Failed to place concrete poweder into water:", err)
			return nil, "Failed to place concrete poweder into water"
		end

		-- Now we should be able to dig the concrete block underneath the bot
		turtle.select(2)
		ok, err = turtle.digDown()
		if not ok then
			Log.error("Failed to dig concrete under bot:", err)
			return nil, "Failed to dig concrete under bot"
		end

		-- Make sure that what we got was concrete
		info = turtle.getItemDetail()
		if not info then
			Log.error("Did not receive anything after digging concrete")
			return nil, "Did not receive anything after digging concrete"
		end

		if info.name ~= "minecraft:white_concrete" then
			Log.error("Expected to receive white concrete; found", info)
			return nil, "Did not receive white concrete"
		end

		-- The white concrete is cool, so move it to slot 3
		turtle.transferTo(3)
	end
end

function Maker:emptyOutput()
	-- Go to slot 3; which is where the concrete should bve
	turtle.select(3)

	-- Dump it alL into the output
	local ok, err = turtle.dropDown()
	if not ok then
		Log.error("Expect to be able to drop concrete down:", err)
		return nil, "Failed to drop concrete"
	end

	return self
end

function Maker:loop()
	local ok, err

	while true do
		-- Go the input and grap at most a stack of concrete
		ok, err = self:gotoInput()
		if not ok then
			error("Failed to go to input: " .. err)
		end

		ok, err = self:takeConcretePowder()
		if not ok then
			error("Failed to get concrete powder: " .. err)
		end

		-- Go to the water and turn all the concrete powder into concrete
		ok, err = self:gotoWater()
		if not ok then
			error("Failed to go to water: " .. err)
		end

		ok, err = self:makeConcrete()
		if not ok then
			error("Failed to make concrete: " .. err)
		end

		-- Goto the output location and output all our concrete
		ok, err = self:gotoOutput()
		if not ok then
			error("Failed to go to output: " .. err)
		end

		ok, err = self:emptyOutput()
		if not ok then
			error("Failed to empty output: " .. err)
		end
	end
end

local function main(args)
	local maker = Maker:create()
	maker:loop()
end

main({ ... })
