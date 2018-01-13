math.randomseed(os.clock()+os.time())
local random = math.random
function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

--https://github.com/davidm/lua-matrix
local matrix = require "engine.matrix"

function genMainShader()
  local lines = {}
  for line in io.lines("engine/shaders/fragment_pre.glsl") do
    table.insert(lines, line)
  end
  for line in io.lines("engine/shaders/mercury_hg_sdf_functions.glsl") do
    table.insert(lines, line)
  end
  for line in io.lines("engine/shaders/fragment.glsl") do
    table.insert(lines, line)
  end
  local file = io.open("engine/shaders/temp.glsl","w+")
  io.output(file)
  for i=1, #lines do
    io.write(lines[i].."\n")
  end
  file:close()
end

local function getRotMatX(a)
  local c = math.cos(a)
  local s = math.sin(a)
  local m = matrix {{1, 0, 0}, {0, c, s}, {0, -s, c}}
  return m
end

local function getRotMatY(a)
  local c = math.cos(a)
  local s = math.sin(a)
  local m = matrix {{c, 0, -s}, {0, 1, 0}, {s, 0, c}}
  return m
end

local function getRotMatZ(a)
  local c = math.cos(a)
  local s = math.sin(a)
  local m = matrix {{c, -s, 0}, {s, c, 0}, {0, 0, 1}}
  return m
end

function getRotationMatrix(x, y, z)
  --[[mat3 rotate3DX(float a) {
    float c = cos(a);
    float s = sin(a);
    mat3 m;
    m[0] = vec3(1.0,0.0,0.0);
    m[1] = vec3(0.0,  c,  s);
    m[2] = vec3(0.0, -s,  c);
    return m;
  }
  mat3 rotate3DY(float a) {
    float c = cos(a);
    float s = sin(a);
    mat3 m;
    m[0] = vec3(  c,0.0, -s);
    m[1] = vec3(0.0,1.0,0.0);
    m[2] = vec3(  s,0.0,  c);
    return m;
  }
  mat3 rotate3DZ(float a) {
    float c = cos(a);
    float s = sin(a);
    mat3 m;
    m[0] = vec3(  c, -s,0.0);
    m[1] = vec3(  s,  c,0.0);
    m[2] = vec3(0.0,0.0,1.0);
    return m;
  }
  mat3 rotate3D(float x,float y,float z) { return rotate3DX(x)*rotate3DY(y)*rotate3DZ(z); }]]
  local mx = getRotMatX(math.rad(x))
  local my = getRotMatY(math.rad(y))
  local mz = getRotMatZ(math.rad(z))
  local mr = mx * my * mz
  return mr^-1
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

function string.split(String,sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   String:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function lines_from(file)
  if not file_exists(file) then return {} end
  lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
  end
  return lines
end

function isNaN( v ) return type( v ) == "number" and v ~= v end

function getAvgTexCol(tex)
  local c = love.graphics.newCanvas(1,1)
  love.graphics.setCanvas(c)
  love.graphics.push()
  love.graphics.scale(1/tex:getWidth(), 1/tex:getHeight())
  love.graphics.draw(tex)
  love.graphics.pop()
  love.graphics.setCanvas()
  local r, g, b, a = c:newImageData():getPixel(0,0)
  return {r, g, b}
end

function prerequire(name)
  local status, lib = pcall(require, name)
  if (status) then return lib end
  print("Script ".. tostring(name:gsub("%.","/")).." doesn't exist!")
  return nil
end
