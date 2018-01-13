function FS_loadModel(filename)
  local t = {}
	local f = assert(io.open("engine/assets/"..filename, "r"))
	for line in f:lines() do
		local object = loadstring("return "..line)()
    for i=1, #object[1] do
      object[1][i].tex_col = {1,1,1}
      if object[1][i].tex then
        local texloc = object[1][i].tex
        object[1][i].tex = love.graphics.newImage("engine/assets/"..texloc)
        object[1][i].tex_col = getAvgTexCol(object[1][i].tex)
        object[1][i].texname = texloc
        object[1][i].texsize = {object[1][i].tex:getWidth(), object[1][i].tex:getHeight()}
      end
      if object[1][i].bumptex then
        local bumptexloc = object[1][i].bumptex
        object[1][i].bumptex = love.graphics.newImage("engine/assets/"..bumptexloc)
        object[1][i].bumptexname = bumptexloc
      end
      if object[1][i].script then
        local scriptloc = "engine/assets/"..object[1][i].script
        object[1][i].script = prerequire(scriptloc:gsub("/","."))
      end
      object[1][i].uuid = uuid()
  		-- table.insert(objects,object)
      table.insert(t, object[1][i])
    end
	end
  return t
end

function generateTextureAtlas(objects)
  local max_size = 8192

  local textures_used = {}
  local bumps_used = {}

  local tex_atlas = {love.graphics.newCanvas(max_size, max_size)}
  local bump_atlas = {love.graphics.newCanvas(max_size, max_size)}

  local x = 0
  local y = 0

  local cur_layer_height = 0

  local cur_atlas = 1

  --Create texture atlas
  for i=1, #objects do
    local dobreak = false
    if objects[i].tex then
      local tex_found = false
      for j=1, #textures_used do
        if objects[i].texname == textures_used[j].name then
          tex_found = true
          objects[i].tex_offset = {textures_used[j].pos.x, textures_used[j].pos.y, textures_used[j].layer}
        end
      end

      if tex_found == false then
        local size = objects[i].texsize

        local texdata = {name=objects[i].texname}

        if y + size[2] > max_size then
          cur_atlas = cur_atlas + 1
          x = 0
          y = 0
          cur_layer_height = 0
        end

        texdata.layer = cur_atlas

        if x + size[1] < max_size then
          cur_layer_height = math.max(cur_layer_height, size[2])

          objects[i].tex_offset = {x, y, cur_atlas}
          texdata.pos = {x=x, y=y}

          love.graphics.setCanvas(tex_atlas[cur_atlas])
          love.graphics.draw(objects[i].tex, x, y)
          love.graphics.setCanvas()
          x = x + size[1]
        else
          x = 0
          y = y + cur_layer_height
          if y + size[2] > max_size then
            cur_atlas = cur_atlas + 1
            if cur_atlas > 16 then
              dobreak = true
              break
            end
          end
          if dobreak then
            break
          end
          cur_layer_height = math.max(0, size[2])

          objects[i].tex_offset = {x, y, cur_atlas}
          texdata.pos = {x=x, y=y}

          love.graphics.setCanvas(tex_atlas[cur_atlas])
          love.graphics.draw(objects[i].tex, x, y)
          love.graphics.setCanvas()
          x = x + size[1]
        end
        table.insert(textures_used, texdata)
      end
    end
    if dobreak then
      break
    end
  end

  x = 0
  y = 0
  size_left = max_size
  height_left = max_size
  cur_atlas = 1
  cur_layer_height = 0

  --Create bump atlas
  for i=1, #objects do
    local dobreak = false
    if objects[i].bumptex then
      local tex_found = false
      for j=1, #bumps_used do
        if objects[i].bumptexname == bumps_used[j].name then
          tex_found = true
          objects[i].bump_offset = {bumps_used[j].pos.x, bumps_used[j].pos.y, bumps_used[j].layer}
        end
      end

      if tex_found == false then
        local size = objects[i].texsize

        local bumpdata = {name=objects[i].bumptexname}

        if y + size[2] > max_size then
          cur_atlas = cur_atlas + 1
          x = 0
          y = 0
          cur_layer_height = 0
        end

        bumpdata.layer = cur_atlas

        if x + size[1] < max_size then
          cur_layer_height = math.max(cur_layer_height, size[2])

          objects[i].bump_offset = {x, y, cur_atlas}
          bumpdata.pos = {x=x, y=y}

          love.graphics.setCanvas(bump_atlas[cur_atlas])
          love.graphics.draw(objects[i].bumptex, x, y)
          love.graphics.setCanvas()
          x = x + size[1]
        else
          x = 0
          y = y + cur_layer_height
          if y + size[2] > max_size then
            cur_atlas = cur_atlas + 1
            if cur_atlas > 16 then
              dobreak = true
              break
            end
          end
          if dobreak then
            break
          end
          cur_layer_height = math.max(0, size[2])

          objects[i].bump_offset = {x, y, cur_atlas}
          bumpdata.pos = {x=x, y=y}

          love.graphics.setCanvas(bump_atlas[cur_atlas])
          love.graphics.draw(objects[i].bumptex, x, y)
          love.graphics.setCanvas()
          x = x + size[1]
        end
        table.insert(bumps_used, bumpdata)
      end
    end
    if dobreak then
      break
    end
  end

  print("Creating texture atlas data")

  local tex_atlas_data = {}
  local bump_atlas_data = {}

  for i=1, #tex_atlas do
    table.insert(tex_atlas_data, tex_atlas[i]:newImageData())
  end
  for i=1, #bump_atlas do
    table.insert(bump_atlas_data, bump_atlas[i]:newImageData())
  end

  print("Done!")

  return tex_atlas_data, bump_atlas_data
end

function MeshToSDF(filename, scale)
  local faces = LoadMeshFaces(filename, scale)
  local shader = love.graphics.newShader("engine/shaders/mesh2sdf.glsl")
  for i=1, #faces do
    local s = "faces["..tostring(i).."]."
    shader:send(s.."A", faces[i][1])
    shader:send(s.."B", faces[i][2])
    shader:send(s.."C", faces[i][3])
  end
  local buffers = {}
  love.graphics.setShader(shader)
  local r = love.graphics.newMesh({{0,0, 0,0, 255,255,255,255},{50,0, 1,0, 255,255,255,255},{50,50, 1,1, 255,255,255,255},{0,50, 0,1, 255,255,255,255}}, "fan")
  for slice=1, 50 do
    shader:send("VolumeZ", slice)
    print(slice)
    local c = love.graphics.newCanvas(50,50)
    love.graphics.setCanvas(c)
    love.graphics.draw(r, 0,0)
    love.graphics.setCanvas()
    local imgdata = c:newImageData()
    imgdata:encode("png", "buf_"..tostring(slice)..".png")
    table.insert(buffers, imgdata)
    -- volumecanvas:newImageData(slice, 0, 1,1,50,50):encode("png", "buf_"..tostring(slice)..".png")
  end
  love.graphics.setShader()
  local volumetexture = love.graphics.newVolumeImage(buffers)
  return volumetexture
end

function LoadMeshFaces(filename, scale)
  local vertices = {}
  local faces = {}
  for line in io.lines("engine/assets/"..filename) do
    if string.starts(line, "v ") then
      local l = line:sub(3, #line)
      local pos = string.split(l, " ")
      pos[1] = tonumber(pos[1])*scale
      pos[2] = tonumber(pos[2])*scale
      pos[3] = tonumber(pos[3])*scale
      table.insert(vertices, pos)
    end
    if string.starts(line, "f ") then
      --Add to tris table
      local l = line:sub(3, #line)
      local verts = string.split(l, " ")
      --Split verts into vertexid, uvid, normalid
      --For now, only the vertexposition is passed to the shader
      local face = {}
      for j=1,#verts do
        local data = string.split(verts[j], "/")
        local vertid = tonumber(data[1])
        -- table.insert(data, vertices[vertid])
        local pos = vertices[vertid]
        --Move vertices from -25>24 to 0>50
        --Later on, I should determine the scale needed to transform a mesh to -25>24, so larger meshes are supported.
        pos[1] = pos[1] + scale
        pos[2] = pos[2] + scale
        pos[3] = pos[3] + scale
        table.insert(face, pos)
      end
      table.insert(faces, face)
    end
  end
  return faces
end
