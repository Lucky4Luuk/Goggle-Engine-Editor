require "engine.distance_functions"

local PRECIS = 0.01

function __SETPRECIS(f)
  PRECIS = f
end

function updateObject(o, index, objects)
  objects[index] = o
end


function getCollisionResponses(bsres, objects) --BSRES is a table of bounding sphere responses, gotten with getBSResponses
  local cres = {}
  if #bsres > 0 then
    for i=1, #bsres do
      local o1 = objects[bsres[i][1]]
      local o2 = objects[bsres[i][2]]
      local d1 = 0
      local d2 = 0
      --Apply scale thingy
      -- local scale = circle2 / circle1
      -- local checkpos = centerpos * scale
      local p = bsres[i][3]
      if o1.t == "Box" then
        d1 = sdBox(vec_minus(p, o1.pos), o1.size)
      elseif o1.t == "Sphere" then
        d1 = sdSphere(vec_minus(p, o1.pos), o1.size[1])
      elseif o1.t == "Plane" then
        d1 = sdPlane(vec_minus(p, o1.pos))
      end
      if o2.t == "Box" then
        d2 = sdBox(vec_minus(p, o2.pos), o2.size)
      elseif o2.t == "Sphere" then
        d2 = sdSphere(vec_minus(p, o2.pos), o2.size[1])
      elseif o2.t == "Plane" then
        d2 = sdPlane(vec_minus(p, o2.pos))
      end
      if d1 + d2 <= PRECIS then
        local dir = vec_minus(p, o1.pos)
        local cp = vec_minus(p, v_mul_f(dir, d1))
        local cn = calcNormal(cp, o1.t, o1.size)
        if o1.t == "Sphere" and o2.t == "Sphere" then
          cn = vec_minus(o2.pos, o1.pos)
        elseif o1.t == "Sphere" and o2.t == "Plane" then
          cn = {0, -1, 0}
        elseif o1.t == "Plane" and o2.t == "Sphere" then
          cn = {0, -1, 0}
        elseif o1.t == "Sphere" then
          cn = vec_minus(cp, o1.pos)
        elseif o2.t == "Sphere" then
          cn = vec_minus(cp, o2.pos)
        end
        local penetration_depth = d1 + d2
        table.insert(cres, {bsres[i][1], bsres[i][2], cp, cn, penetration_depth, dir})
      end
    end
  end
  return cres
end

function getBSResponses(objects)
  local bsres = {}
  for i=1, #objects do
    for j=1, #objects do
      if i ~= j then
        if vec_distance(objects[i].pos, objects[j].pos) < (objects[i].bsr + objects[j].bsr) and objects[i].t ~= "Plane" and objects[i].t ~= "Plane" then
          -- Calculate center of the area where the 2 spheres overlap
          local d = vec_distance(objects[i].pos, objects[j].pos)
          local a = (objects[i].bsr*objects[i].bsr - objects[j].bsr*objects[j].bsr + d*d) / (2 * d)
          local p = vec_add(objects[i].pos, v_div_f(v_mul_f(vec_minus(objects[j].pos, objects[i].pos), a), d))
          if isNaN(p[1]) ~= true and isNaN(p[2]) ~= true and isNaN(p[3]) ~= true then
            --Insert data into table
            local data = {}
            if i < j then
              data = {i, j, p}
            else
              data = {j, i, p}
            end
            local isDupe = false
            for index=1, #bsres do
              if bsres[index][1] == data[1] and bsres[index][2] == data[2] then
                isDupe = true
              end
            end
            if isDupe == false then
              table.insert(bsres, data)
            end
          end
        elseif objects[i].t == "Plane" and objects[j].t ~= "Plane" then
          local dir = vec_minus(objects[j].pos, objects[i].pos)
          local p = vec_add(objects[j].pos, v_mul_f(dir, objects[j].bsr))
          --Insert data into table
          local data = {}
          if i < j then
            data = {i, j, p}
          else
            data = {j, i, p}
          end
          local isDupe = false
          for index=1, #bsres do
            if bsres[index][1] == data[1] and bsres[index][2] == data[2] then
              isDupe = true
            end
          end
          if isDupe == false then
            table.insert(bsres, data)
          end
        elseif objects[j].t == "Plane" and objects[i].t ~= "Plane" then
          local dir = vec_minus(objects[i].pos, objects[j].pos)
          local p = vec_add(objects[i].pos, v_mul_f(dir, objects[i].bsr))
          --Insert data into table
          local data = {}
          if i < j then
            data = {i, j, p}
          else
            data = {j, i, p}
          end
          local isDupe = false
          for index=1, #bsres do
            if bsres[index][1] == data[1] and bsres[index][2] == data[2] then
              isDupe = true
            end
          end
          if isDupe == false then
            table.insert(bsres, data)
          end
        end
      end
    end
  end
  return bsres
end

function resolveCollision(data, objects)
  local A = objects[data[1]]
  local B = objects[data[2]]
  local rv = vec_minus(B.vel, A.vel)
  local velAlongNormal = dot(rv, data[4])

  --Do not calculate new shit if the objects are separating.
  if velAlongNormal > 0 then
    return 0
  end

  --Calculate restition (bounciness)
  local e = min(A.res, B.res)

  --Calculate impulse scalar
  local j = -(1 + e) * velAlongNormal
  local A_INVMASS = 0
  if A.mass > 0 then
    A_INVMASS = 1 / A.mass
  end
  local B_INVMASS = 0
  if B.mass > 0 then
    B_INVMASS = 1 / B.mass
  end
  j = j / (A_INVMASS + B_INVMASS)

  --Apply impulse
  local impulse = v_mul_f(data[4], j)
  local mass_sum = A.mass + B.mass
  local ratio = 0
  if A.mass > 0 and mass_sum > 0 then
    ratio = A.mass / mass_sum
  end
  -- print(ratio)
  objects[data[1]].vel = vec_minus(objects[data[1]].vel, v_mul_f(impulse, ratio))
  ratio = 0
  if B.mass > 0 and mass_sum > 0 then
    ratio = B.mass / mass_sum
  end
  objects[data[2]].vel = vec_add(objects[data[2]].vel, v_mul_f(impulse, ratio))
end

function applyPhysics(cres, objects)
  if #cres > 0 then
    for i=1, #cres do
      resolveCollision(cres[i], objects)
    end
  end
end

function update()
  -- table.insert(objects, {pos={0,0,0}, bsr=0.6, t="Sphere", size={0.5, 0.5, 0.5}})
  -- table.insert(objects, {pos={1.1,0,0}, bsr=0.7, t="Sphere", size={0.6, 0.6, 0.6}})
  return objects
end

function getBoundingSphere(index)
  return objects[index].bsr
end
