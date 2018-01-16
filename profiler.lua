require "profiler_lib"

local pf = {}

local ram_log = {}
local vram_log = {}

local log_length = 250

local max_ram = 0
local max_vram = 0

function pf.setLogLength(n)
  log_length = n
end

function pf.start()
  profilerStart()
end

function pf.stop()
  profilerStop()
end

function pf.reset()
  ram_log = {}
  vram_log = {}
end

function pf.report(filename)
  profilerReport(filename)
end

function pf.draw(x,y, w,h)
  love.graphics.push()
  love.graphics.setColor(0.4,0.4,0.4,0.4)
  love.graphics.rectangle("fill",x,y, w,h)
  love.graphics.setColor(1,1,1,1)
  love.graphics.line(x+5,y, x+w-10, y)
  love.graphics.line(x+5,y + h/4, x+w-10, y + h/4)
  love.graphics.line(x+5,y + h/2, x+w-10, y + h/2)

  love.graphics.print(max_ram, x, y)
  love.graphics.print(max_ram/4*3, x, y + h/4)
  love.graphics.print(max_ram/2, x, y + h/2)
  love.graphics.print(max_ram/4, x, y + h/4*3)
  love.graphics.print(0, x, y+h)

  love.graphics.print(max_vram, x+w-10, y)
  love.graphics.print(max_vram/4*3, x+w-10, y + h/4)
  love.graphics.print(max_vram/2, x+w-10, y + h/2)
  love.graphics.print(max_vram/4, x+w-10, y + h/4*3)
  love.graphics.print(0, x+w-10, y+h)

  love.graphics.setColor(0.5,0.5,1,1)
  local points = {}
  for i=1, #ram_log do
    local px = x + map_to_range(i, 1, #ram_log, 0, w)
    local py = y + (h - map_to_range(ram_log[i], 0, max_ram, 0, h))
    table.insert(points, px)
    table.insert(points, py)
  end
  if #points > 3 then
    love.graphics.line(points)
  end

  love.graphics.setColor(0.8,0.5,0.5,1)
  points = {}
  for i=1, #vram_log do
    local px = map_to_range(i, 1, #vram_log, x, x+w)
    local py = y + (h - map_to_range(vram_log[i], 0, max_vram, 0, h))
    table.insert(points, px)
    table.insert(points, py)
  end
  if #points > 3 then
    love.graphics.line(points)
  end

  love.graphics.pop()
end

function pf.update()
  profilerCheckMemory()
  profilerCheckGraphicsMemory()
  local ram_usage = profilerAccessMemory()
  local vram_usage = profilerAccessGraphicsMemory()
  ram_usage = tonumber(ram_usage:sub(1, #ram_usage-5))
  vram_usage = tonumber(vram_usage:sub(1, #vram_usage-5))
  max_ram = math.max(max_ram, ram_usage)
  max_vram = math.max(max_vram, vram_usage)
  table.insert(ram_log, ram_usage)
  table.insert(vram_log, vram_usage)
  while #ram_log > log_length do
    table.remove(ram_log,1)
  end
  while #vram_log > log_length do
    table.remove(vram_log,1)
  end
end

return pf
