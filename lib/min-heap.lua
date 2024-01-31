local Assert = require("lib.assert")
local class = require("lib.class")

local MinHeap = class("MinHeap")

function MinHeap:init()
  self.heap = {}
  self.size = 0
end

function MinHeap:getPriority(item)
  return item
end

function MinHeap:isEmpty()
  return self.size == 0
end

function MinHeap:__len()
  return self.size
end

function MinHeap:getPriorityAt(index)
  return self:getPriority(self.heap[index])
end

function MinHeap:_heapUp(from)
  local index = from
  local parent = math.floor(0.5 * index)

  while index > 1 and self:getPriorityAt(parent) > self:getPriorityAt(index) do
    self.heap[index], self.heap[parent] = self.heap[parent], self.heap[index]
    index = parent
    parent = math.floor(0.5 * index)
  end

  return index
end

function MinHeap:_heapDown(limit)
  for index = limit, 1, -1 do
    local left = index + index
    local right = left + 1

    while left <= self.size do
      local smallest = left
      if right <= self.size and self:getPriorityAt(left) > self:getPriorityAt(right) then
        smallest = right
      end

      if self:getPriorityAt(index) > self:getPriorityAt(smallest) then
        self.heap[index], self.heap[smallest] = self.heap[smallest], self.heap[index]
      else
        break
      end

      index = smallest
      left = index + index
      right = left + 1
    end
  end
end

function MinHeap:insert(x)
  local index = self.size + 1
  self.size = index
  self.heap[index] = x
  self:_heapUp(index)
  return self
end

function MinHeap:_indexOf(x)
  for i = 1, self.size do
    if self.heap[i] == x then
      return i
    end
  end

  return nil
end

function MinHeap:contains(x)
  return self:_indexOf(x) ~= nil
end

function MinHeap:remove(x)
  local index = self:_indexOf(x)
  if index ~= nil then
    if self.size == index then
      self.heap[index] = nil
      self.size = self.size - 1
    else
      self.heap[index] = self.heap[self.size]
      self.heap[self.size] = nil
      self.size = self.size - 1

      if self.size > 1 then
        local sifted = self:_heapUp(index)
        self:_heapDown(sifted)
      end
    end

    return true
  else
    return false
  end
end

function MinHeap:pop()
  Assert.assert(self.size > 0, "Heap is empty")

  local top = self.heap[1]

  if self.size > 1 then
    self.heap[1] = self.heap[self.size]
    self.heap[self.size] = nil
    self.size = self.size - 1
    self:_heapDown(1)
  else
    self.heap[1] = nil
    self.size = 0
  end

  return top
end

function MinHeap:peek()
  return self.heap[1]
end

return MinHeap
