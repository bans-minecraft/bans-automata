-- Area Awareness
--
-- THe AA (Area Awareness) system allows bots to keep track of information about the blocks it has
-- inspected on its journey around the world. This information can then be queried. The most
-- powerful tool the AA grants us is to enable bots to "path find". That is, a bot is able to take a
-- coordinate that is has visited before, build a fairly optimal path back to that block, and then
-- follow that path. This is achieved using the A* (A-Star) algorithm. The success of the algorithm
-- depends on a number of predicates:
--
-- 1. The bot has actual knowledge, stored in it's `Awareness`, about it's current location and the
--    location of the target block it is path-finding towards.
--
-- 2. The bot actually has stored a resonable "graph" between the current and target blocks that it
--    can explore. This typically means ensuring that the bot is not moved using the typicaly
--    `turtle...` methods, but rather using the equivalent methods under the `Bot` class (e.g.
--    `Bot:forward` rather than `turtle.forward`). This should maintain sufficient AA data for the
--    bot to path-find back to any point along the path it has previously traversed.
--
-- 3. There must actually exist a solution, and that solution should be solvable by the A*
--    algorithm. If not, the path finding will nto successfully generate a path.
--
-- Rather tha complicate matters with an actual graph, the AA is stored as a hash. The hash key is a
-- string, built with the `positionKey` function, that encodes the X, Y, and Z coordinates of a
-- block. The value associated with each key is an `AANode` that describes the contents of the
-- block.

local Direction = require("lib.direction")
local Assert = require("lib.assert")
local Log = require("lib.log")
local Utils = require("lib.utils")
local Vector = require("lib.vector")
local AANode = require("lib.bot.aa.node")
local AAUtils = require("lib.bot.aa.utils")
local class = require("lib.class")

-- Area Awareness (AA)
--
-- This class encapsulates the AA graph, and provides some simple functions over that graph.
local AA = class("AA")

function AA:init()
  self.cache = {}
end

function AA.static.deserialize(data)
  Assert.assertIs(data, "table")
  Assert.assertIs(data.cache, "table")

  local aa = AA:new()
  for key, value in pairs(data.cache) do
    aa.cache[key] = AANode.deserialize(value)
  end

  return aa
end

function AA:serialize()
  local cache = {}
  for key, node in pairs(self.cache) do
    cache[key] = node:serialize()
  end

  return {
    cache = cache,
  }
end

function AA:clear()
  self.cache = {}
end

-- Acquire information about the block infront of the bot
--
-- This function will return an `AANode` that describes the block infront of the bot.
function AA:getNodeForward()
  local has_block, info = turtle.inspect()
  if not has_block then
    return AANode.createEmpty()
  end

  return AANode.createFromInfo(info)
end

-- Acquire information about the block above the bot
--
-- This function will return an `AANode` that describes the block above the bot.
function AA:getNodeUp()
  local has_block, info = turtle.inspectUp()
  if not has_block then
    return AANode.createEmpty()
  end

  return AANode.createFromInfo(info)
end

-- Acquire information about the block below the bot
--
-- This function will return an `AANode` that describes the block below the bot.
function AA:getNodeDown()
  local has_block, info = turtle.inspectDown()
  if not has_block then
    return AANode.createEmpty()
  end

  return AANode.createFromInfo(info)
end

-- Get the `AANode` corresponding to the given hash key (index)
--
-- If there is no such node in the AA, this will return a new `AANode` representing an unknown
-- block.
function AA:queryIndex(index)
  return self.cache[index] or AANode.createUnknown()
end

-- Get the `AANode` corresponding to the given block position (as a `Vector`)
--
-- If there is no such node in the AA, this will return a new `AANode` representing an unknown
-- block.
function AA:query(v)
  return self.cache[AAUtils.positionKey(v)] or AANode.createUnknown()
end

-- Attempt a check whether the given block position (as a `Vector`) is an ore.
--
-- This function will return two values:
--
-- 1. A boolean indicating whether the AA believes that the block at the given position is an ore,
-- 2. The `AANode` that represents that block.
--
-- Note that, if the first result is `false`, it is possible that the returned `AANode` is simply an
-- empty `AANode` representing an unknown block (as retuened from `AA:query`).
function AA:checkOre(v)
  local node = self:query(v)
  if node.state ~= AANode.FULL then
    return false, node
  end

  return node:isOre(), node
end

function AA:dump()
  Log.info(("AA contains %d nodes"):format(#self.cache))
  for key, node in pairs(self.cache) do
    Log.info(("%s: %s"):format(key, node))
  end
end

function AA:updateIndex(index, node)
  Assert.assertIs(index, "number")
  Assert.assertInstance(node, AANode)
  self.cache[index] = node
end

function AA:update(v, node)
  Assert.assertInstance(v, Vector)
  Assert.assertInstance(node, AANode)
  self.cache[AAUtils.positionKey(v)] = node
end

local MinHeap = require("lib.min-heap")
local OpenSet = class("OpenSet", MinHeap)

function OpenSet:init()
  MinHeap.init(self)
  self.map = {}
end

function OpenSet:get(key)
  return self.map[key]
end

function OpenSet:getPriority(node)
  return node.fScore
end

function OpenSet:insert(x)
  self.map[x.key] = x
  return MinHeap.insert(self, x)
end

function OpenSet:remove(x)
  local removed = MinHeap.remove(self, x)

  if removed then
    self.map[x.key] = nil
  end

  return removed
end

function OpenSet:pop()
  local node = MinHeap.pop(self)
  self.map[node.key] = nil
  return node
end

local PathNode = class("PathNode")

function PathNode:init(coord, fScore, gScore)
  self.key = AAUtils.positionKey(coord)
  self.coord = coord
  self.fScore = fScore or 0
  self.gScore = gScore or 0
end

-- Reconstruct a path from the `visited` table.
--
-- This will build the path, backwards, from the target (passed in `goal`) along all the visited
-- nodes in the `visited` table. This returns a table of directions, where each direction indicates
-- that the bot should take a step in that direction (e.g. `North, North, East, East`).
local function reconstructPath(visited, goal)
  local path = {}

  while visited[goal] ~= nil do
    table.insert(path, 1, visited[goal][1])
    goal = visited[goal][2]
  end

  return path
end

-- Honestly, after a million steps we're getting really daft.
local MAX_PATH_LENGTH = 1000000

function AA:buildPath(start, target, limit)
  Assert.assertInstance(start, Vector)
  Assert.assertInstance(target, Vector)

  -- If the block that we're targeting is known to be full, we cannot build a path there.
  local targetNode = self:query(target)
  if targetNode.state == AANode.FULL then
    Log.error(("Cannot build a path to full block at %s"):format(target))
    return nil
  end

  -- Ensure that the limit is sensible.
  if type(limit) ~= "number" or limit < 0 then
    limit = MAX_PATH_LENGTH
  end

  if limit > MAX_PATH_LENGTH then
    Log.warn("Path limit of %d is too high, setting to %d", limit, MAX_PATH_LENGTH)
    limit = MAX_PATH_LENGTH
  end

  local targetKey = AAUtils.positionKey(target)
  local openSet = OpenSet:new()
  local closedSet = {}
  local visited = {}

  -- Add the start node and it's score to the open set
  openSet:insert(PathNode:new(start, AAUtils.costEstimate(start, target), 0))

  while #openSet > 0 do
    -- Get the node with the lowest fScore from the open set.
    local current = openSet:pop()

    -- If we've reached the goal, reconstruct the path and return it.
    if current.key == targetKey then
      return reconstructPath(visited, targetKey)
    end

    -- If we'e exceeded our path-finding limit, then abort.
    if current.fScore >= limit then
      Log.error(("Path-finding limit of %d reached (by %d)"):format(limit, current.fScore))
      return nil
    end

    -- Add the current block to the closed set.
    closedSet[current.key] = true

    -- Scan in all six directions from the current block. If we find a neighbouring block that is
    -- known to be empty, calculate the score for that neighbour and add it to the open set.
    for dir = 0, 5 do
      local n = Direction.offsetDirection(current.coord, dir)
      local neighbourKey = AAUtils.positionKey(n)
      local neighbour = self:queryIndex(neighbourKey)

      -- If the neighbour block in the direction `dir` is known to be `EMPTY` (by `AANode` status),
      -- and it is not already present in the closed set, then calculate the score and add it to the
      -- open set.
      if neighbour.state == AANode.EMPTY and closedSet[neighbourKey] == nil then
        -- The goal score for a neighbour is simply the cost of the `current` block plus one: ew're
        -- moving one block at a time.
        local gScore = current.gScore + 1

        -- If the neighbour is not already in the open set, or the new score in `g` is better
        -- (lower) than the score we previously recorded for this block, then we can add it to the
        -- open set. This ensures that we do not repeatedly add blocks to the open set, unless the
        -- score will be improved since we last added them.
        local existing = openSet:get(neighbourKey)
        if existing == nil or gScore < existing.gScore then
          visited[neighbourKey] = { dir, current.key }
          openSet:remove(existing)
          openSet:insert(PathNode:new(n, gScore + AAUtils.costEstimate(n, target), gScore))
        end
      end
    end
  end
end

function AA:buildPathOld(a, b, limit)
  Assert.assertInstance(a, Vector)
  Assert.assertInstance(b, Vector)

  -- if the block that we're targeting is known to be full, we cannot build a path there.
  local target = self:query(b)
  if target.state == AANode.FULL then
    Log.error("Cannot build path to a full block")
    return nil
  end

  -- Make sure that the limit is sensible
  if type(limit) ~= "number" or limit < 0 or limit > 9999999 then
    limit = 9999999
  end

  -- The following tables (i.e. `openSet` and `visited`) are all indexed in the same as was the AA
  -- cache: by the string returned from `AAUtils.positionKey`.

  local startIndex = AAUtils.positionKey(a)
  local goalIndex = AAUtils.positionKey(b)
  local openSet = {}   -- a table of vectors that have yet to be processed
  local closedSet = {} -- a table of booleans indicating that we've processed a vector
  local visited = {}   -- a table of pairs of a direction and the index (a string key)
  local gScore = {}    -- a table of gScores for each vector
  local fScore = {}    -- a table of fScores for each vector

  -- Add the start node and its score to the open set
  openSet[startIndex] = a:clone()
  gScore[startIndex] = 0
  fScore[startIndex] = AAUtils.costEstimate(a, b)

  while not Utils.isEmpty(openSet) do
    local fCurrent = 9999999
    local current      -- a Vector
    local currentIndex -- a string index

    -- Find the node with the lowest fScore in the open set.
    for i, node in pairs(openSet) do
      if node ~= nil and fScore[i] <= fCurrent then
        currentIndex = i
        current = node:clone()
        fCurrent = fScore[i]
      end
    end

    -- If we've reached the goal, reconstruct the path and return it.
    if currentIndex == goalIndex then
      return AAUtils.reconstructPath(visited, goalIndex)
    end

    -- If we've exceeded our path finding limit, then abort.
    if fCurrent >= limit then
      Log.error(("Path-finding limit of %d reached (by %d)"):format(limit, fCurrent))
      return nil
    end

    -- Remove the 'current' block from the open set and add it to the closed set.
    openSet[currentIndex] = nil
    closedSet[currentIndex] = true

    -- Scan in all six directions from the current block. If we find a neighbouring block that is
    -- known to be empty, calculate the score for that neighbour and add it to the open set.
    for dir = 0, 5 do
      local n = Direction.offsetDirection(current, dir)
      local neighbourIndex = AAUtils.positionKey(n)
      local neighbour = self:queryIndex(neighbourIndex)

      -- If the neighbour block in the direction `dir` is known to be `EMPTY` (by `AANode` status),
      -- and it is not already present in the closed set, then calculate the score and add it to the
      -- open set.
      if neighbour.state == AANode.EMPTY and closedSet[neighbourIndex] == nil then
        -- The goal score for a neighbour is simply the cost of the `current` block plus one: we're
        -- moving one block at a time.
        local g = gScore[currentIndex] + 1

        -- If the neighbour is not already in the open set, or the new score in `g` is better
        -- (lower) than the score we previously recorded for this block, then we can add it to the
        -- open set. This ensures that we do not repeatedly add blocks to the open set, unless the
        -- score will be improved since we last added them.
        if openSet[neighbourIndex] == nil or g <= gScore[neighbourIndex] then
          visited[neighbourIndex] = { dir, currentIndex }
          gScore[neighbourIndex] = g
          fScore[neighbourIndex] = g + AAUtils.costEstimate(n, b)
          openSet[neighbourIndex] = n
        end
      end
    end
  end
end

return AA
