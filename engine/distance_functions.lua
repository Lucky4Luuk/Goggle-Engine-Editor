-------------
--Functions--
-------------

-- vec3 p1, vec3 p2
function dot(p1, p2)
	return p1[1] * p2[1] + p1[2] * p2[2] + p1[3] * p2[3]
end

-- vec3 p, float f
function f_minus(p, f)
	return {p[1] - f, p[2] - f, p[3] - f}
end

-- vec3 p, float f
function f_add(p, f)
	return {p[1] + f, p[2] + f, p[3] + f}
end

-- vec3 p1, vec3 p2
function vec_minus(p1, p2)
	return {p1[1] - p2[1], p1[2] - p2[2], p1[3] - p2[3]}
end

-- vec3 p1, vec3 p2
function vec_add(p1, p2)
	return {p1[1] + p2[1], p1[2] + p2[2], p1[3] + p2[3]}
end

-- vec3 p1, vec3 p2
function vec_mul(p1, p2)
	return {p1[1] * p2[1], p1[2] * p2[2], p1[3] * p2[3]}
end

-- vec3 p, float f
function v_mul_f(p, f)
	return {p[1] * f, p[2] * f, p[3] * f}
end

-- vec3 p, float f
function v_div_f(p, f)
	return {p[1] / f, p[2] / f, p[3] / f}
end

-- vec3 p, float f
function vec_pow(p, f)
	return {math.pow(p[1], f), math.pow(p[2], f), math.pow(p[3], f)}
end

-- vec3 p
function length(p)
	local x = p[1]
	local y = p[2]
	local z = p[3]
	return math.sqrt(x*x + y*y + z*z)
end

-- vec3 p
function vec_abs(p)
	return {math.abs(p[1]),math.abs(p[2]),math.abs(p[3])}
end

-- vec3 p1, vec3 p2
function vec_max(p1, p2)
	return {max(p1[1],p2[1]), max(p1[2],p2[2]), max(p1[3],p2[3])}
end

-- vec3 p, float f
function f_max(p, f)
	return vec_max(p,{f,f,f})
end

-- float f, vec3 p
function f2_max(f, p)
	return vec_max(p,{f,f,f})
end

-- vec3 p1, vec3 p2
function vec_min(p1, p2)
	return {min(p1[1],p2[1]), min(p1[2],p2[2]), min(p1[3],p2[3])}
end

-- vec3 p, float f
function f_min(p, f)
	return vec_min(p,{f,f,f})
end

-- float f, vec3 p
function f2_min(f, p)
	return vec_min(p,{f,f,f})
end

-- float f1, float f2
function min(f1, f2)
	return math.min(f1,f2)
end

-- float f1, float f2
function max(f1, f2)
	return math.max(f1,f2)
end

function vec_distance(p1, p2)
	return math.abs(length(vec_minus(p1, p2)))
end

-- vec3 p
function normalize(p)
	return v_div_f(p, length(p))
end

-- vec2 p, float f
function v2_mul_f(p, f)
	return {p[1] * f, p[2] * f}
end

-- string obj_type, vec3 p, vec3 s
function map(obj_type, p, s)
	if obj_type == "Sphere" then
		return sdSphere(p, s[1])
	elseif obj_type == "Box" then
		return sdBox(p, s)
	elseif obj_type == "Plane" then
		return sdPlane(p)
	end
end

-- vec3 p, string obj_type
function calcNormal(p, obj_type, s)
	local e = v2_mul_f({1, -1}, 0.5773*0.0005)
	return normalize(
		vec_add(vec_add(vec_add(v_mul_f({e[1], e[2], e[2]}, map(obj_type,vec_add(p, {e[1], e[2], e[2]}), s)),
		v_mul_f({e[2], e[2], e[1]}, map(obj_type,vec_add(p, {e[2], e[2], e[1]}), s))),
		v_mul_f({e[2], e[1], e[2]}, map(obj_type,vec_add(p, {e[2], e[1], e[2]}), s))),
		v_mul_f({e[1], e[1], e[1]}, map(obj_type,vec_add(p, {e[1], e[1], e[1]}), s)))
	)
end

--------------
--Primitives--
--------------
--Each Distance Field Function returns a float

-- vec3 p, float s
function sdSphere(p, s)
	return length(p) - s
end

-- vec3 p, vec3 b
function udBox(p, b)
	return length(f_max(vec_minus(vec_abs(p),b),0.0))
end

-- vec3 p, vec3 b, float r
function udRoundBox(p, b, r)
	return f_minus(length(f_max(vec_minus(vec_abs(p),b))),r)
end

-- vec3 p, vec3 b
function sdBox(p, b)
	local d = vec_minus(vec_abs(p),b)
	return min(max(d[1],max(d[2],d[3])),0.0) + length(f_max(d,0))
end

-- vec3 p
function sdPlane(p)
	return p[2]
end
