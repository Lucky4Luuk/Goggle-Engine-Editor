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
gui.font = love.graphics.newFont("assets/SourceSansPro-Regular.ttf",18) --The default love2d font works best at size 13
gui.font:setFilter("nearest", "nearest", 1)
gui.settings = {}
gui.settings.docked_window_width = 256
gui.gamecanvas = {}
gui.gamecanvas.offset = 0
gui.console_max_lines = 10
gui.objects = {}
gui.mode = "editor"

local cur_edit = nil

local console_height = 0

function gui.get_game_canvas()
  if gui.mode == "editor" or gui.mode == "editor_start" then
    local w = love.graphics.getWidth() - 2*gui.settings.docked_window_width
    local h = w / 16 * 9
    if h > love.graphics.getHeight()/3 * 2 - love.graphics.getHeight()/16 then
      h = love.graphics.getHeight()/3 * 2 - love.graphics.getHeight()/16
      w = h / 9 * 16
      gui.gamecanvas.offset = h / 4
    else
      gui.gamecanvas.offset = 0
    end
    return love.graphics.newCanvas(w, h)
  else
    local h = love.graphics.getHeight() - love.graphics.getHeight()/16
    local w = h / 9 * 16
    gui.gamecanvas.offset = (love.graphics.getWidth() - w)/2
    return love.graphics.newCanvas(w, h)
  end
end

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
    if window.dockpos == "left-top" and gui.mode == "editor" then
      x = 0
      y = love.graphics.getHeight()/16
      w = gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
    elseif window.dockpos == "left-bottom" and gui.mode == "editor" then
      x = 0
      y = love.graphics.getHeight()/2 + love.graphics.getHeight()/32
      w = gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
    elseif window.dockpos == "right-top" and gui.mode == "editor" then
      w = gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
      x = love.graphics.getWidth() - w
      y = love.graphics.getHeight()/16
    elseif window.dockpos == "right-bottom" and gui.mode == "editor" then
      w = gui.settings.docked_window_width
      h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
      x = love.graphics.getWidth() - w
      y = love.graphics.getHeight()/2 - love.graphics.getHeight()/16
    elseif window.dockpos == "left" and gui.mode == "editor" then
      x = 0
      y = love.graphics.getHeight()/16
      w = gui.settings.docked_window_width
      h = love.graphics.getHeight() - y
    elseif window.dockpos == "right" and gui.mode == "editor" then
      w = gui.settings.docked_window_width
      x = love.graphics.getWidth() - w
      y = love.graphics.getHeight()/16
      h = love.graphics.getHeight() - y
    elseif window.dockpos == "bar" then
      x = 0
      y = 0
      w = love.graphics.getWidth()
      h = love.graphics.getHeight()/16
    elseif window.dockpos == "bottom" and gui.mode == "editor" then
      x = gui.settings.docked_window_width
      y = love.graphics.getHeight()/3*2
      w = love.graphics.getWidth() - x*2
      h = love.graphics.getHeight()/3
    end
    if window.type == "bar" then
      love.graphics.setColor(window.bgcol.r-0.2, window.bgcol.g-0.2, window.bgcol.b-0.2)
      love.graphics.rectangle("fill",x,y,w,h)
      love.graphics.setColor(0,0,0)
      love.graphics.rectangle("line",x-1,y-1,w+2,h+1)
      love.graphics.setColor(window.bgcol.r-0.4, window.bgcol.g-0.4, window.bgcol.b-0.4)
      love.graphics.line(w/12, y, w/12, y+h)
      love.graphics.line(w/6, y, w/6, y+h)
      love.graphics.setColor(window.bgcol.r+0.4, window.bgcol.g+0.4, window.bgcol.b+0.4)
      love.graphics.polygon("fill", x+w/48,y+h/24, x+w/12-w/48,y+h/2, x+w/48,y+h-h/24)
      love.graphics.rectangle("fill", x+w/12+w/36,y+h/6, w/48, h - h/3)
    elseif gui.mode == "editor" then
      love.graphics.setColor(window.bgcol.r, window.bgcol.g, window.bgcol.b)
      love.graphics.rectangle("fill",x,y,w,h)
      love.graphics.setColor(0,0,0)
      love.graphics.rectangle("line",x-1,y-1,w+2,h+2)
      love.graphics.setColor(window.bgcol.r-0.2, window.bgcol.g-0.2, window.bgcol.b-0.2)
      love.graphics.rectangle("fill",x,y,w,gui.font:getHeight()+gui.font:getHeight()/10)
      love.graphics.setColor(window.txtcol.r, window.txtcol.g, window.txtcol.b)
      love.graphics.printf(window.name, x+4, y, w, "left")
    end
    if window.type == "console" and gui.mode == "editor" then
      local dy = (gui.font:getHeight() + gui.font:getHeight()/10)
      console_height = h - dy*2
      love.graphics.setColor(0,0,0)
      love.graphics.rectangle("fill", x, y + dy, w, h - dy)
      love.graphics.setColor(1,1,1)
      for i=math.max(#console_log - gui.console_max_lines, 1), #console_log do
        love.graphics.print(console_log[i], x+4, y + dy)
        dy = dy + gui.font:getHeight() + gui.font:getHeight()/10
      end
    elseif window.type == "scenebrowser" and gui.mode == "editor" then
      local dy = gui.font:getHeight() + gui.font:getHeight()/10
      for i=1, #gui.objects do
        if gui.objects[i].uuid then
          if selected_object == gui.objects[i].uuid then
            love.graphics.setColor(window.bgcol.r + 0.2, window.bgcol.g + 0.2, window.bgcol.b + 0.2)
            love.graphics.rectangle("fill", x, y + dy, w, gui.font:getHeight() + gui.font:getHeight()/10)
          end
          love.graphics.setColor(window.txtcol.r, window.txtcol.g, window.txtcol.b)
          love.graphics.print(gui.objects[i].name, x+4, y + dy)
          dy = dy + gui.font:getHeight() + gui.font:getHeight()/10
        end
      end
    elseif window.type == "objecteditor" and gui.mode == "editor" then
      --Draw info
      if selected_object ~= "" then
        local cur_object = nil
        for i=1, #gui.objects do
          if gui.objects[i].uuid == selected_object then
            cur_object = gui.objects[i]
            break
          end
        end
        local dy = y + gui.font:getHeight() + gui.font:getHeight()/10
        -- love.graphics.setColor(window.bgcol.r - 0.1, window.bgcol.g - 0.1, window.bgcol.b - 0.1)
        -- love.graphics.rectangle("fill", x+gui.font:getWidth("X:   "), dy, gui.font:getWidth(tostring(cur_object.pos[1]))+6, gui.font:getHeight())
        -- love.graphics.setColor(0.1,0.1,0.1)
        -- love.graphics.rectangle("line", x+gui.font:getWidth("X:   "), dy, gui.font:getWidth(tostring(cur_object.pos[1]))+6, gui.font:getHeight())
        -- love.graphics.setColor(window.txtcol.r, window.txtcol.g, window.txtcol.b)
        -- love.graphics.print("X:   "..tostring(cur_object.pos[1]), x+4, dy)
        -- dy = dy + gui.font:getHeight() + gui.font:getHeight()/10
        for i=1, #window.fields do
          local field = window.fields[i]

          --Draw the field
          if field.type == "vector3" then
            local tw = (w - w/6) / 3

            love.graphics.print(field.name, x+4, dy)

            dy = dy + gui.font:getHeight() + gui.font:getHeight()/10

            love.graphics.setColor(window.bgcol.r - 0.1, window.bgcol.g - 0.1, window.bgcol.b - 0.1)
            love.graphics.rectangle("fill", x+w/16, dy, tw, gui.font:getHeight())
            love.graphics.rectangle("fill", x+tw+w/8, dy, tw, gui.font:getHeight())
            love.graphics.rectangle("fill", x+tw*2+w/(5+1/3), dy, tw, gui.font:getHeight())

            love.graphics.setColor(0.1,0.1,0.1)
            love.graphics.rectangle("line", x+w/16, dy, tw, gui.font:getHeight())
            love.graphics.rectangle("line", x+tw+w/8, dy, tw, gui.font:getHeight())
            love.graphics.rectangle("line", x+tw*2+w/(5+1/3), dy, tw, gui.font:getHeight())

            love.graphics.setColor(window.txtcol.r, window.txtcol.g, window.txtcol.b)
            love.graphics.print("X:", x+2, dy)
            love.graphics.print("Y:", x+2+tw+w/16, dy)
            love.graphics.print("Z:", x+2+tw*2+w/8, dy)

            if field.tag == "pos" then
              love.graphics.printf(round(cur_object.pos[1], 2), x+w/16, dy, tw, "right")
              love.graphics.printf(round(cur_object.pos[2], 2), x+tw+w/8, dy, tw, "right")
              love.graphics.printf(round(cur_object.pos[3], 2), x+tw*2+w/(5+1/3), dy, tw, "right")
            elseif field.tag == "rot" then
              if cur_object.rot then
                love.graphics.printf(round(cur_object.rot.x, 2), x+w/16, dy, tw, "right")
                love.graphics.printf(round(cur_object.rot.y, 2), x+tw+w/8, dy, tw, "right")
                love.graphics.printf(round(cur_object.rot.z, 2), x+tw*2+w/(5+1/3), dy, tw, "right")
              else
                love.graphics.printf(0, x+w/16, dy, tw, "right")
                love.graphics.printf(0, x+tw+w/8, dy, tw, "right")
                love.graphics.printf(0, x+tw*2+w/(5+1/3), dy, tw, "right")
              end
            end

            dy = dy + gui.font:getHeight() + gui.font:getHeight()/10
          end
        end
      end
    end
  elseif gui.mode == "editor" then
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

function gui.textinput(t)

end

function gui.mousepressed(x, y, button, isTouch)
  local found = false
  for i=1, #gui.windows do
    if found then break end
    local window = gui.windows[i]
    if window.docked then
      local x = 0
      local y = 0
      local w = 0
      local h = 0
      --"left-bottom", "left-top", "left", "right",
      --"right-bottom", "right-top", "top", "bottom" and "bar" are the current docking options
      if window.dockpos == "left-top" and gui.mode == "editor" then
        x = 0
        y = love.graphics.getHeight()/16
        w = gui.settings.docked_window_width
        h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
      elseif window.dockpos == "left-bottom" and gui.mode == "editor" then
        x = 0
        y = love.graphics.getHeight()/2 + love.graphics.getHeight()/32
        w = gui.settings.docked_window_width
        h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
      elseif window.dockpos == "right-top" and gui.mode == "editor" then
        w = gui.settings.docked_window_width
        h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
        x = love.graphics.getWidth() - w
        y = love.graphics.getHeight()/16
      elseif window.dockpos == "right-bottom" and gui.mode == "editor" then
        w = gui.settings.docked_window_width
        h = love.graphics.getHeight()/2 - love.graphics.getHeight()/32
        x = love.graphics.getWidth() - w
        y = love.graphics.getHeight()/2 - love.graphics.getHeight()/16
      elseif window.dockpos == "left" and gui.mode == "editor" then
        x = 0
        y = love.graphics.getHeight()/16
        w = gui.settings.docked_window_width
        h = love.graphics.getHeight() - y
      elseif window.dockpos == "right" and gui.mode == "editor" then
        w = gui.settings.docked_window_width
        x = love.graphics.getWidth() - w
        y = love.graphics.getHeight()/16
        h = love.graphics.getHeight() - y
      elseif window.dockpos == "bar" then
        x = 0
        y = 0
        w = love.graphics.getWidth()
        h = love.graphics.getHeight()/16
      elseif window.dockpos == "bottom" and gui.mode == "editor" then
        x = gui.settings.docked_window_width
        y = love.graphics.getHeight()/3*2
        w = love.graphics.getWidth() - x*2
        h = love.graphics.getHeight()/3
      end
      if window.type == "bar" then
        --Bar
        if love.mouse.getX() < w/12 then
          gui.mode = "play_start"
        elseif love.mouse.getX() < w/6 then
          gui.mode = "editor_start"
        end
      elseif window.type == "scenebrowser" and gui.mode == "editor" then
        local dy = gui.font:getHeight() + gui.font:getHeight()/10
        if love.mouse.getX() > x+3 and love.mouse.getX() < w+1 then
          if love.mouse.getY() > y + dy * (#gui.objects+1) then
            selected_object = ""
            found = true
            break
          end
          for i=1, #gui.objects do
            if love.mouse.getY() > y + dy and love.mouse.getY() < y + dy + gui.font:getHeight() + gui.font:getHeight()/10 then
              --Select this object
              selected_object = gui.objects[i].uuid
              found = true
            end
            dy = dy + gui.font:getHeight() + gui.font:getHeight()/10
          end
        end
      end
    elseif gui.mode == "editor" then
      --Floating window
    end
  end
end

function gui.draw()
  table.sort(gui.windows, window_sort)
  love.graphics.setFont(gui.font)
  for i=1, #gui.windows do
    gui.draw_window(gui.windows[i])
  end
end

function gui.resize(w, h)
  gui.console_max_lines = math.floor(h / console_height)
end

return gui
