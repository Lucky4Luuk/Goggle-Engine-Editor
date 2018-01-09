local gui = require "gui"

local theme = "dark"

local default_bg_col = {r=1, g=1, b=1}
local default_txt_col = {r=0, g=0, b=0}

if theme == "dark" then
  default_bg_col = {r=0.3, g=0.3, b=0.3}
  default_txt_col = {r=1, g=1, b=1}
end

function love.load()
  local w = nil

  -- w = {name="Testing window!",x=150,y=50,w=love.graphics.getWidth()-love.graphics.getWidth()/8,h=love.graphics.getHeight()-love.graphics.getHeight()/6}
  -- w.bgcol = {r=1,g=1,b=1}
  -- gui.add_window(w)

  w = {name="File Browser", dockpos="left-bottom", docked=true, type="filebrowser"}
  w.bgcol = default_bg_col
  w.txtcol = default_txt_col
  gui.add_window(w)

  w = {name="Scene Browser", dockpos="left-top", docked=true, type="scenebrowser"}
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

  w = {name="Console", dockpos="bottom", docked=true, type="console"}
  w.bgcol = default_bg_col
  w.txtcol = default_txt_col
  gui.add_window(w)
end

function love.draw()
  gui.draw()
end
