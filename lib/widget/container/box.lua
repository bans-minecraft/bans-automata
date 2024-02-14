local Assert = require("lib.assert")
local Child = require("lib.widget.container.child")
local Class = require("lib.class")
local Rect = require("lib.rect")
local Requisition = require("lib.widget.requisition")
local Size = require("lib.size")
local Table = require("lib.table")
local Widget = require("lib.widget")

local Box = Class("Box", Widget)

function Box:init(orientation)
  Assert.assertIs(orientation, "string")
  Widget.init(self)
  self.border = 0
  self.children = {}
  self.spacing = 0
  self.homogeneous = false
  self.orientation = orientation
end

function Box:getChildren()
  return Table.map(self.children, function(child)
    return child.widget
  end)
end

function Box:getChildIndex(widget)
  for index, child in ipairs(self.children) do
    if child.widget == widget then
      return index
    end
  end

  return nil
end

function Box:addChild(widget, packing, expand, fill, padding)
  Assert.assertInstance(widget, Widget)
  Assert.assertEq(widget.parent, nil)
  local child = Child:new(widget)
  table.insert(self.children, child)

  if packing ~= nil then
    Assert.assertIs(packing, "string")
    child.packing = packing
  end

  if expand ~= nil then
    Assert.assertIs(expand, "boolean")
    child.expand = expand
  end

  if fill ~= nil then
    Assert.assertIs(fill, "boolean")
    child.fill = fill
  end

  if padding ~= nil then
    Assert.assertIs(padding, "number")
    child.padding = padding
  end

  widget:setParent(self)
  self:queueRedraw()
end

function Box:removeChild(widget)
  Assert.assertInstance(widget, Widget)
  Assert.assertEq(widget.parent, self)
  local index = self:getChildIndex(widget)
  Assert.assertNeq(index, nil)
  table.remove(self.children, index)
  widget:clearParent()
  self:queueRedraw()
end

function Box:insertChild(index, widget)
  Assert.assertInstance(widget, Widget)
  Assert.assertEq(widget.parent, nil)
  table.insert(self.children, index, Child:new(widget))
  widget:setParent(self)
  self:queueRedraw()
end

function Box:setSpacing(spacing)
  Assert.assertIs(spacing, "number")
  self.spacing = spacing
  self:queueRedraw()
end

function Box:setHomogeneous(active)
  Assert.assertIs(active, "boolean")
  self.homogeneous = active
  self:queueRedraw()
end

function Box:getChildForWidget(widget)
  Assert.assertInstance(widget, Widget)
  local index = self:getChildIndex(widget)
  if index ~= nil then
    return self.children[index]
  end

  return nil
end

function Box:_getChildForWidgetOrIndex(widgetOrIndex)
  if type(widgetOrIndex) == "number" then
    Assert.assert(widgetOrIndex >= 1 and widgetOrIndex <= #self.children,
      ("Child index %d is out of range 1..%d"):format(widgetOrIndex, #self.children))
    return self.children[widgetOrIndex]
  else
    Assert.assertInstance(widgetOrIndex, Widget)
    return self:getChildForWidget(widgetOrIndex)
  end
end

function Box:setChildPadding(widgetOrIndex, padding)
  Assert.assertIs(padding, "number")
  local child = self:_getChildForWidgetOrIndex(widgetOrIndex)
  Assert.assertInstance(child, Widget)
  child.padding = padding
  self:queueRedraw()
end

function Box:setChildExpand(widgetOrIndex, expand)
  Assert.assertIs(expand, "boolean")
  local child = self:_getChildForWidgetOrIndex(widgetOrIndex)
  Assert.assertInstance(child, Widget)
  child.expand = expand
  self:queueRedraw()
end

function Box:setChildFill(widgetOrIndex, fill)
  Assert.assertIs(fill, "boolean")
  local child = self:_getChildForWidgetOrIndex(widgetOrIndex)
  Assert.assertInstance(child, Widget)
  child.fill = fill
  self:queueRedraw()
end

function Box:setOrientation(orientation)
  Assert.assertIs(orientation, "string")
  self.orientation = orientation
  self:queueRedraw()
end

function Box:getSizeRequest()
  local min = Size:new(0, 0)
  local natural = Size:new(0, 0)

  for index, child in ipairs(self.children) do
    child:getSizeRequest(self.spacing, index == 1, index == #self.children, self.orientation)

    if self.orientation == "vertical" then
      min.width = math.max(min.width, child.reqMinimum.width)
      min.height = min.height + child.reqMinimum.height

      natural.width = math.max(natural.width, child.reqNatural.width)
      natural.height = natural.height + child.reqNatural.height
    elseif self.orientation == "horizontal" then
      min.width = min.width + child.reqMinimum.width
      min.height = math.max(min.height, child.reqMinimum.height)

      natural.width = natural.width + child.reqNatural.width
      natural.height = math.max(natural.height, child.reqNatural.height)
    end
  end

  return Requisition:new(min, natural)
end

function Box:countExpandedChildren()
  local visible = 0
  local expanded = 0

  for _, child in ipairs(self.children) do
    if child.widget.visible then
      visible = visible + 1
      if child.expand then
        expanded = expanded + 1
      end
    end
  end

  return visible, expanded
end

function Box:render(context)
  if self.style and self.style.fill and self.style.bg then
    context:clear(self.style.bg)
  end

  for _, child in ipairs(self.children) do
    if child.widget.visible then
      context:enterRegion(child.allocation)
      child.widget:render(context)
      context:leaveRegion()
    end
  end
end

local function compareGap(sizes, a, b)
  local a_gap = math.max(0, sizes[a.index].natural_size - sizes[a.index].minimum_size)
  local b_gap = math.max(0, sizes[b.index].natural_size - sizes[b.index].minimum_size)
  local delta = b_gap - a_gap

  if delta == 0 then
    delta = b.index - a.index
  end

  return delta
end

function Box:setAllocation(allocation)
  Widget.setAllocation(self, allocation)
  local visible, expanded = self:countExpandedChildren()

  if visible > 0 then
    local size

    if self.orientation == "horizontal" then
      size = allocation.size.width - 2 * self.border - (visible - 1) * self.spacing
    else
      size = allocation.size.height - 2 * self.border - (visible - 1) * self.spacing
    end

    local sizes = {}
    local spreading = {}
    local index = 1

    for _, child in ipairs(self.children) do
      if child.widget.visible then
        local child_size, child_natural
        if self.orientation == "horizontal" then
          child_size, child_natural = child:getWidthForHeight(allocation.size.height)
        else
          child_size, child_natural = child:getHeightForWidth(allocation.size.width)
        end

        size = size - child_size
        size = size - 2 * child.padding
        table.insert(sizes, { minimum_size = child_size, natural_size = child_natural })
        table.insert(spreading, { index = index, child = child })
        index = index + 1
      end
    end

    local extra

    if self.homogeneous then
      if self.orientation == "horizontal" then
        size = allocation.size.width - 2 * self.border - (visible - 1) * self.spacing
      else
        size = allocation.size.height - 2 * self.border - (visible - 1) * self.spacing
      end

      extra = size / visible
    else
      -- Sort the spreading by descending gap and index.
      table.sort(spreading, function(a, b)
        return compareGap(sizes, a, b) < 0
      end)

      for i = visible, 1, -1 do
        local sizing = sizes[spreading[i].index]
        local glue = (size + i) / (i + 1)
        local gap = math.min(glue, sizing.natural_size - sizing.minimum_size)
        sizing.minimum_size = sizing.minimum_size + gap
        size = size - gap
      end

      if expanded > 0 then
        extra = size / expanded
      else
        extra = 0
      end
    end

    local x = 0
    local y = 0
    local child_allocation = Rect.createEmpty()
    local child_size;

    for _, packing in ipairs({ "start", "end" }) do
      if self.orientation == "horizontal" then
        child_allocation.position.row = allocation.position.row + self.border
        child_allocation.size.height = math.max(1, allocation.size.height - 2 * self.border)

        if packing == "start" then
          x = allocation.position.col + self.border
        else
          x = allocation.position.col + allocation.size.width - self.border
        end
      else
        child_allocation.position.col = allocation.position.col + self.border
        child_allocation.size.width = math.max(1, allocation.size.width - 2 * self.border)

        if packing == "start" then
          y = allocation.position.row + self.border
        else
          y = allocation.position.row + allocation.size.height - self.border
        end
      end

      index = 1
      for _, child in ipairs(self.children) do
        if child.widget.visible then
          if child.packing == packing then
            if self.homogeneous then
              if visible == 1 then
                child_size = size
              else
                child_size = extra
              end

              visible = visible - 1
              size = size - extra
            else
              child_size = sizes[index].minimum_size + 2 * child.padding
              if child.expand then
                if expanded == 1 then
                  child_size = child_size + size
                else
                  child_size = child_size + extra
                end

                expanded = expanded - 1
                size = size - extra
              end
            end

            if self.orientation == "horizontal" then
              if child.fill then
                child_allocation.size.width = math.max(1, child_size - 2 * child.padding)
                child_allocation.position.col = x + child.padding
              else
                child_allocation.size.width = sizes[index].minimum_size
                child_allocation.position.col = x + (child_size - child_allocation.size.width) / 2
              end

              if packing == "start" then
                x = x + child_size + self.spacing
              else
                x = x - (child_size + self.spacing)
                child_allocation.position.col = child_allocation.position.col - child_size
              end
            else
              if child.fill then
                child_allocation.size.height = math.max(1, child_size - 2 * child.padding)
                child_allocation.position.row = y + child.padding
              else
                child_allocation.size.height = sizes[index].minimum_size
                child_allocation.position.row = y + (child_size - child_allocation.size.height) / 2
              end

              if packing == "start" then
                y = y + child_size + self.spacing
              else
                y = y - (child_size + self.spacing)
                child_allocation.position.row = child_allocation.position.row - child_size
              end
            end

            child:setAllocation(child_allocation)
          end

          index = index + 1
        end
      end
    end
  end
end

return Box
