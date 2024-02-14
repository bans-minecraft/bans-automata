local Assert = require("lib.assert")
local Class = require("lib.class")
local Enum = require("lib.enum")
local Selector = require("lib.widget.theme.selector")
local Log = require("lib.log")

local Edge = Class("CssEdge")
local EdgeType = Enum("Descendent", "Child")

local function edgeTypeForCombinator(combinator)
  if combinator == Selector.Combinator.Descendent then
    return EdgeType.Descendent
  elseif combinator == Selector.Combinator.Child then
    return EdgeType.Child
  else
    error(("Unrecognized selector combinator: '%s'"):format(combinator))
  end
end

function Edge:init(etype, selector, node)
  self.type = etype
  self.selector = selector
  self.node = node
end

function Edge:matches(widget, depth)
  if self.type == EdgeType.Child and depth > 0 then
    return false
  end

  return self.selector:matches(widget)
end

---------------------------------------------------------------------------------------------------

local Node = Class("CssNode")

function Node:init()
  self.attributes = {}
  self.edges = {}
end

local pretty = require("cc.pretty")

function Node:print(indent)
  print(indent .. pretty.render(pretty.pretty(self.attributes)))
  for _, edge in ipairs(self.edges) do
    print(indent .. ("+- (%s): %s"):format(edge.type, edge.selector))
    edge.node:print(indent .. "    ")
  end
end

function Node:addEdge(combinator, selector)
  local etype = edgeTypeForCombinator(combinator)
  for _, edge in ipairs(self.edges) do
    if edge.type == etype and edge.selector == selector then
      return edge
    end
  end

  local edge = Edge:new(etype, selector, Node:new())
  table.insert(self.edges, edge)
  return edge
end

function Node:addSelector(combinator, selector)
  local edge = self:addEdge(combinator, selector)

  if selector.child then
    return edge.node:addSelector(selector.child.combinator, selector.child.selector)
  else
    return edge.node
  end
end

local function build(theme)
  local root = Node:new()

  for selectorStr, attributes in pairs(theme) do
    local selector, err = Selector.parse(selectorStr)
    print("Selector (original):", selector)
    print("Selector (reverse ):", Selector:reverse(selector))
    if not selector then
      return nil, err
    end

    local node = root:addSelector(Selector.Combinator.Descendent, selector)
    for key, value in pairs(attributes) do
      node.attributes[key] = value
    end
  end

  return root
end

---------------------------------------------------------------------------------------------------

local Iterator = Class("CssIterator")

function Iterator:init(node)
  Assert.assertInstance(node, Node)
  self.node = node
  self.depth = 0
  self.stack = {}
end

function Iterator:enter(childWidget)
  Log.info(("Iterator:enter(childWidget = %s)"):format(childWidget))
  for _, edge in ipairs(self.node.edges) do
    if edge.selector:matches(childWidget, self.depth) then
      table.insert(self.stack, { node = self.node, depth = self.depth })
      self.node = edge.node
      self.depth = 0
      return
    end
  end

  self.depth = self.depth + 1
end

function Iterator:leave()
  Log.info(("Iterator:leave() depth = %d"):format(self.depth))
  if self.depth > 0 then
    self.depth = self.depth - 1
    return
  end

  Assert.assert(#self.stack > 0, "stack underflow")
  local last = table.remove(self.stack)
  self.node = last.node
  self.depth = last.depth
end

---------------------------------------------------------------------------------------------------

return {
  Node = Node,
  build = build,
  Iterator = Iterator
}
