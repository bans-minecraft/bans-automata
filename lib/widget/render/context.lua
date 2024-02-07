local Assert = require("lib.assert")
local Class = require("lib.class")
local Rect = require("lib.rect")
local Coord = require("lib.coord")

local RenderContext = Class("RenderContext")

local function sortCoords(position, size)
  local startX = position.col
  local endX = startX + size.width - 1

  local startY = position.row
  local endY = startY + size.height - 1

  local minX, maxX, minY, maxY

  if startX <= endX then
    minX, maxX = startX, endX
  else
    minX, maxX = endX, startX
  end

  if startY <= endY then
    minY, maxY = startY, endY
  else
    minY, maxY = endY, startY
  end

  return minX, maxX, minY, maxY
end

function RenderContext:init()
end

function RenderContext:_renderPixelInternal(x, y)
  term.setCursorPos(x, y)
  term.write(" ")
end

function RenderContext:renderRect(rect, colorOpt)
  Assert.assertInstance(rect, Rect)
  local color = colors.black
  if colorOpt ~= nil then
    Assert.assertIs(colorOpt, "number")
    color = colorOpt
  end

  if rect.size.width == 0 and rect.size.height == 0 then
    self:_renderPixelInternal(rect.position.col, rect.position.row)
    term.setCursorPos(rect.position.col, rect.position.row)
    term.setBackgroundColor(color)
    term.write(" ")
    return
  end

  color = colors.toBlit(color)

  local minX, maxX, minY, maxY = sortCoords(rect.position, rect.size)
  local width = maxX - minX + 1

  for y = minY, maxY do
    term.setCursorPos(minX, y)
    term.blit((" "):rep(width), color:rep(width), color:rep(width))
  end
end

function RenderContext:renderString(position, content, bgColorOpt, fgColorOpt)
  Assert.assertInstance(position, Coord)
  local fgColor = colors.write
  local bgColor = colors.black

  if fgColorOpt ~= nil then
    Assert.assertIs(fgColorOpt, "number")
    fgColor = fgColorOpt
  end

  if bgColorOpt ~= nil then
    Assert.assertIs(bgColorOpt, "number")
    bgColor = bgColorOpt
  end

  term.setCursorPos(position.col, position.row)
  term.setBackgroundColor(bgColor)
  term.setTextColor(fgColor)
  term.write(content)
end

return RenderContext
