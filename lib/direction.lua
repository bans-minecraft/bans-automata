local Assert = require("lib.assert")
local Log = require("lib.log")
local Utils = require("lib.utils")
local Vector = require("lib.vector")
local class = require("lib.class")

-- A direction
--
-- Note that these are global (world) directions, and should not be used relatively
local M = {
  North = 0,
  West = 1,
  South = 2,
  East = 3,
  Up = 4,
  Down = 5,
}

-- Make sure that the argument is a valid direction
M.assertDir = function(dir)
  if type(dir) ~= "number" then
    error("Expected 'dir' to be a number; found " .. type(dir))
  end

  if dir < 0 or dir > 5 then
    Log.error("Invalid direction " .. dir .. "; expected 0..5")
    error("Invalid direction " .. dir .. "; expected 0..5")
  end
end

-- A table of direction offsets
--
-- This table provides a LUT from a `Direction` to a unit `Vector` in the given direction. See
-- the `dirOffset()` function.
local DIR_OFFSET = {}
DIR_OFFSET[M.North] = Vector:new(0, 0, -1)
DIR_OFFSET[M.South] = Vector:new(0, 0, 1)
DIR_OFFSET[M.East] = Vector:new(1, 0, 0)
DIR_OFFSET[M.West] = Vector:new(-1, 0, 0)
DIR_OFFSET[M.Up] = Vector:new(0, 1, 0)
DIR_OFFSET[M.Down] = Vector:new(0, -1, 0)

-- Get the offset for a direction
--
-- This function will return a unit `Vector` (cloned from the `DIR_OFFSET` table) that gives the
-- offset for the given direction.
M.dirOffset = function(dir)
  M.assertDir(dir)
  return DIR_OFFSET[dir]:clone()
end

-- A LUT of human-readable names
local DIR_NAMES = {}
DIR_NAMES[M.North] = "North"
DIR_NAMES[M.South] = "South"
DIR_NAMES[M.East] = "East"
DIR_NAMES[M.West] = "West"
DIR_NAMES[M.Up] = "Up"
DIR_NAMES[M.Down] = "Down"

-- Get the human-readable name of a direction
M.dirName = function(dir)
  M.assertDir(dir)
  return DIR_NAMES[dir]
end

local DIR_OPPOSITES = {}
DIR_OPPOSITES[M.North] = M.South
DIR_OPPOSITES[M.South] = M.North
DIR_OPPOSITES[M.East] = M.West
DIR_OPPOSITES[M.West] = M.East
DIR_OPPOSITES[M.Up] = M.Down
DIR_OPPOSITES[M.Down] = M.Up

-- Get the opposite direction
M.opposite = function(dir)
  M.assertDir(dir)
  return DIR_OPPOSITES[dir]
end

-- Offset a vector in a direction with a given scale.
--
-- For any valid direction `dir`, this function will scale the direction vector by the number `d`
-- (defaulting to 1) and return `v + d * dirOffset(dir)`.
M.offsetDirection = function(v, dir, d)
  Assert.assertInstance(v, Vector)

  if type(d) ~= "number" then
    d = 1
  end

  return v + M.dirOffset(dir):scale(d)
end

local DIR_ALIASES = {
  ["N"] = M.North,
  ["E"] = M.East,
  ["S"] = M.South,
  ["W"] = M.West,
  ["U"] = M.Up,
  ["D"] = M.Down,

  ["North"] = M.North,
  ["South"] = M.South,
  ["East"] = M.East,
  ["West"] = M.West,
  ["Up"] = M.Up,
  ["Down"] = M.Down,
}

for key, value in pairs(DIR_ALIASES) do
  DIR_ALIASES[string.lower(key)] = value
  DIR_ALIASES[string.upper(key)] = value
end

M.parseDirection = function(name)
  return DIR_ALIASES[name]
end

local SIDE_INDICES = { "left", "back", "right", "front" }

M.directionSide = function(facing, direction)
  M.assertDir(facing)
  M.assertDir(direction)
  return SIDE_INDICES[1 + (direction - facing + 3) % 4]
end

local DirSeqStep = class("DirSeqStep")

function DirSeqStep:init(direction, count)
  M.assertDir(direction)
  self.direction = direction
  self.count = Utils.numberOrDefault(count, 1)
end

local DirSeq = class("DirSeq")

function DirSeq:init()
  self.steps = {}
end

function DirSeq:finish()
  return self.steps
end

function DirSeq:add(step)
  Assert.assertInstance(step, DirSeqStep)
  table.insert(self.steps, step)
end

function DirSeq:north(count)
  self:add(DirSeqStep:new(M.North, count))
  return self
end

function DirSeq:south(count)
  self:add(DirSeqStep:new(M.South, count))
  return self
end

function DirSeq:east(count)
  self:add(DirSeqStep:new(M.East, count))
  return self
end

function DirSeq:west(count)
  self:add(DirSeqStep:new(M.West, count))
  return self
end

function DirSeq:up(count)
  self:add(DirSeqStep:new(M.Up, count))
  return self
end

function DirSeq:down(count)
  self:add(DirSeqStep:new(M.Down, count))
  return self
end

M.DirSeqStep = DirSeqStep
M.DirSeq = DirSeq

M.seq = function()
  return DirSeq:new()
end

return M
