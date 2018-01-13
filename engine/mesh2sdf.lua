function genSDF(filename)
  if not file_exists(filename) then
    print("File does not exist")
    return nil
  end

  local vertices = {}
  -- local tris = {}
  local imgdata = love.graphics.newCanvas(127,127):newImageData()

  local x = 0
  local y = 0

  for i, line in ipairs(lines_from(filename)) do
    if string.starts(line, "v ") then
      local l = line:sub(3, #line)
      local pos = string.split(l, " ")
      pos[1] = tonumber(pos[1])*255
      pos[2] = tonumber(pos[2])*255
      pos[3] = tonumber(pos[3])*255
      table.insert(vertices, pos)
    elseif string.starts(line, "f ") then
      --Add to tris table
      local l = line:sub(3, #line)
      local verts = string.split(l, " ")
      --Split verts into vertexid, uvid, normalid
      --For now, only the vertexposition is passed to the shader
      -- local data = {}
      for j=1,#verts do
        local data = string.split(verts[j], "/")
        local vertid = tonumber(data[1])
        -- table.insert(data, vertices[vertid])
        local pos = vertices[vertid]
        --Move vertices from -128>127 to 0>255
        pos[1] = pos[1] + 128
        pos[2] = pos[2] + 128
        pos[3] = pos[3] + 128
        --Put them on the canvas
        imgdata:setPixel(x, y, pos[1], pos[2], pos[3], 255)
      end

      x = x + 3
      if x > 125 then
        y = y + 1
        x = 0
      end
      -- table.insert(tris, data)
    end
  end

  local texSize = 128

  local shader = love.graphics.newShader("shaders/mesh2sdf.glsl")
  shader:send("texSize",texSize)
  shader:send("mesh",love.graphics.newImage(imgdata))
  shader:send("meshres",{126,126})
  local canvas = love.graphics.newCanvas(texSize,texSize*texSize)
  love.graphics.setShader(shader)
  love.graphics.setCanvas(canvas)
  love.graphics.rectangle("fill",0,0,texSize,texSize*texSize)
  love.graphics.setCanvas()
  love.graphics.setShader()
  canvas:newImageData():encode("png", "test.png")
  -- saveImage(canvas:newImageData():encode("png"), "test.png")
end
