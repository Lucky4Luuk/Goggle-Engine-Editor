local width = 800
local height = 480
local iTime = 0
local iTimeDelta = 0
local canvas = nil
local cam_dir = {1,0,0}
local cam_pos = {3,1,0}
local shader = nil
local fxaa = nil
local sensitivityX = 0.5
local sensitivityY = 0.5

local FLAGS = {AA=true}

local MODE = "game"

function setCamera(pos, dir)
  cam_pos = pos
  cam_dir = dir
end

function setMode(m)
  MODE = m
end

function setRenderSize(w, h)
  width = w
  height = h
  return true
end

function updateAtlas(tex_atlas, bump_atlas)
  send("tex_atlas", tex_atlas)
  send("bump_atlas", bump_atlas)
end

function updateObjectsList(objects, meshes)
	local obj_amount = 0

  for i, o in ipairs(meshes) do
    send("meshes["..tostring(i).."]", meshes[i])
  end

	for i, o in ipairs(objects) do
		local alpha = o.alpha/255
		local t = 0
		--local c = {o[4][1]/255,o[4][2]/255,o[4][3]/255}
    local c = {o.color[1]/255, o.color[2]/255, o.color[3]/255}
		if o.t == "Plane" then
			t = 1
		elseif o.t == "Sphere" then
			t = 2
		elseif o.t == "uBox" then
			t = 3
		elseif o.t == "Box" then
			t = 4
		elseif o.t == "Mesh" then
      t = 5
      send("objects["..tostring(obj_amount).."].tex_offset", o.tex_offset)
    end
    if o.t ~= "Plane" then
      local mr = getRotationMatrix(o.rot.x, o.rot.y, o.rot.z)
      send("objects["..tostring(obj_amount).."].r", mr)
    end
    send("objects["..tostring(obj_amount).."].avg_tex_col", o.tex_col)
    send("objects["..tostring(obj_amount).."].roughness", o.roughness)
    send("objects["..tostring(obj_amount).."].metallic", o.metallic)
    if o.tex then
      send("objects["..tostring(obj_amount).."].isTextured", true)
      send("objects["..tostring(obj_amount).."].texsize", o.texsize)
      send("objects["..tostring(obj_amount).."].texrepeat", o.texrepeat)
      send("objects["..tostring(obj_amount).."].tex_offset", o.tex_offset)
    else
      send("objects["..tostring(obj_amount).."].isTextured", false)
    end
    if o.bumptex then
      send("objects["..tostring(obj_amount).."].hasBumpMap", true)
      send("objects["..tostring(obj_amount).."].bump_offset", o.bump_offset)
    else
      send("objects["..tostring(obj_amount).."].hasBumpMap", false)
    end
		send("objects["..tostring(obj_amount).."].Type",t)
		send("objects["..tostring(obj_amount).."].i",obj_amount)
		send("objects["..tostring(obj_amount).."].p",o.pos)
		send("objects["..tostring(obj_amount).."].b",o.size)
		send("objects["..tostring(obj_amount).."].color",c)
    send("objects["..tostring(obj_amount).."].ref",o.ref)
    send("objects["..tostring(obj_amount).."].alpha",alpha)
		obj_amount = obj_amount + 1
	end

	send("object_amount",obj_amount)
end

function updateLightsList(lights)
	local light_amount = 0

	for i,l in ipairs(lights) do
		local c = {l[4][1]/255,l[4][2]/255,l[4][3]/255}
		local t = 0
		if l[1] == "Directional" then
			t = 1
		elseif l[1] == "Point" then
			t = 2
		end
		send("lights["..tostring(i-1).."].Type",t)
		send("lights["..tostring(i-1).."].p",l[2])
		send("lights["..tostring(i-1).."].d",l[3])
		send("lights["..tostring(i-1).."].color",c)
		light_amount = light_amount + 1
	end
	send("light_amount",light_amount)
end

function setCanvas(c)
  canvas = c
  return true
end

function setShader(s)
  shader = s
  return true
end

function send(name, value)
  if shader:hasUniform(name) then
    shader:send(name, value)
  end
end

function renderer_load()
  fxaa = love.graphics.newShader("engine/shaders/fxaa.glsl")
end

function render()
  --Set variables
	send("iTime",{iTime,iTimeDelta})
  send("cam_pos", cam_pos)
  send("cam_dir", cam_dir)
  send("screen_res", {width, height})
  love.graphics.setShader(shader)
  if FLAGS.AA and MODE == "game" then
    love.graphics.setCanvas(canvas)
  end
	love.graphics.setColor(1,1,1,1)
	love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())
  if FLAGS.AA and MODE == "game" then
    love.graphics.setCanvas()
    love.graphics.setShader(fxaa)
    love.graphics.draw(canvas)
  end
  love.graphics.setShader()
end
