local Log         = require("lib.log");
local Ores        = require("lib.bot.ores");

-- A node in the AA graph
--
-- Each node in the AA graph represents a block that the bot is "aware" of. Each node stores the
-- `state` of the block along with the `info` about the block (as returned from the `turtle.inspect`
-- method and its kin).
local AANode      = {}
AANode.__index    = AANode
AANode.__name     = "AANode"

-- Possible states of an AANode
AANode.UNKNOWN    = -1 -- Block state is unknown
AANode.EMPTY      = 0  -- Block is empty (contains air, water, or other traversable)
AANode.FULL       = 1  -- Block is full (contains non-traversable)

-- Minecraft blocks that we consider traversable
local TRAVERSABLE = {
  ["minecraft:air"]   = true,
  ["minecraft:water"] = true,
  ["minecraft:lava"]  = true,
}

function AANode:create(state, info)
  Log.assertIs(state, "number")
  Log.assertIs(info, "table")

  local node = {}
  setmetatable(node, AANode)
  node.state = state
  node.info  = info

  return node
end

-- Create an AA node for an empty block.
--
-- This returns an AA node that is used to represent a block that contains air, water, or some other
-- traversable. The bot can move through these sort of blocks. Notably, the block that the bot
-- currently occupies is also considered empty.
function AANode:createEmpty()
  return AANode:create(AANode.EMPTY, { name = "minecraft:air", tags = {} })
end

-- Create an AA node for an unknown block.
--
-- If a query to the AA is for a block that is unknown, a node with this `state` is returned.
function AANode:createUnknown()
  return AANode:create(AANode.UNKNOWN, { name = "unknown", tags = {} })
end

-- Create an AA node from inspection information.
--
-- This is used to create an `AANode` from some data (a table) returned from `turtle.inspect` and
-- its kin.
function AANode:createFromInfo(info)
  Log.assertIs(info, "table")
  local state = AANode.EMPTY
  if not TRAVERSABLE[info.name] then
    state = AANode.FULL
  end

  return AANode:create(state, info)
end

function AANode:isOre()
  return Ores.isOre(self.info)
end

function AANode:__tostring()
  return ("AANode(%i, %s)"):format(self.state, self.info.name)
end

return AANode
