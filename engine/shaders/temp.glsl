//#pragma language glsl3

#define saturate(x) clamp(x, 0.0, 1.0)
#define PI 3.14159265359

int GI_maxDistance = 20; //Unused
int GI_maxBounces = 4; //Unused

uniform vec2 iTime;
uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform int object_amount;
uniform int light_amount;
uniform sampler2D tex_atlas; //The Texture Atlas.
//Using this, we still can't have many textures, but it's better than none.
uniform sampler2D bump_atlas; //The Bump Texture Atlas. Same limitation as the Texture Atlas.
uniform struct Object //This defines the paramaters of the type 'Object'.
{
	int Type; //Object Type.
	int i; //Object ID.
	vec3 p; //Vector 3: position.
	vec3 b; //Vector 3: size (if sphere, only x is used).
	mat3 r; //Matrix 3: rotation.
	vec3 color; //Base color.
	bool isTextured; //Defines if it's textured or not.
	bool hasBumpMap; //Defines if it uses a bumpmap or not.
	vec3 tex_offset; //UV offset.
	//The Z component used to refer to which Texture Atlas to use, but this isn't used for now.
	vec3 bump_offset; //UV offset for the tex_offset. The Z component is the same as the one used in tex_offset.
	vec2 texsize; //Texture size.
	vec2 texrepeat; //Texture repeat.
	//The UV coord calculated gets a modulo applied to it, using this as 'b' in mod(a, b).
	vec3 avg_tex_col; //Average Texture Color. Unused, but planned to be used for GI.
	float alpha; //Alpha of the object. Unused for now.
	float ref; //Reflectivity. Usually just 1, as it's a multiplier to the final result.
	float roughness; //Roughness of the object. Used for the PBR lighting system.
	float metallic; //Metallic value of the object. Used for the PBR lighting system.
} objects[30]; //Final definition of the amount of uniforms of type 'Object'.
uniform struct Light //This defines the paramaters of the type 'Light'.
{
	int Type; //Light type.
	vec3 p; //Light position. Not used for the Directional Light.
	vec3 d; //Light direction. In case of a pointlight, only the x component is used (as radius).
	vec3 color; //Light color.
} lights[50]; //Final definition of the amount of uniforms of type 'Light'.
uniform float fog_density; //The fog density.
uniform float view_distance; //The view distance.
uniform vec2 screen_res; //The screen resolution.
//Used instead of love_ScreenSize, as I found that it didn't always report correctly.
//This was probably an error on my side, but this at least works.


// mat3 rotate3DX(float a) { return mat3(1.,0.,0.,0.,cos(a),-sin(a),0,sin(a),cos(a));}
// mat3 rotate3DY(float a) { return mat3(cos(a),0.,sin(a),0.,1.,0.,-sin(a),0.,cos(a));}
// mat3 rotate3DZ(float a) { return mat3(cos(a),-sin(a),0.,sin(a),cos(a),0.,0.,0.,1.);}


//Define RESULT
struct RESULT {
	vec4 re; //Vec4 re: x=distance, yzw=color.
	int i; //Object ID.
};

struct L_RESULT {
	float t; //Distance.
	vec4 m; //Material.
	int id; //Object ID.
};

struct GI_TRACE {
	vec3 pos; //Hit position.
	vec3 dir; //Direction in which the light bounces.
	int id; //Object ID.
	vec4 m; //Material.
};
#define SAMPLES 32 //More samples means better image quality.

#define AA 1 //The amount of MSAA. Usually not needed, as it's quite heavy.
//The engine already uses FXAA too.

#define GI 1 //Switch between the old, non-PBR lighting system and the new lighting system.
//GI = 1 means the new lighting system. Right now, it doesn't actually control GI, as there is none.

#define BUMP_FACTOR 0.015 //Leave like this if you don't know what you are doing.
//Just a basic multiplier for the BUMP_FACTOR, although it's not used right now.

#define STEP_SIZE 1 //If bigger, it might get glitchy but might also speed up.
//Leave at 1 if you don't know what you are doing.
//Putting it lower than 1 might help with the accuracy of distance fields.

#define CHECKERBOARD 1 //Turns on checkerboard rendering. Renders every other pixel, interpolates the rest.
//Mercury HG_SDF

// Sign function that doesn't return 0
float sgn(float x) {
	return (x<0)?-1:1;
}

vec2 sgn(vec2 v) {
	return vec2((v.x<0)?-1:1, (v.y<0)?-1:1);
}

float square (float x) {
	return x*x;
}

vec2 square (vec2 x) {
	return x*x;
}

vec3 square (vec3 x) {
	return x*x;
}

float lengthSqr(vec3 x) {
	return dot(x, x);
}


// Maximum/minumum elements of a vector
float vmax(vec2 v) {
	return max(v.x, v.y);
}

float vmax(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

float vmax(vec4 v) {
	return max(max(v.x, v.y), max(v.z, v.w));
}

float vmin(vec2 v) {
	return min(v.x, v.y);
}

float vmin(vec3 v) {
	return min(min(v.x, v.y), v.z);
}

float vmin(vec4 v) {
	return min(min(v.x, v.y), min(v.z, v.w));
}

// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
// Read like this: R(p.xz, a) rotates "x towards z".
// This is fast if <a> is a compile-time constant and slower (but still practical) if not.
void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// Shortcut for 45-degrees rotation
void pR45(inout vec2 p) {
	p = (p + vec2(p.y, -p.x))*sqrt(0.5);
}

// Repeat space along one axis. Use like this to repeat along the x axis:
// <float cell = pMod1(p.x,5);> - using the return value is optional.
float pMod1(inout float p, float size) {
	float halfsize = size*0.5;
	float c = floor((p + halfsize)/size);
	p = mod(p + halfsize, size) - halfsize;
	return c;
}

// Same, but mirror every second cell so they match at the boundaries
float pModMirror1(inout float p, float size) {
	float halfsize = size*0.5;
	float c = floor((p + halfsize)/size);
	p = mod(p + halfsize,size) - halfsize;
	p *= mod(c, 2.0)*2 - 1;
	return c;
}

// Repeat the domain only in positive direction. Everything in the negative half-space is unchanged.
float pModSingle1(inout float p, float size) {
	float halfsize = size*0.5;
	float c = floor((p + halfsize)/size);
	if (p >= 0)
		p = mod(p + halfsize, size) - halfsize;
	return c;
}

// Repeat only a few times: from indices <start> to <stop> (similar to above, but more flexible)
float pModInterval1(inout float p, float size, float start, float stop) {
	float halfsize = size*0.5;
	float c = floor((p + halfsize)/size);
	p = mod(p+halfsize, size) - halfsize;
	if (c > stop) { //yes, this might not be the best thing numerically.
		p += size*(c - stop);
		c = stop;
	}
	if (c <start) {
		p += size*(c - start);
		c = start;
	}
	return c;
}


// Repeat around the origin by a fixed angle.
// For easier use, num of repetitions is use to specify the angle.
float pModPolar(inout vec2 p, float repetitions) {
	float angle = 2*PI/repetitions;
	float a = atan(p.y, p.x) + angle/2.;
	float r = length(p);
	float c = floor(a/angle);
	a = mod(a,angle) - angle/2.;
	p = vec2(cos(a), sin(a))*r;
	// For an odd number of repetitions, fix cell index of the cell in -x direction
	// (cell index would be e.g. -5 and 5 in the two halves of the cell):
	if (abs(c) >= (repetitions/2)) c = abs(c);
	return c;
}

// Repeat in two dimensions
vec2 pMod2(inout vec2 p, vec2 size) {
	vec2 c = floor((p + size*0.5)/size);
	p = mod(p + size*0.5,size) - size*0.5;
	return c;
}

// Same, but mirror every second cell so all boundaries match
vec2 pModMirror2(inout vec2 p, vec2 size) {
	vec2 halfsize = size*0.5;
	vec2 c = floor((p + halfsize)/size);
	p = mod(p + halfsize, size) - halfsize;
	p *= mod(c,vec2(2))*2 - vec2(1);
	return c;
}

// Same, but mirror every second cell at the diagonal as well
vec2 pModGrid2(inout vec2 p, vec2 size) {
	vec2 c = floor((p + size*0.5)/size);
	p = mod(p + size*0.5, size) - size*0.5;
	p *= mod(c,vec2(2))*2 - vec2(1);
	p -= size/2;
	if (p.x > p.y) p.xy = p.yx;
	return floor(c/2);
}

// Repeat in three dimensions
vec3 pMod3(inout vec3 p, vec3 size) {
	vec3 c = floor((p + size*0.5)/size);
	p = mod(p + size*0.5, size) - size*0.5;
	return c;
}

// Mirror at an axis-aligned plane which is at a specified distance <dist> from the origin.
float pMirror (inout float p, float dist) {
	float s = sgn(p);
	p = abs(p)-dist;
	return s;
}

// Mirror in both dimensions and at the diagonal, yielding one eighth of the space.
// translate by dist before mirroring.
vec2 pMirrorOctant (inout vec2 p, vec2 dist) {
	vec2 s = sgn(p);
	pMirror(p.x, dist.x);
	pMirror(p.y, dist.y);
	if (p.y > p.x)
		p.xy = p.yx;
	return s;
}

// Reflect space at a plane
float pReflect(inout vec3 p, vec3 planeNormal, float offset) {
	float t = dot(p, planeNormal)+offset;
	if (t < 0) {
		p = p - (2*t)*planeNormal;
	}
	return sgn(t);
}

float opUChamfer(float a, float b, float r) {
	return min(min(a, b), (a - r + b) * sqrt(0.5));
}

float opIChamfer(float a, float b, float r) {
	return max(max(a, b), (a + r + b)*sqrt(0.5));
}

float opSChamfer(float a, float b, float r) {
	return opIChamfer(a, -b, r);
}

// The "Columns" flavour makes n-1 circular columns at a 45 degree angle:
float opUColumns(float a, float b, float r, float n) {
	if ((a < r) && (b < r)) {
		vec2 p = vec2(a, b);
		float columnradius = r*sqrt(2)/((n-1)*2+sqrt(2));
		pR45(p);
		p.x -= sqrt(2)/2*r;
		p.x += columnradius*sqrt(2);
		if (mod(n,2) == 1) {
			p.y += columnradius;
		}
		// At this point, we have turned 45 degrees and moved at a point on the
		// diagonal that we want to place the columns on.
		// Now, repeat the domain along this direction and place a circle.
		pMod1(p.y, columnradius*2);
		float result = length(p) - columnradius;
		result = min(result, p.x);
		result = min(result, a);
		return min(result, b);
	} else {
		return min(a, b);
	}
}

//Function opU:
//Boolean operation: union. Combines 2 distance fields.
//From http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
vec4 opU( vec4 d1, vec4 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

//Function opS:
//Boolean operation: subtraction. Subtracts distance field d2 from d1.
//From http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float opS( float d1, float d2 )
{
    return max(-d1,d2);
}

//Function opI:
//Boolean operation: intersection. Intersection between distance field d1 and d2.
//From http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float opI( float d1, float d2 )
{
    return max(d1,d2);
}

//Function opMorph:
//Boolean operation: morph. Morphs distance field d1 to d2, using A (range 0-1).
float opMorph(float d1, float d2, float a)
{
    a = clamp(a,0.0,1.0);
    return a * d1 + (1.0 - a) * d2;
}

//Signed distance to a sphere:
//P is the position of the ray relative to the object.
//S is the sphere's radius.
//From http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdSphere(vec3 pc, float s, mat3 r)
{
	vec3 p = r * pc;
	return length(p) - s;
}

//Signed distance to an infinite plane:
//P is the position of the ray relative to the object.
//From http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdPlane(vec3 p)
{
    return p.y;
}

//Unsigned distance to a box:
//P is the position of the ray relative to the object.
//B is the box's size
//R is the box's rotation matrix (inverse, calculated on the CPU).
//From http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float udBox( vec3 pc, vec3 b, mat3 r )
{
	vec3 p = r * pc;
  return length(max(abs(p)-b,0.0));
}

//Signed distance to a box:
//P is the position of the ray relative to the object.
//B is the box's size.
//R is the box's rotation matrix (inverse, calculated on the CPU).
//From http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdBox(vec3 pc, vec3 b, mat3 r)
{
	vec3 p = r * pc;
	vec3 d = abs(p) - b;
	return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

//Distance to a mesh:
//BROKEN//
float udMesh(vec3 p, int id)
{
	return sdBox(p, vec3(float(id)), mat3(0.0));
}

//Function to get the corresponding UV coordinates on the texture atlas, using the object's UV coordinates.
vec4 getTexel(sampler2D tex, vec2 uv, vec3 offset, vec2 ts)
{
	vec2 size = vec2(8192.0);
	vec2 global_uv = offset.xy / size;
	vec2 local_uv = (uv * ts) / size;
	return Texel(tex, global_uv + local_uv);
}

//Function to texture a box, using Triplanar Mapping.
vec3 cubeTex(vec3 p, vec3 n, sampler2D tex, vec2 tr, vec3 offset, vec2 ts, mat3 r)
{
	p = r * p;
	n = r * n;
	return getTexel( tex, mod(p.yz, tr), offset, ts ).rgb*abs(n.x)+
				 getTexel( tex, mod(p.xz, tr), offset, ts ).rgb*abs(n.y)+
				 getTexel( tex, mod(p.xy, tr), offset, ts ).rgb*abs(n.z);
}

//Signed distance to a bumpmapped box:
//samplePos is the worldposition of the ray.
//boxPos is the box's position.
//boxDim is the box's size.
//bumptex is the bumpmap used.
//tr is the box's tex_repeat variable.
//offset is the box's tex_offset variable.
//ts is the bumpmap's size.
float sdBoxBump(vec3 samplePos, vec3 boxPos, vec3 boxDim, sampler2D bumptex, vec2 tr, vec3 offset, vec2 ts, mat3 r)
{
	vec3 normal;
	float bump = 0.0;
	if(length(samplePos-boxPos) < length(boxDim))
	{
		normal = normalize(samplePos-boxPos);
		vec3 bumpcol = cubeTex(samplePos*0.1, normal, bumptex, tr, offset, ts, r);
		bump = bumpcol.g*BUMP_FACTOR;
	}
	vec3 d = abs(samplePos-boxPos) - boxDim;
	return min(max(d.x,max(d.y,d.z)),0.0) +
		length(max(d,0.0))+bump;
}

//http://research.microsoft.com/en-us/um/people/hoppe/ravg.pdf
//For the Bezier Curve.
float det( vec2 a, vec2 b ) { return a.x*b.y-b.x*a.y; }
vec3 getClosest( vec2 b0, vec2 b1, vec2 b2 )
{
    float a =     det(b0,b2);
    float b = 2.0*det(b1,b0);
    float d = 2.0*det(b2,b1);
    float f = b*d - a*a;
    vec2  d21 = b2-b1;
    vec2  d10 = b1-b0;
    vec2  d20 = b2-b0;
    vec2  gf = 2.0*(b*d21+d*d10+a*d20); gf = vec2(gf.y,-gf.x);
    vec2  pp = -f*gf/dot(gf,gf);
    vec2  d0p = b0-pp;
    float ap = det(d0p,d20);
    float bp = 2.0*det(d10,d0p);
    float t = clamp( (ap+bp)/(2.0*a+b+d), 0.0 ,1.0 );
    return vec3( mix(mix(b0,b1,t), mix(b1,b2,t),t), t );
}

//Unsupported right now, but will work on this.
//By Inigo Quilez, IIRC.
vec4 sdBezier( vec3 a, vec3 b, vec3 c, vec3 p )
{
	vec3 w = normalize( cross( c-b, a-b ) );
	vec3 u = normalize( c-b );
	vec3 v = normalize( cross( w, u ) );

	vec2 a2 = vec2( dot(a-b,u), dot(a-b,v) );
	vec2 b2 = vec2( 0.0 );
	vec2 c2 = vec2( dot(c-b,u), dot(c-b,v) );
	vec3 p3 = vec3( dot(p-b,u), dot(p-b,v), dot(p-b,w) );

	vec3 cp = getClosest( a2-p3.xy, b2-p3.xy, c2-p3.xy );

	return vec4( sqrt(dot(cp.xy,cp.xy)+p3.z*p3.z), cp.z, length(cp.xy), p3.z );
}

//Modulo function that supports negative numbers.
float fmod(float a, float b)
{
  if(a<0.0)
  {
      return b - mod(abs(a), b);
  }
  return mod(a, b);
}

//General texture mapping function.
//P is the worldposition where the object was hit.
//N is the surface normal corresponding to position P.
//T is the object's type.
//TS is the texture's size.
//tex is the texturemap.
//offset is the object's tex_offset variable.
vec3 get_texture(vec3 p, vec3 n, int t, vec2 ts, vec2 tr, sampler2D tex, vec3 offset, mat3 r)
{
	if (t == 1) //Plane. Has it's own math, because it's always perfectly level, thus faster to calculate.
	{
		vec2 uv = mod(p.xz, tr);
		if (uv.x > 0 && uv.y > 0 && uv.x < tr.x && uv.y < tr.y) return getTexel(tex, uv, offset, ts).rgb;
	} else if (t == 2) //Sphere. Has it's own math, because it's a little different to calculate.
	{
		// float u = asin(n.x)/PI + 0.5;
		// float v = asin(n.y)/PI + 0.5;
		float u = n.x/2 + 0.5;
		float v = n.y/2 + 0.5;
		return getTexel(tex, vec2(u, v), offset, ts).rgb;
	} else if (t == 4) //Cube. Just calls cubeTex.
	{
		return cubeTex(p, n, tex_atlas, tr, offset, ts, r);
	}
	return vec3(1.0);
}

//Function that "maps" the scene.
//pos is the worldposition of the ray.
RESULT map(vec3 pos)
{
	vec4 res = vec4(-1.0); //Variable for final result.
	int id = 0;
	float closest;

	if (object_amount > 0)
	{
		if (objects[0].Type == 1) //Plane.
		{
			float q = sdPlane(pos - objects[0].p);
			res = vec4(q,objects[0].color);
			closest = q;
		} else if (objects[0].Type == 2) //Sphere.
		{
			float q = sdSphere(pos - objects[0].p,objects[0].b.x, objects[0].r);
			res = vec4(q,objects[0].color);
			closest = q;
		} else if (objects[0].Type == 3) //Unsigned box.
		{
			float q = udBox(pos - objects[0].p,objects[0].b, objects[0].r);
			res = vec4(q,objects[0].color);
			closest = q;
		} else if (objects[0].Type == 4) //Signed box.
		{
			float q = 0.0;
			if (objects[0].hasBumpMap)
			{
				//float sdBoxBump(vec3 samplePos, vec3 boxPos, vec3 boxDim, sampler2D bumptex, vec2 tr, vec3 offset, vec2 ts)
				q = sdBoxBump(pos, objects[0].p, objects[0].b, bump_atlas, objects[0].texrepeat, objects[0].bump_offset, objects[0].texsize, objects[0].r);
				// q = sdBox(pos - objects[0].p,objects[0].b);
			} else {
				q = sdBox(pos - objects[0].p,objects[0].b, objects[0].r);
			}
			res = vec4(q,objects[0].color);
			closest = q;
		} else if (objects[0].Type == 5) //Mesh.
		{
			float q = udMesh(pos - objects[0].p, int(objects[0].tex_offset.x));
			res = vec4(q, objects[0].color);
			closest = q;
		}
		id = objects[0].i;

		for (int o = 1; o < 1024; o++) //Constant length loop, to make it faster.
		{
			if (o>object_amount) break; //To break the loop when it is going over the limit.
			//Using the if-statement to break the loop and having a constant loop length, we can make the loop a lot faster.
			if (objects[o].Type == 1)
			{
				float q = sdPlane(pos - objects[o].p);
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = o;
				}
			} else if (objects[o].Type == 2)
			{
				float q = sdSphere(pos - objects[o].p,objects[o].b.x, objects[o].r);
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = o;
				}
			} else if (objects[o].Type == 3)
			{
				float q = udBox(pos - objects[o].p,objects[o].b, objects[o].r);
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = o;
				}
			} else if (objects[o].Type == 4)
			{
				float q = 0.0;
				if (objects[o].hasBumpMap)
				{
					q = sdBoxBump(pos, objects[o].p, objects[o].b, bump_atlas, objects[o].texrepeat, objects[o].bump_offset, objects[o].texsize, objects[o].r);
					// q = sdBox(pos - objects[o].p,objects[o].b);
				} else {
					q = sdBox(pos - objects[o].p,objects[o].b, objects[o].r);
				}
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = o;
				}
			} else if (objects[o].Type == 5) //A mesh
			{
				float q = udMesh(pos - objects[o].p, int(objects[o].tex_offset.x));
				res = opU(res, vec4(q, objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = o;
				}
			}
		}
	}

  RESULT r;
	r.re = res;
	r.i = id;
  return r;
}

//Function for glass.
//BROKEN//
vec3 getGlass(vec3 pos, vec3 dir)
{
	float tmin = 0.005;
	float tmax = view_distance/5.0;

	float tp1 = (0.0 - pos.y)/dir.y; if (tp1 > 0.0) tmax = min(tmax, tp1);
	float tp2 = (120 - pos.y)/dir.y; if (tp2 > 0.0) { if (pos.y > 120) tmin = max(tmin, tp2);
																									 else tmax = min(tmax, tp2); }

	float t = tmin;
	vec3 m = vec3(0.0);
	int id = 0;
	for (int i=0; i<16; i++)
	{
			float precis = 0.0005*t;
			RESULT r = map(pos + dir*t);
			vec4 res = r.re;
			id = r.i;
			if (t>tmax || res.x < precis) break;
			t += res.x*STEP_SIZE;
			m = res.yzw;
			// vec3 newdir = refract(dir, calcNormal(pos + dir*t), ior);
			// m += getGlass(pos + dir*t, newdir);
	}

	if (t>tmax) m=vec3(-15.0);
	return m;
}

//Softshadow function.
//RO is the ray's origin, in this case the light's origin.
//RD is the ray's direction, in this case the light's direction.
//mint is the near plane value.
//tmax is the far plane value.
float softshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax )
{
	float res = 1.0;
  float t = mint;
  for( int i=0; i<64; i++ )
  {
		float h = map( ro + rd*t ).re.x*STEP_SIZE;
    res = min( res, 8.0*h/t );
    t += clamp( h, 0.02, 0.10 );
    if( h<0.001 || t>tmax ) break;
  }
  return clamp( res, 0.0, 1.0 );
}

//Calculates the normal, by sampling the scene multiple times with small offsets.
//Using the values it can determine the surface normal.
//MAGIC//
vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*map( pos + e.xyy ).re.x +
					  e.yyx*map( pos + e.yyx ).re.x +
					  e.yxy*map( pos + e.yxy ).re.x +
					  e.xxx*map( pos + e.xxx ).re.x );
}

//Casts a ray through the scene.
//pos is the ray's origin.
//dir is the ray's direction.
RESULT castRay(vec3 pos, vec3 dir)
{
    float tmin = 0.005;
    float tmax = view_distance;

    float tp1 = (0.0 - pos.y)/dir.y; if (tp1 > 0.0) tmax = min(tmax, tp1);
    float tp2 = (120 - pos.y)/dir.y; if (tp2 > 0.0) { if (pos.y > 120) tmin = max(tmin, tp2);
                                                     else tmax = min(tmax, tp2); }

    float t = tmin;
    vec3 m = vec3(0.0);
		int id = 0;
    for (int i=0; i<SAMPLES; i++)
    {
        float precis = 0.0005*t;
        RESULT r = map(pos + dir*t);
				vec4 res = r.re;
				id = r.i;
				float a = objects[id].alpha;
				float ior = 0.8;
        if (t>tmax || res.x < precis) break;
        t += res.x*STEP_SIZE;
        m = res.yzw;
    }

    if (t>tmax) m=vec3(-15.0);
    //return vec4(t, m);
		RESULT re;
		re.re = vec4(t, m);
		re.i = id;
		return re;
}

//Function that calculates AO.
//It does a small raymarch in the surface normal's direction, to determine how close stuff is to the object.
//pos is the worldposition where the object was hit.
//nor is the surface normal corresponding to pos.
float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
  float sca = 1.0;
  for( int i=0; i<50; i++ )
  {
      float hr = 0.01 + 0.12*float(i)/50.0;
      vec3 aopos =  nor * hr + pos;
      float dd = map( aopos ).re.x*STEP_SIZE;
      occ += -(dd-hr)*sca;
      sca *= 0.9;
  }
  return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );
}

//Function to calculate fog.
//pos is the ray's origin.
//rd is the ray's direction.
//sky_color is the color of the sky.
vec3 calcFog(vec3 pos, vec3 rd, vec3 sky_color)
{
	float d = length(pos)*0.6*fog_density;
	d = clamp(pow(d,2),0.0,1.0);
	vec3 col = sky_color * d;
	col = clamp(col,0.0,1.0-fog_density/10);
	// vec3 col = sky_color*d;
	return col;
}

//------------------------------------------------------------------------------
// BRDF
//------------------------------------------------------------------------------

//This is where the real magic happens.
//Behold, the PBR lighting system.

float pow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

float D_GGX(float linearRoughness, float NoH, const vec3 h) {
    // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"
    float oneMinusNoHSquared = 1.0 - NoH * NoH;
    float a = NoH * linearRoughness;
    float k = linearRoughness / (oneMinusNoHSquared + a * a);
    float d = k * k * (1.0 / PI);
    return d;
}

float V_SmithGGXCorrelated(float linearRoughness, float NoV, float NoL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    float a2 = linearRoughness * linearRoughness;
    float GGXV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
    float GGXL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
    return 0.5 / (GGXV + GGXL);
}

vec3 F_Schlick(const vec3 f0, float VoH) {
    // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
    return f0 + (vec3(1.0) - f0) * pow5(1.0 - VoH);
}

float F_Schlick(float f0, float f90, float VoH) {
    return f0 + (f90 - f0) * pow5(1.0 - VoH);
}

float Fd_Burley(float linearRoughness, float NoV, float NoL, float LoH) {
    // Burley 2012, "Physically-Based Shading at Disney"
    float f90 = 0.5 + 2.0 * linearRoughness * LoH * LoH;
    float lightScatter = F_Schlick(1.0, f90, NoL);
    float viewScatter  = F_Schlick(1.0, f90, NoV);
    return lightScatter * viewScatter * (1.0 / PI);
}

float Fd_Lambert() {
    return 1.0 / PI;
}

//------------------------------------------------------------------------------
// Indirect lighting
//------------------------------------------------------------------------------

//MORE LIGHTING
//Handles indirect lighting. Not GI, but it does handle reflections.

vec3 Irradiance_SphericalHarmonics(const vec3 n) {
    // Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
    return max(
          vec3( 0.754554516862612,  0.748542953903366,  0.790921515418539)
        + vec3(-0.083856548007422,  0.092533500963210,  0.322764661032516) * (n.y)
        + vec3( 0.308152705331738,  0.366796330467391,  0.466698181299906) * (n.z)
        + vec3(-0.188884931542396, -0.277402551592231, -0.377844212327557) * (n.x)
        , 0.0);
}

vec2 PrefilteredDFG_Karis(float roughness, float NoV) {
    // Karis 2014, "Physically Based Material on Mobile"
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572,  0.022);
    const vec4 c1 = vec4( 1.0,  0.0425,  1.040, -0.040);

    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;

    return vec2(-1.04, 1.04) * a004 + r.zw;
}

//Hardshadow function.
//Pretty much unused, but the BRDF functions sometimes use it.
//No reason to use it over the softshadow function, as it has the same artifacts, same performance but looks worse.
float shadow(in vec3 origin, in vec3 direction) {
  float hit = 1.0;
  float t = 0.02;

  for (int i = 0; i < 1000; i++) {
      float h = map(origin + direction * t).re.x;
      if (h < 0.001) return 0.0;
      t += h;
      hit = min(hit, 10.0 * h / t);
      if (t >= 2.5) break;
  }

  return clamp(hit, 0.0, 1.0);
}

//Oh boy.
//The final BRDF function that ties it all together.
//pos is the worldposition where the object was hit.
//n is the surface normal corresponding to pos.
//rd is the ray's direction.
//l is the current light's direction.
//lp is the current light's position.
//range is the light's range (not used for the directional light).
//baseColor is the object's base color.
//roughness is the object's roughness.
//metallic is the object's metallic value.
vec3 BRDF (vec3 pos, vec3 n, vec3 rd, vec3 l, vec3 lp, float range, vec3 baseColor, float roughness, float metallic)
{
	vec3 color = vec3(0.0);

	vec3 v = normalize(-rd);
	vec3 h = normalize(v + l);
	vec3 r = normalize(reflect(rd, n));

	float NoV = abs(dot(n, v)) + 1e-5;
	float NoL = saturate(dot(n, l));
	float NoH = saturate(dot(n, h));
	float LoH = saturate(dot(l, h));

	float intensity = 2.0; //Default: 2.0
	float indirectIntensity = 0.64; //Default: 0.64

	if (range > 0) { //This is probably the worst distance calculation possible. But it seems to work.
		intensity = 0.0;
		indirectIntensity = 0.0;
		intensity += clamp(range-distance(pos, lp),0.0,range);
		indirectIntensity += clamp(range-distance(pos, lp),0.0,range)/3.90625;
	}

	float linearRoughness = roughness * roughness;
	vec3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
	vec3 f0 = 0.04 * (1.0 - metallic) + baseColor.rgb * metallic;

	float attenuation = softshadow(pos, l, 0.02, 25.0);

	indirectIntensity *= attenuation;

	//Specular BRDF
	float D = D_GGX(linearRoughness, NoH, h) * attenuation;
	float V = V_SmithGGXCorrelated(linearRoughness, NoV, NoL);
	vec3 F = F_Schlick(f0, LoH);
	vec3 Fr = (D * V) * F;

	//Diffuse BRDF
	vec3 Fd = diffuseColor * Fd_Burley(linearRoughness, NoV, NoL, LoH);

	color = Fd + Fr;
	color *= (intensity * attenuation * NoL) + vec3(0.98, 0.92, 0.89);

	//Diffuse Indirect
	vec3 indirectDiffuse = Irradiance_SphericalHarmonics(n) * Fd_Lambert();

	RESULT indirectHit = castRay(pos, r);
	vec3 tex_col = objects[indirectHit.i].avg_tex_col;
	vec3 indirectSpecular = indirectHit.re.yzw;
	if (indirectHit.re.yzw == vec3(-15.0)) {
		indirectSpecular = vec3(0.7, 0.9, 1.0) + rd.y*0.8;
	}

	//Indirect Contribution
	vec2 dfg = PrefilteredDFG_Karis(roughness, NoV);
	vec3 specularColor = f0 * dfg.x + dfg.y;
	vec3 ibl = diffuseColor * indirectDiffuse + indirectSpecular * specularColor * attenuation;

	color += ibl * indirectIntensity;

	return color;
}

//Function to tonemap the scene using ACES.
//x is the current pixel color (no alpha, as the final result doesn't contain any alpha either).
vec3 Tonemap_ACES(const vec3 x) {
  // Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return (x * (a * x + b)) / (x * (c * x + d) + e);
}

//The render function:
//This function performs the following steps:
//1. Call castRay function.
//2. Apply lighting, ambient occlusion, fog, etc.
//3. DONE!
//Parameters:
//ro is the ray's origin.
//rd is the ray's direction.
vec3 render( in vec3 ro, in vec3 rd )
{
	vec3 col = vec3(0.7, 0.9, 1.0) + rd.y*0.8;
	vec3 c = vec3(0.0);
  //vec4 res = castRay(ro,rd);
	RESULT r = castRay(ro, rd);
	vec4 res = r.re;
	int id = r.i;
  float t = res.x;
	vec3 m = res.yzw;

	if (m != vec3(-15.0))
	{
		vec3 pos = ro + t*rd;
		vec3 nor = calcNormal( pos );
		vec3 ref = reflect( rd, nor );

		// material
		col = m;
		//vec3 get_texture(vec3 p, vec3 n, int t, vec2 ts, vec2 tr, sampler2D tex, vec3 offset)
		if (objects[id].isTextured) col *= get_texture(pos - objects[id].p, nor, objects[id].Type, objects[id].texsize, objects[id].texrepeat, tex_atlas, objects[id].tex_offset, objects[id].r);
		if (m.x == -2.0)
		{
			if (m.y == -2.0)
			{
				if (m.z == -2.0)
				{
					float f = mod( floor(5.0*pos.z) + floor(5.0*pos.x), 2.0);
					col = 0.3 + 0.1*f*vec3(1.0);
				}
			}
		}

		// lighting
		float occ = calcAO( pos, nor );
		if (GI > 0) {
			//GI is 1, so prepare yourself for a lot of pain.
			//Goodbye life
			//Update: not as bad as it appeared
			for (int i=0; i<1024; i++) {
				if (i>light_amount) break;
				if (lights[i].Type == 1) {
					vec3 lig = normalize(lights[i].d);
					c += BRDF(pos, nor, rd, lig, vec3(0.0), -1, col, objects[id].roughness, objects[id].metallic) * occ;
				} else if (lights[i].Type == 2) {
					vec3 lig = normalize(lights[i].p - pos);
					//lights[i].d.x is the range
					c += BRDF(pos, nor, rd, lig, lights[i].p, lights[i].d.x, col, objects[id].roughness, objects[id].metallic) * occ;
				}
			}
		} else {
			for (int i=0; i<1024; i++)
			{
				if (i>light_amount) break;
				if (lights[i].Type == 1) { //Directional Light
					vec3 lig = normalize(lights[i].d);
					float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
					float bac = clamp( dot( nor, normalize(vec3(-lig.x,0.0,-lig.z))), 0.0, 1.0 )*clamp( 1.0-pos.y,0.0,1.0);
					float dom = smoothstep( -0.1, 0.1, ref.y );
					float fre = pow( clamp(1.0+dot(nor,rd),0.0,1.0), 2.0 );
					float spe = pow(clamp( dot( ref, lig ), 0.0, 1.0 ),16.0);
					float amb = clamp( 0.5+0.5*nor.y, 0.0, 1.0 );

					dif *= softshadow( pos, lig, 0.02, 2.5 );
					dom *= softshadow( pos, ref, 0.02, 2.5 );

					vec3 lin = vec3(0.0);
					lin += 1.30*dif*lights[i].color;
					lin += 2.00*spe*lights[i].color*dif;
					lin += 0.40*amb*vec3(0.40,0.60,1.00)*occ*lights[i].color;
					lin += 0.50*dom*vec3(0.40,0.60,1.00)*occ*lights[i].color;
					lin += 0.50*bac*vec3(0.25,0.25,0.25)*occ*lights[i].color;
					lin += 0.25*fre*vec3(1.00,1.00,1.00)*occ*lights[i].color;
					c = c + col*lin;

					//col = mix( col, vec3(0.8,0.9,1.0), 1.0-exp( -0.0002*t*t*t ) );
				}
				else if (lights[i].Type == 2) { //Point Light
					float dist = abs(length(lights[i].p - pos))/lights[i].d.x;
					vec3 lig = lights[i].p - pos;
					float dif = 1.0 - clamp( dist, 0.0, 1.0 );
					float bac = clamp( dot( nor, normalize(vec3(-lig.x,0.0,-lig.z))), 0.0, 1.0 )*clamp( 1.0-pos.y,0.0,1.0) * dif;
					float dom = smoothstep( -0.1, 0.1, ref.y ) * dif;
					float fre = pow( clamp(1.0+dot(nor,rd),0.0,1.0), 2.0 ) * dif;
					float spe = pow(clamp( dot( ref, lig ), 0.0, 1.0 ),16.0) * dif;
					float amb = clamp( 0.5+0.5*nor.y, 0.0, 1.0 ) * dif;

					dif *= softshadow( pos, lig, 0.02, 2.5 );
					dom *= softshadow( pos, ref, 0.02, 2.5 );

					vec3 lin = vec3(0.0);
					lin += 1.30*dif*lights[i].color;
					lin += 2.00*spe*lights[i].color;
					lin += 0.40*amb*vec3(0.40,0.60,1.00)*occ*lights[i].color;
					lin += 0.50*dom*vec3(0.40,0.60,1.00)*occ*lights[i].color;
					lin += 0.50*bac*vec3(0.25,0.25,0.25)*occ*lights[i].color;
					lin += 0.25*fre*vec3(1.00,1.00,1.00)*occ*lights[i].color;
					c = c + col*lin;

					//c = mix( c, vec3(0.8,0.9,1.0), 1.0-exp( -0.0002*t*t*t ) );
				}
			}
		}

		vec3 fog_pos = pos - cam_pos;
		//c = c + calcFog(fog_pos, rd, vec3(0.7, 0.9, 1.0) + rd.y*0.8);
		// Exponential distance fog
		float d = length(fog_pos);
		// Tone mapping
	  c = Tonemap_ACES(c);
	  c = mix(c, vec3(0.7, 0.9, 1.0) + rd.y*0.8, 1.0 - exp2(-0.011 * d * d * fog_density));
	} else {
		return (vec3(0.7, 0.9, 1.0) + rd.y*0.8);
	}

	return vec3( clamp(c,0.0,1.0) );
}

//setCamera is a function to get the camera's rotation matrix.
//ro is the ray's origin.
//ta is the ray's direction.
//cr is the ray's rotation around the camera's direction (roll).
mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

//Main function.
//color is the color drawn with inside Love2D.
//texture is the texture drawn to.
//texture_coords are the UV coordinates Love2D specifies.
//screen_coords are the current pixel's screen coordinates. Used to calculate the proper UV coordinates in my case.
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec2 fragCoord = vec2(screen_coords.x, screen_res.y - screen_coords.y);
#if CHECKERBOARD
	float offset = mod(fragCoord.y, 2.0);
	if (mod(fragCoord.x + offset, 2.0) > 0.5)
	{
		return vec4(0.0);
	}
#endif
	float time = 15.0 + iTime.x;

  vec3 tot = vec3(0.0,0.0,0.0);
#if AA>1 //For multisampling.
  for( int m=0; m<AA; m++ )
  for( int n=0; n<AA; n++ )
  {
    //Pixel coordinates
    vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
    vec2 p = (-screen_res.xy + 2.0*(fragCoord+o))/screen_res.y;
#else
    vec2 p = (-screen_res.xy + 2.0*fragCoord)/screen_res.y;
#endif

		//Camera
    vec3 ro = cam_pos;
		vec3 ta = cam_pos + cam_dir;
		//Camera-to-world matrix
		mat3 ca = setCamera(ro, ta, 0.0);
    //Ray direction
    vec3 rd = ca * normalize(vec3(p.xy,2.0));

    //Render the scene
    vec3 col = render( ro, rd );

		//Apply gamma correction.
    col = pow( col, vec3(0.4545) );

    tot += col;
#if AA>1 //Again, for multisampling.
    }
    tot /= float(AA*AA);
#endif

    return vec4( tot, 1.0 );
}
