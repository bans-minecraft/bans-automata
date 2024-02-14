local Assert = require("lib.assert")
local Class = require("lib.class")
local Enum = require("lib.enum")

local Selector = Class("Selector")
Selector.static.Combinator = Enum("Descendent", "Child")

function Selector:init(name)
  Assert.assertIsString(name)
  self.name = name
  self.child = nil
end

function Selector:matches(widget)
  local class = widget.class
  while class do
    if class.name == self.name then return true end
    class = class.super
  end

  return false
end

function Selector:__eq(other)
  return other.name == self.name
end

function Selector:__tostring()
  local child = ""
  if self.child then
    child = " " .. tostring(self.child.selector)
    if self.child.combinator == Selector.Combinator.Child then
      child = " >" .. child
    end
  end

  return self.name .. child
end

function Selector.static.parseSelector(input)
  local name = string.match(input, "^([%a-]+)$")
  if not name then
    return nil
  end

  return Selector:new(name)
end

function Selector.static.parseCombinator(input)
  if input == ">" then
    return Selector.Combinator.Child
  end
end

function Selector.static.reverse(node)
  local prev

  while node do

  end




  local prev
  local node = head

  while node do
    local next_node = node.child and node.child.selector or nil
    local new_combinator = node.child and node.child.combinator or nil
    node.child = prev

    if prev then
      prev.selector = node
    end

    if new_combinator then
      prev = { combinator = new_combinator, selector = nil }
    end

    node = next_node
  end

  return prev
end

function Selector.static.parse(input)
  local combinator = Selector.Combinator.Descendent
  local root, last

  for token in string.gmatch(input, "%S+") do
    local selector = Selector.parseSelector(token)
    if selector then
      if last then
        last.child = {
          combinator = combinator,
          selector = selector
        }

        combinator = Selector.Combinator.Descendent
      end

      if not root then
        root = selector
      end

      last = selector
    elseif root then
      combinator = Selector.parseCombinator(token)
      if not combinator then
        return nil, ("Expected combinator or selector after '%s'; found '%s'"):format(root, token)
      end
    else
      return nil, ("Expected selector; found '%s'"):format(token)
    end
  end

  return root
end

return Selector
