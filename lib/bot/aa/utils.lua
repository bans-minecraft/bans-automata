local Log = require("lib.log")
local Vector = require("lib.vector")

local M = {}

-- Approximate distance cost estimator
--
-- This function computes the cost estimate for traversal from (ax, ay, az) to (bx, by, bz). As
-- Minecraft is a grid world, we don't bother using anything like the Euclidean distance, and
-- instead use the Manhattan distance.
--
-- See: https://en.wikipedia.org/wiki/Taxicab_geometry
--
M.costEstimate = function(a, b)
  Log.assertClass(a, Vector)
  Log.assertClass(b, Vector)
  return math.abs(b.x - a.x) + math.abs(b.y - a.y) + math.abs(b.z - a.z)
end

M.positionKey = function(v)
  Log.assertClass(v, Vector)
  return ("%.0f:%.0f:%.0f"):format(v.x, v.y, v.z)
end

-- Expand A* path
--
-- This function walks back along the path from the A* visited nodes, and returns a series of
-- directions to move in.
M.reconstructPath = function(visited, goal)
  local path = {}

  while visited[goal] ~= nil do
    table.insert(path, 1, visited[goal][1])
    goal = visited[goal][2]
  end

  return path
end

return M
