local Assert = require("lib.assert")
local Class = require("lib.class")
local Coord = require("lib.coord")
local Log = require("lib.log")
local Rect = require("lib.rect")
local Size = require("lib.size")
local Theme = require("lib.widget.theme")

local function checkColor(colorOpt, defaultColor)
  if colorOpt ~= nil then
    Assert.assertIs(colorOpt, "number")
    return colorOpt
  end

  return defaultColor
end

local RenderContext = Class("RenderContext")

function RenderContext:init(target, themeOpt)
  local width, height = target.getSize()
  self.target = target
  self.region = Rect.make(0, 0, width, height)
  self.stack = {}
  self.debug = false

  if themeOpt ~= nil then
    self.theme = themeOpt
  else
    self.theme = Theme:new()
  end
end

function RenderContext:updateSize()
  Assert.assert(#self.stack == 0, "Cannot use RenderContext:updateSize() whilst in child region")
  local width, height = self.target.getSize()
  self.region = Rect.make(0, 0, width, height)
end

function RenderContext:enterRegion(region)
  Assert.assertInstance(region, Rect)
  if self.debug then
    Log.info("RenderContext:enterRegion() region =", region)
  end
  table.insert(self.stack, self.region)
  self.region = region
end

function RenderContext:leaveRegion()
  Assert.assert(#self.stack > 0, "RenderContext region underflow")
  local last = self.region
  self.region = table.remove(self.stack, 1)
  return last
end

function RenderContext:getSize()
  return self.region.size
end

function RenderContext:getWidth()
  return self.region.size.width
end

function RenderContext:getHeight()
  return self.region.size.height
end

function RenderContext:transformCoordAndCheck(coord)
  if coord.row < 0 or coord.col < 0 then
    return nil
  end

  if coord.row > self.region.size.height then
    return nil
  end

  if coord.col > self.region.size.width then
    return nil
  end

  local row = coord.row + self.region.position.row
  local col = coord.col + self.region.position.col
  return Coord:new(row, col)
end

function RenderContext:transformRectAndClip(rect)
  local clipped = false

  local row = rect.position.row
  if row < 0 then
    row = 0
    clipped = true
  end

  local col = rect.position.col
  if col < 0 then
    col = 0
    clipped = true
  end

  local width = rect.size.width
  if col + width > self.region.size.width then
    width = self.region.size.width - col
    clipped = true
  end

  local height = rect.size.height
  if row + height > self.region.size.height then
    height = self.region.size.height - row
    clipped = true
  end

  row = row + self.region.position.row
  col = col + self.region.position.col

  return Rect:new(Coord:new(row, col), Size:new(width, height)), clipped
end

function RenderContext:renderPixel(position, colorOpt)
  Assert.assertInstance(position, Coord)
  position = self:transformCoordAndCheck(position)
  if position == nil then
    return
  end

  local color = color.white
  if colorOpt ~= nil then
    Assert.assertIs(colorOpt, "number")
    color = colorOpt
  end

  self.target.setBackgroundColor(color)
  self.target.setCursorPos(position.col + 1, position.row + 1)
  self.target.write(" ")
end

function RenderContext:renderRect(rect, colorOpt)
  Assert.assertInstance(rect, Rect)
  local color = checkColor(colorOpt, colors.white)

  -- Transform and clip the Rect to the draw region and discard degenerate results.
  local drawRect, clipped = self:transformRectAndClip(rect)
  if self.debug and clipped then
    Log.info(("RenderContext:renderRect() clipped %s to %s"):format(rect, drawRect))
  end

  if drawRect.size.width < 1 or drawRect.size.height < 1 then
    if self.debug then
      Log.info(("RenderContext:renderRect() draw rect %s is degenerate"):format(drawRect))
    end

    return
  end

  if self.debug then
    Log.info(("RenderContext:renderRect() drawRect = %s"):format(drawRect))
  end

  -- Fill in lines for each row of the draw rect
  local lineStr = (" "):rep(drawRect.size.width)
  local colorStr = colors.toBlit(color):rep(drawRect.size.width)
  for y = drawRect.position.row, drawRect.position.row + drawRect.size.height - 1 do
    self.target.setCursorPos(drawRect.position.col + 1, y + 1)
    self.target.blit(lineStr, colorStr, colorStr)
  end
end

function RenderContext:clear(colorOpt)
  Log.info(("RenderContext:clear(%s): region = %s"):format(colorOpt, self.region))
  self:renderRect(Rect:new(Coord:new(0, 0), self.region.size), checkColor(colorOpt, colors.black))
end

function RenderContext:renderString(position, content, fgColorOpt, bgColorOpt)
  Assert.assertInstance(position, Coord)

  if #content < 1 then
    return
  end

  -- Create a Rect that describes the region for the string, then transform and clip it.
  local rect = Rect:new(position, Size:new(#content, 1))
  local drawRect, clipped = self:transformRectAndClip(rect)
  if self.debug and clipped then
    Log.info(("RenderContext:renderString() clipped %s to %s"):format(rect, drawRect))
  end

  if drawRect.size.width < 1 or drawRect.size.height < 1 then
    if self.debug then
      Log.info(("RenderContext:renderString() draw rect %s is degenerate"):format(drawRect))
    end

    return
  end

  -- Due to clipping, we might need to truncate our string
  if drawRect.size.width < #content then
    content = content:sub(1, drawRect.size.width)
  end

  local fgColor = checkColor(fgColorOpt, colors.white)
  local bgColor = checkColor(bgColorOpt, colors.black)

  self.target.setCursorPos(drawRect.position.col + 1, drawRect.position.row + 1)
  self.target.setBackgroundColor(bgColor)
  self.target.setTextColor(fgColor)
  self.target.write(content)
end

return RenderContext
