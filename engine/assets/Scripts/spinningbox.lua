local c = {}

local t = 0

local function FixedUpdate(self, dt)
  self.rot.x = (self.rot.x + dt * 30) % 360
  self.rot.y = (self.rot.y + dt * 30) % 360
  self.pos[2] = math.sin(t)/2 + 2
  t = t + dt
end

c.FixedUpdate = FixedUpdate

return c
