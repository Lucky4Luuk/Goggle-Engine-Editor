--LOVE 3D ENGINE

local engine = {}

engine.console = {} --Console "library". This is just a table of functions passed from the editor to the engine, to allow the engine to print to the console.
engine.gamecanvas = love.graphics.newCanvas(768, 432)
engine.render_target = {}
engine.render_target.width = 768
engine.render_target.height = 432
engine.center = {768/2, 432/2}

require "engine.distance_functions"
require "engine.renderer"
require "engine.filesystem"
require "engine.physics"
require "engine.utils"

local debug = {FPS=false, CAMERA=false, ERROR=false}

local width = 768
local height = 432
local min_width = width
local min_height = height
local iTime = 0
local iTimeDelta = 0
-- local canvas = nil
local cam_dir = {-1,0, 1}
local cam_pos = {1,0.5,-1}
engine.camera_position = {}
engine.camera_direction = {}
local default_cam_dir = cam_dir
local default_cam_pos = cam_pos
-- local shader = nil
local sensitivityX = 0.5
local sensitivityY = 0.5
local scale = {width / engine.render_target.width, height / engine.render_target.height}

engine.objects = {}
local lights = {{"Directional",{0,0,0},{-0.4,0.3,-0.6},{255,255,255}},{"Point",{-5,2,0},{0.5,0,0},{0,0,255}}}
local meshes = {}

local tex_atlas = nil
local bump_atlas = nil
local tex_atlas_data = 0
local bump_atlas_data = 0

local fog_density = 0.1
local view_distance = 20.0

local errors = {}

local first_frame = true
local TIMESTEP = 0
local TIMESTEPLENGTH = 1/60

function engine.setTargetResolution(w, h)
	setRenderSize(w, h)
	setSize(w, h)
	width = w
	height = h
end

function engine.setFXAACanvas(c)
	setCanvas(c)
end

function setSize(w, h)
	width = w
	height = h
	canvas = love.graphics.newCanvas(width,height)
	scale = {width / love.graphics.getWidth(), height / love.graphics.getHeight()}
	local status = setCanvas(love.graphics.newCanvas(width,height))
	status = setRenderSize(w, h)
end

function loadModel(data)
	if (type(data) == "string") then
		local t = FS_loadModel(data)
		for i=1, #t do
			table.insert(engine.objects, t[i])
		end
	else
		local i = #meshes
		table.insert(meshes, data[2])
		local o = data[1]
		o.tex_offset = {i, 0, 0}
		o.tex_col = {1,1,1}
		table.insert(engine.objects, o)
	end
end

function handleError(status)
	if status ~= true then
		table.insert(errors, status)
	end
end

function createAtlases()
	tex_atlas = {}
	bump_atlas = {}
	for i=1, #tex_atlas_data do
		table.insert(tex_atlas, love.graphics.newImage(tex_atlas_data[i]))
	end
	for i=1, #bump_atlas_data do
		table.insert(bump_atlas, love.graphics.newImage(bump_atlas_data[i]))
	end
end

function newMeshObject(pos, color, roughness, metallic, ref, volumetexture)
	--{t="Plane",pos={0,0,0},size={0,0,0},color={255,255,255},alpha=255,roughness=0.2,metallic=0,ref=1, tex="Textures/floor.png", texsize={0,0}, texrepeat={1,1}, bsr=0.0, vel={0,0,0}, res=0.5, mass=0.0}
	return {{t="Mesh", pos=pos,size={0,0,0},color=color,alpha=255,roughness=roughness,metallic=metallic, ref=ref, tex_offset={0,0,0}, tex_col={1,1,1}, bsr=0.0, vel={0.0}, res=0.5, mass=0.0}, volumetexture}
end

function engine.load()
	console.print("[-] Engine is loading...")
	console.print("[-] Creating render canvas...")
	--Create canvas for scaling
	renderer_load()
	setSize(width, height)
	setCanvas(love.graphics.newCanvas(width,height, {msaa=4}))
	console.print("[!] Render canvas created!")

	console.print("[-] Generating and loading main shader...")
	--Gen & Load shader
	genMainShader()
	setShader(love.graphics.newShader("engine/shaders/temp.glsl"))
	console.print("[!] Shader generated and loaded succesfully!")

	console.print("[-] Loading scene...")
	--Load testing data
	loadModel("floor.dmod")
	loadModel("box.dmod")
	--loadModel(newMeshObject({5,0.5,0}, {255,255,255}, 0.2, 0, 1, MeshToSDF("Models/tigre_sumatra_sketchfab.obj", 2)))
	console.print("[!] Scene loaded!")

	console.print("[-] Generating texture atlases...")
	--Generate Texture Atlas
	tex_atlas_data, bump_atlas_data = generateTextureAtlas(engine.objects)
	createAtlases()
	updateAtlas(tex_atlas[1], bump_atlas[1])
	console.print("[!] Texture atlases created succesfully!")

	console.print("[-] Sending data to shader...")
	--Send data to shader
	updateObjectsList(engine.objects, meshes)
	send("fog_density",fog_density)
	send("view_distance",view_distance)
	console.print("[!] Data has been sent to the shader succesfully!")

	--Reset mouse at start so the camera doesn't get offset before starting.
	love.mouse.setPosition(engine.center.x, engine.center.y)

	--Reset camera direction in case it rotated.
	resetCamera()

	setMode("editor")

	console.print("[!] Engine succesfully loaded!")
end

function resetCamera()
	cam_dir = default_cam_dir
	cam_pos = default_cam_pos
end

function rotateCamera()
	local mouseDeltaX = engine.mouse.x - engine.center.x
	local mouseDeltaY = engine.mouse.y - engine.center.y

	local qx = math.rad(mouseDeltaX*sensitivityX)
	local qy = -math.rad(mouseDeltaY*sensitivityY)
	qy = math.floor(qy * 200) / 200

	local x = cam_dir[1]
	local z = cam_dir[3]

	--X-Axis Rotation
	cam_dir[2] = cam_dir[2] + qy

	--Y-Axis Rotation
	cam_dir[1] = x*math.cos(qx) - z*math.sin(qx)
	cam_dir[3] = z*math.cos(qx) + x*math.sin(qx)

	love.mouse.setPosition(engine.center.x, engine.center.y)
end

function moveCamera(dt)
	if love.keyboard.isDown("e") then
		cam_pos[2] = cam_pos[2] + 1*dt
	elseif love.keyboard.isDown("q") then
		cam_pos[2] = cam_pos[2] - 1*dt
	end
	if love.keyboard.isDown("w") then
		cam_pos[1] = cam_pos[1] + cam_dir[1]*dt
		cam_pos[2] = cam_pos[2] + cam_dir[2]*dt
		cam_pos[3] = cam_pos[3] + cam_dir[3]*dt
	elseif love.keyboard.isDown("s") then
		cam_pos[1] = cam_pos[1] - cam_dir[1]*dt
		cam_pos[2] = cam_pos[2] - cam_dir[2]*dt
		cam_pos[3] = cam_pos[3] - cam_dir[3]*dt
	end
	if love.keyboard.isDown("d") then
		cam_pos[1] = cam_pos[1] - cam_dir[3]*dt
		cam_pos[3] = cam_pos[3] + cam_dir[1]*dt
	elseif love.keyboard.isDown("a") then
		cam_pos[1] = cam_pos[1] + cam_dir[3]*dt
		cam_pos[3] = cam_pos[3] - cam_dir[1]*dt
	end
end

function FixedUpdate()
	local bsres = getBSResponses(engine.objects)
  local cres = getCollisionResponses(bsres, engine.objects)
  applyPhysics(cres, engine.objects)

	for i=1, #engine.objects do
		if engine.objects[i].script then
			if engine.objects[i].script.FixedUpdate then
				engine.objects[i].script.FixedUpdate(engine.objects[i], TIMESTEPLENGTH)
			end
		end
	end
end

function engine.mousepressed(x, y, button, is_touch)
	if button == 2 then
		love.mouse.setPosition(engine.center.x, engine.center.y)
	end
end

function engine.update(dt)
	iTime = iTime + dt
	iTimeDelta = dt
	TIMESTEP = TIMESTEP + dt

	engine.camera_position.x = cam_pos[1]
	engine.camera_position.y = cam_pos[2]
	engine.camera_position.z = cam_pos[3]

	engine.camera_direction.x = cam_dir[1]
	engine.camera_direction.y = cam_dir[2]
	engine.camera_direction.z = cam_dir[3]

	if engine.mouse.right then
		moveCamera(dt)
		rotateCamera()
	end
	setCamera(cam_pos, cam_dir)
	updateObjectsList(engine.objects, meshes)
	updateLightsList(lights)

	while TIMESTEP > TIMESTEPLENGTH do
		FixedUpdate()
		TIMESTEP = TIMESTEP - TIMESTEPLENGTH
	end
end

function engine.draw()
	--Draw Stuff
	render()

	--FPS Counter
	love.graphics.setShader()
	love.graphics.setBlendMode("subtract")
	love.graphics.setColor(1,1,1,1)
	local dy = 0
	if debug.FPS then
		love.graphics.print(string.format("FPS: %0.2f",love.timer.getFPS()), 0,dy)
		dy = dy + 20
		love.graphics.print(string.format("MS: %0.2f",love.timer.getDelta()*1000), 0,dy)
		dy = dy + 20
	end
	if debug.CAMERA then
		love.graphics.print("CAM_POS: ("..tostring(cam_pos[1]).."; "..tostring(cam_pos[2]).."; "..tostring(cam_pos[3])..")",0,dy)
		dy = dy + 20
		love.graphics.print("CAM_DIR: ("..tostring(cam_dir[1]).."; "..tostring(cam_dir[2]).."; "..tostring(cam_dir[3])..")",0,dy)
		dy = dy + 20
	end
	love.graphics.setBlendMode("alpha")
end

function engine.keypressed(k)
	if k == 'escape' then
		love.event.quit()
	end
	if k == 'f11' then
		local modes = love.window.getFullscreenModes()
		table.sort(modes, function(a, b) return a.width*a.height < b.width*b.height end)   --Sort from smallest to largest
		if fullscreen == true then
			fullscreen = false
			love.window.setMode(min_width,min_height, {vsync=false})
			width = min_width
			height = min_height
			love.window.setFullscreen(false)
			canvas = love.graphics.newCanvas(width,height, {msaa=4})
		else
			fullscreen = true
			width = modes[#modes].width
			height = modes[#modes].height
			-- print(width,height)
			love.window.setMode(width,height, {vsync=false})
			-- love.window.setFullscreen(true)
		end
		setSize(width, height)
		updateAtlas(tex_atlas[1], bump_atlas[1])
		updateObjectsList(engine.objects, meshes)
		updateLightsList(lights)
		send("fog_density",fog_density)
		send("view_distance",view_distance)
	end
end

function engine.resize(w, h)
	setSize(width, height)
	updateAtlas(tex_atlas[1], bump_atlas[1])
	updateObjectsList(engine.objects, meshes)
	updateLightsList(lights)
	send("fog_density",fog_density)
	send("view_distance",view_distance)
end

return engine
