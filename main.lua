local engine = require "engine.main"
local matrix = require "engine.matrix"

local transform_arrows = {}
transform_arrows.x_arrow = {x=-5000, y=-5000} --Stores worldposition of the 2 points of the arrow.
local arrow_drag = {down=false,x=0,y=0}

console = {} --Console "library". Not imported, but these functions can be passed to the engine itself, to report back to the console. Not local so the engine can use it.
console_log = {} --Log of the console. Not local so the GUI library can use it.
selected_object = "" --Name of the currently selected object.

local gamecanvas = nil

local mode = "editor"

local gui = require "gui"

local theme = "dark"

local default_bg_col = {r=1, g=1, b=1}
local default_txt_col = {r=0, g=0, b=0}

if theme == "dark" then
  default_bg_col = {r=0.3, g=0.3, b=0.3}
  default_txt_col = {r=1, g=1, b=1}
end

function console.print(str)
  table.insert(console_log, tostring(str))
end

function love.load()
  --Initialize W for neater code down below
  local w = nil

  -- w = {name="Testing window!",x=150,y=50,w=love.graphics.getWidth()-love.graphics.getWidth()/8,h=love.graphics.getHeight()-love.graphics.getHeight()/6}
  -- w.bgcol = {r=1,g=1,b=1}
  -- gui.add_window(w)

  w = {name="File Browser", dockpos="left-bottom", docked=true, type="filebrowser"}
  w.bgcol = default_bg_col
  w.txtcol = default_txt_col
  gui.add_window(w)

  w = {name="Scene Browser", dockpos="left-top", docked=true, type="scenebrowser"} --The scenebrowser type just means a scrollable window (vertical only) with a list of items that are clickable
  w.bgcol = default_bg_col
  w.txtcol = default_txt_col
  gui.add_window(w)

  w = {name="Object Editor", dockpos="right", docked=true, type="objecteditor"}
  w.bgcol = default_bg_col
  w.txtcol = default_txt_col
  gui.add_window(w)

  w = {name="Top Bar", dockpos="bar", docked=true, type="bar"}
  w.bgcol = default_bg_col
  w.txtcol = default_txt_col
  gui.add_window(w)

  w = {name="Console", dockpos="bottom", docked=true, type="console"} --The console type just means a scrollable window that contains non-editable text in the form of a table containing all the lines.
  w.bgcol = default_bg_col --Note: scrolling isn't implemented yet. It will autoscroll for now.
  w.txtcol = default_txt_col
  gui.add_window(w)

  engine.gamecanvas = gui.get_game_canvas()
  engine.mouse = {x=0, y=0}
  engine.center = {x=love.graphics.getWidth()/2, y=love.graphics.getHeight()/2}
  engine.load()
  engine.update(0)

  love.window.setMode(love.graphics.getWidth(), love.graphics.getHeight(), {vsync=false, resizable=true})
end

function love.update(dt)
  gui.objects = engine.objects
  if mode == "editor" then
    engine.mouse.x = love.mouse.getX()
    engine.mouse.y = love.mouse.getY()
    if love.mouse.isDown(2) then
      engine.mouse.right = true
    else
      engine.mouse.right = false
    end
    if love.mouse.isDown(1) then
      arrow_drag.down = true
      checkTransformArrows(love.mouse.getX(), love.mouse.getY())
    else
      arrow_drag.down = false
    end
    engine.update(dt)
    -- if selected_object ~= "" then
    --   --Show transform arrows
    --   --First test:
    --   local pos = {x=0,y=0,z=0}
    --   local rot = {x=0,y=0,z=0}
    --   for i=1, #engine.objects do
    --     if engine.objects[i].uuid == selected_object then
    --       rot.x = engine.objects[i].rot.x
    --       rot.y = engine.objects[i].rot.y
    --       rot.z = engine.objects[i].rot.z
    --     end
    --   end
    -- end
  end
end

function love.mousepressed(x, y, button, isTouch)
  engine.mousepressed(x, y, button, isTouch)
  gui.mousepressed(x, y, button, isTouch)
  if button == 1 then
    arrow_drag.x = x
    arrow_drag.y = y
  end
end

function love.draw()
  gui.draw()
  love.graphics.push()
  love.graphics.setCanvas(engine.gamecanvas)
  engine.draw()
  love.graphics.setCanvas()
  love.graphics.translate(gui.settings.docked_window_width + gui.gamecanvas.offset, love.graphics.getHeight()/16)
  love.graphics.draw(engine.gamecanvas)
  love.graphics.pop()
  drawTransformArrows()
end

function love.resize(w, h)
  engine.gamecanvas = gui.get_game_canvas()
  engine.center = {x=w/2, y=h/2}
  engine.render_target.width = w
  engine.render_target.height = w
  engine.setTargetResolution(engine.gamecanvas:getWidth(), engine.gamecanvas:getHeight())
  engine.resize(engine.gamecanvas:getWidth(), engine.gamecanvas:getHeight())
  --gui.resize(w, h) --Broken as of now
end

function moveObject(dir, amount)
  --console.print(dir .. ": " .. tostring(amount))
  if selected_object ~= "" then
    for i=1, #engine.objects do
      if engine.objects[i].uuid == selected_object then
        if dir == "x" then
          engine.objects[i].pos[1] = engine.objects[i].pos[1] + amount
        elseif dir == "y" then
          engine.objects[i].pos[2] = engine.objects[i].pos[2] + amount
        elseif dir == "z" then
          engine.objects[i].pos[3] = engine.objects[i].pos[3] + amount
        end
      end
    end
  end
end

function checkTransformArrows(x, y)
  local lx = x - gui.settings.docked_window_width - gui.gamecanvas.offset - engine.gamecanvas:getWidth()
  local ly = y - love.graphics.getHeight()/8

  lx = lx / (love.graphics.getWidth()/60)
  ly = ly / (love.graphics.getWidth()/60)

  local mx = arrow_drag.x - gui.settings.docked_window_width - gui.gamecanvas.offset - engine.gamecanvas:getWidth()
  local my = arrow_drag.y - love.graphics.getHeight()/8

  local r = -math.pi

  local my1 = my * math.cos(r) + mx * math.sin(r)
  my1 = my1 / (love.graphics.getWidth()/60)

  local lx1 = lx * math.cos(r) - ly * math.sin(r)
  local ly1 = ly * math.cos(r) + lx * math.sin(r)


  if ly1 > 0 and ly1 < 3.3 and lx1 > -0.65 and lx1 < 0.65 then
    local dy = (ly1 - my1)
    moveObject("y", dy)
  end

  r = -math.pi + math.rad(125)

  local my2 = my * math.cos(r) + mx * math.sin(r)
  my2 = my2 / (love.graphics.getWidth()/60)

  local lx2 = lx * math.cos(r) - ly * math.sin(r)
  local ly2 = ly * math.cos(r) + lx * math.sin(r)

  if ly2 > 0 and ly2 < 3.3 and lx2 > -0.65 and lx2 < 0.65 then
    local dy = (ly2 - my2) * -1
    moveObject("x", dy)
  end

  r = -math.pi - math.rad(125)

  local my3 = my * math.cos(r) + mx * math.sin(r)
  my3 = my3 / (love.graphics.getWidth()/60)

  local lx3 = lx * math.cos(r) - ly * math.sin(r)
  local ly3 = ly * math.cos(r) + lx * math.sin(r)

  if ly3 > 0 and ly3 < 3.3 and lx3 > -0.65 and lx3 < 0.65 then
    local dy = (ly3 - my3) * -1
    moveObject("z", dy)
  end

  arrow_drag.x = x
  arrow_drag.y = y
end

function drawTransformArrows()
  love.graphics.push()

  love.graphics.translate(gui.settings.docked_window_width + gui.gamecanvas.offset + engine.gamecanvas:getWidth(), love.graphics.getHeight()/8)
  love.graphics.scale(love.graphics.getWidth()/60, love.graphics.getWidth()/60)

  love.graphics.rotate(math.pi)
  love.graphics.setColor(0.2,1,0.2)
  love.graphics.polygon("fill", 0,3.3, 0.65,2, 0.35,2, 0.35,0, -0.35,0, -0.35,2, -0.65,2)
  love.graphics.rotate(math.rad(125))
  love.graphics.setColor(0.2,0.2,1)
  love.graphics.polygon("fill", 0,3.3, 0.65,2, 0.35,2, 0.35,0, -0.35,0, -0.35,2, -0.65,2)
  love.graphics.rotate(math.rad(110))
  love.graphics.setColor(1,0.2,0.2)
  love.graphics.polygon("fill", 0,3.3, 0.65,2, 0.35,2, 0.35,0, -0.35,0, -0.35,2, -0.65,2)

  love.graphics.setColor(1,1,1)
  love.graphics.ellipse("fill", 0, 0, 0.6, 0.6)

  love.graphics.pop()
end
