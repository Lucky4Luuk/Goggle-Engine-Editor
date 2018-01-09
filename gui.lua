--Some utility functions
math.randomseed(os.clock()+os.time()) --This should probably also be inside the actual engine.
local random = math.random --Otherwise, when exporting your game, it might behave differently, as then it's not seeded by this.
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

--Actual Library
local gui = {}

gui.windows = {}
gui.font = love.graphics.newFont(13)
gui.font:setFilter("nearest", "nearest", 1)
gui.settings = {}
gui.settings.docked_window_width = 48

function gui.add_window(window)
  local id = uuid()
  window.id = id
  window.depth = 0
  if window.docked then
    window.depth = 5
    if window.dockpos == "bottom" then
      window.depth = 6
    elseif window.dockpos == "bar" then
      window.depth = 2
    elseif window.dockpos == "top" then
      window.depth = 3
    elseif window.dockpos == "left-top" or window.dockpos == "right-top" or window.dockpos == "left" or window.dockpos == "right" then
      window.depth = 4
    end
  end
  table.insert(gui.windows, window)
end

function gui.draw_window(window)
  if window.docked then
    local x = 0
    local y = 0
    local w = 0
    local h = 0
    --"left-bottom", "left-top", "left", "right",
    --"right-bottom", "right-top", "top", "bottom" and "bar" are the current docking options
    if window.dockpos == "left-top" then
      x = 0
      y = love.graphics.getHeight()/16
      w = love.graphics.getWidth()/192*gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
    elseif window.dockpos == "left-bottom" then
      x = 0
      y = love.graphics.getHeight()/2 + love.graphics.getHeight()/32
      w = love.graphics.getWidth()/192*gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
    elseif window.dockpos == "right-top" then
      w = love.graphics.getWidth()/192*gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
      x = love.graphics.getWidth() - w
      y = love.graphics.getHeight()/16
    elseif window.dockpos == "right-bottom" then
      w = love.graphics.getWidth()/192*gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
      x = love.graphics.getWidth() - w
      y = love.graphics.getHeight()/2 - love.graphics.getHeight()/16
    elseif window.dockpos == "left" then
      x = 0
      y = love.graphics.getHeight()/16
      w = love.graphics.getWidth()/192*gui.settings.docked_window_width
      h = love.graphics.getHeight() - y
    elseif window.dockpos == "right" then
      w = love.graphics.getWidth()/192*gui.settings.docked_window_width
      x = love.graphics.getWidth() - w
      y = love.graphics.getHeight()/16
      h = love.graphics.getHeight() - y
    elseif window.dockpos == "bar" then
      x = 0
      y = 0
      w = love.graphics.getWidth()
      h = love.graphics.getHeight()/16
    elseif window.dockpos == "bottom" then
      x = love.graphics.getWidth()/192*gui.settings.docked_window_width
      y = love.graphics.getHeight()/3*2
      w = love.graphics.getWidth() - x*2
      h = love.graphics.getHeight() - y
    end
    if window.type == "bar" then
      love.graphics.setColor(window.bgcol.r-0.2, window.bgcol.g-0.2, window.bgcol.b-0.2)
      love.graphics.rectangle("fill",x,y,w,h)
      love.graphics.setColor(0,0,0)
      love.graphics.rectangle("line",x-1,y-1,w+2,h+1)
    else
      love.graphics.setColor(window.bgcol.r, window.bgcol.g, window.bgcol.b)
      love.graphics.rectangle("fill",x,y,w,h)
      love.graphics.setColor(0,0,0)
      love.graphics.rectangle("line",x-1,y-1,w+2,h+2)
      love.graphics.setColor(window.bgcol.r-0.2, window.bgcol.g-0.2, window.bgcol.b-0.2)
      love.graphics.rectangle("fill",x,y,w,gui.font:getHeight()+gui.font:getHeight()/10)
      love.graphics.setColor(window.txtcol.r, window.txtcol.g, window.txtcol.b)
      love.graphics.printf(window.name, x+4, y, w, "left")
    end
  else
    love.graphics.setColor(window.bgcol.r, window.bgcol.g, window.bgcol.b)
    love.graphics.rectangle("fill", window.x, window.y, window.w, window.h)
    love.graphics.setColor(window.bgcol.r-0.1, window.bgcol.g-0.2, window.bgcol.b-0.2)
    love.graphics.rectangle("fill", window.x, window.y, window.w, gui.font:getHeight()+gui.font:getHeight()/10)
    love.graphics.setColor(0,0,0)
    love.graphics.printf(window.name, window.x+4, window.y, window.w, "left")
  end
end

local function window_sort(a, b)
  return a.depth > b.depth
end

function gui.draw()
  table.sort(gui.windows, window_sort)
  love.graphics.setFont(gui.font)
  for i=1, #gui.windows do
    gui.draw_window(gui.windows[i])
  end
end

return gui
