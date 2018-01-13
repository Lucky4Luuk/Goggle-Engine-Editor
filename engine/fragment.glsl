#define AA 1
#define GI 1

int GI_maxDistance = 20;
int GI_maxBounces = 4;

uniform vec2 iTime;
uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform int object_amount;
uniform int light_amount;
uniform struct Object
{
	int Type;
	int i; //Object ID
	vec3 p; //Vector 3: position
	vec3 b; //Vector 3: size (if sphere, only x is used)
	vec3 color;
	float alpha;
} objects[30];
uniform struct Light
{
	int Type;
	vec3 p;
	vec3 d;
	vec3 color;
} lights[50];
uniform float fog_density;
uniform float view_distance;

//Define RESULT
struct RESULT {
	vec4 re;
	int i;
};

struct COLRESULT {
	int b;
	int id;
	vec3 pos;
};

struct L_RESULT {
	float t;
	vec3 m;
	int id;
};

struct GI_TRACE {
	vec3 p;
	vec3 rd;
	vec3 em;
	float BRDF;
	int id;
};

float opBlendChamfer(float d1, float d2, float r)
{
  float m = min(d1, d2);
  if (d1 < r && d2 < r) {
    return min(m, d1 + d2 - r);
  }
  return m;
}


vec4 opU( vec4 d1, vec4 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

float opS( float d1, float d2 )
{
    return max(-d1,d2);
}

float opI( float d1, float d2 )
{
    return max(d1,d2);
}

float opMorph(float d1, float d2, float a)
{
    a = clamp(a,0.0,1.0);
    return a * d1 + (1.0 - a) * d2;
}

// distance to sphere function (p is world position of the ray, s is sphere radius)
// from http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdSphere(vec3 p, float s)
{
	return length(p) - s;
}

float sdPlane(vec3 p)
{
    return p.y;
}

float udBox( vec3 p, vec3 b )
{
    return length(max(abs(p)-b,0.0));
}

float sdBox(vec3 p, vec3 b)
{
	vec3 d = abs(p) - b;
	return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float fmod(float a, float b)
{
    if(a<0.0)
    {
        return b - mod(abs(a), b);
    }
    return mod(a, b);
}

RESULT map(vec3 pos)
{
	//vec3 cp = vec3(0.0,0.0,0.0);

    //vec2 res = opU(vec2(sdPlane(pos - vec3(0.0,0.0,0.0) + cp),1.0),
    //               vec2(sdSphere(pos - vec3(0.0,0.5,0.0) + cp,0.5),46.9));

    //float b = opBlend(udBox(pos - vec3(1.0,0.5,0.0) + cp,vec3(0.5,0.5,0.5)),
    //                  sdSphere(pos - vec3(1.0,0.5,0.0) + cp,0.5),(sin(iTime.x)+1.0)/2.0);
    //res = opU(res, vec2(b,78.5));

    //b = opI(udBox(pos - vec3(-1.0,0.5 * (sin(iTime.x)+1.0)/2.0,0.0) + cp,vec3(0.5,0.5,0.5)),
    //        sdSphere(pos - vec3(-1.0,0.5,0.0) + cp,0.5));
    //res = opU(res, vec2(b,129.8));

    //b = opS(sdSphere(pos - vec3(-1.0,0.5,-1.0) + cp,0.5),
    //        udBox(pos - vec3(-1.0,0.5 * (sin(iTime.x))/1.0,-1.0) + cp,vec3(0.5,0.5,0.5)));
    //res = opU(res, vec2(b,22.4));

	vec4 res = vec4(-1.0);
	int id = 0;
	float closest;

	if (object_amount > 0)
	{
		if (objects[0].Type == 1)
		{
			float q = sdPlane(pos - objects[0].p);
			res = vec4(q,objects[0].color);
			closest = q;
		} else if (objects[0].Type == 2)
		{
			float q = sdSphere(pos - objects[0].p,objects[0].b.x);
			res = vec4(q,objects[0].color);
			closest = q;
		} else if (objects[0].Type == 3)
		{
			float q = udBox(pos - objects[0].p,objects[0].b);
			res = vec4(q,objects[0].color);
			closest = q;
		} else if (objects[0].Type == 4)
		{
			float q = sdBox(pos - objects[0].p,objects[0].b);
			res = vec4(q,objects[0].color);
			closest = q;
		}
		id = objects[0].i;

		for (int o = 1; o < 256; o++)
		{
			if (o > object_amount) break;
			if (objects[o].Type == 1)
			{
				float q = sdPlane(pos - objects[o].p);
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = objects[o].i;
				}
			} else if (objects[o].Type == 2)
			{
				float q = sdSphere(pos - objects[o].p,objects[o].b.x);
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = objects[o].i;
				}
			} else if (objects[o].Type == 3)
			{
				float q = udBox(pos - objects[o].p,objects[o].b);
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = objects[o].i;
				}
			} else if (objects[o].Type == 4)
			{
				float q = sdBox(pos - objects[o].p,objects[o].b);
				res = opU(res,vec4(q,objects[o].color));
				if (q < closest)
				{
					closest = q;
					id = objects[o].i;
				}
			}
		}
	}
    RESULT r;
		r.re = res;
		r.i = id;
    return r;
}

RESULT castRay(vec3 pos, vec3 dir)
{
    float tmin = 0.005;
    float tmax = view_distance;

    float tp1 = (0.0 - pos.y)/dir.y; if (tp1 > 0.0) tmax = min(tmax, tp1);
    float tp2 = (120 - pos.y)/dir.y; if (tp2 > 0.0) { if (pos.y > 120) tmin = max(tmin, tp2);
                                                     else tmax = min(tmax, tp2); }

    float t = tmin;
    vec3 m = vec3(-1.0);
		int id = 0;
    for (int i=0; i<64; i++)
    {
        float precis = 0.0005*t;
        RESULT r = map(pos + dir*t);
				vec4 res = r.re;
				id = r.i;
        if (res.x<precis || t>tmax) break;
        t += res.x;
        m = res.yzw;
    }

    if (t>tmax) m=vec3(-15.0);
    //return vec4(t, m);
		RESULT re;
		re.re = vec4(t, m);
		re.i = id;
		return re;
}

L_RESULT castLightRay(vec3 pos, vec3 dir, vec3 light_color, int cur_id)
{
    float tmin = 0.05;
    float tmax = view_distance;

    float tp1 = (0.0 - pos.y)/dir.y; if (tp1 > 0.0) tmax = min(tmax, tp1);
    float tp2 = (120 - pos.y)/dir.y; if (tp2 > 0.0) { if (pos.y > 120) tmin = max(tmin, tp2);
                                                     else tmax = min(tmax, tp2); }

    float t = tmin;
    vec3 m = vec3(0.0);
		int id = 0;
    for (int i=0; i<64; i++)
    {
        float precis = 0.0005*t;
        RESULT r = map(pos + dir*t);
				vec4 res = r.re;
				id = r.i;
        if (res.x<precis)
				{
					if (id != cur_id) break;
				}

				if (res.x>tmax) break;
        t += res.x;
        m = res.yzw;
    }

    if (t>tmax)
		{
			m=vec3(0.0);
			id = -1;
		}

		L_RESULT lre;
		lre.t = t;
		lre.m = m;
		lre.id = id;

    return lre;
}

float softshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax )
{
	float res = 1.0;
    float t = mint;
    for( int i=0; i<16; i++ )
    {
		float h = map( ro + rd*t ).re.x;
        res = min( res, 8.0*h/t );
        t += clamp( h, 0.02, 0.10 );
        if( h<0.001 || t>tmax ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*map( pos + e.xyy ).re.x +
					  e.yyx*map( pos + e.yyx ).re.x +
					  e.yxy*map( pos + e.yxy ).re.x +
					  e.xxx*map( pos + e.xxx ).re.x );
    /*
	vec3 eps = vec3( 0.0005, 0.0, 0.0 );
	vec3 nor = vec3(
	    map(pos+eps.xyy).x - map(pos-eps.xyy).x,
	    map(pos+eps.yxy).x - map(pos-eps.yxy).x,
	    map(pos+eps.yyx).x - map(pos-eps.yyx).x );
	return normalize(nor);
	*/
}

float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
  float sca = 1.0;
  for( int i=0; i<50; i++ )
  {
      float hr = 0.01 + 0.12*float(i)/50.0;
      vec3 aopos =  nor * hr + pos;
      float dd = map( aopos ).re.x;
      occ += -(dd-hr)*sca;
      sca *= 0.95;
  }
  return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );
}

COLRESULT calcCollision(in vec3 pos, in vec3 nor)
{
	COLRESULT cr;
	cr.b = 0;
	for (int i=1; i<2; i++)
	{
		float hr = 0.01 + 0.12*float(i)/4.0;
		vec3 colpos = nor * hr + pos;
		float dd = map(colpos).re.x;
		if (dd < 0.01)
		{
			cr.b = 1;
			cr.id = map(colpos).i;
			cr.pos = objects[cr.id].p;
			return cr;
		}
	}
	return cr;
}

vec3 calcFog(vec3 pos, vec3 rd)
{
	float d = length(pos)*0.6*fog_density;
	d = clamp(pow(d,2),0.0,1.0);
	vec3 col = vec3(0.7, 0.9, 1.0)*d + 0.1*d;
	col = clamp(col,0.0,1.0-fog_density/10);
	//vec3 col = sky_color*d;
	return col;
}

GI_TRACE GI_TracePath(vec3 pos, vec3 dir, int id)
{
	//https://en.wikipedia.org/wiki/Path_tracing
	L_RESULT lre = castLightRay(pos, dir, vec3(1.0), id);

	vec3 m = lre.m;
	vec3 em = vec3(1.0); //Amount of light that has fallen on the current position, aka light level of object at this position;
	float reflectance = 0.5;

	vec3 p = pos + dir*lre.t;
	vec3 nor = calcNormal(p);
	vec3 rd = reflect(dir, nor);

	float cos_theta = dot(rd, nor);
	float BRDF = 2.0 * reflectance * cos_theta;
	//vec3 reflected = GI_TracePath(p, rd, lre.id);

	//return em + (BRDF * reflected);

	GI_TRACE gre;
	gre.em = em;
	gre.BRDF = BRDF;
	gre.p = p;
	gre.rd = rd;
	gre.id = id;

	return gre;
}

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
		for (int i=0; i<light_amount; i++)
		{
			if (GI>0) {
				if (lights[i].Type == 1) {
					vec3 GI_Color = vec3(0.0);

					vec3 p = lights[i].p;
					vec3 d = lights[i].d;
					int gi_id = id;

					for (int depth=0; depth<GI_maxBounces; depth++) {
						GI_TRACE gre = GI_TracePath(p, d, gi_id);
						p = gre.p;
						d = gre.rd;
						gi_id = gre.id;

						GI_Color += gre.em + gre.BRDF * GI_Color;
					}

					c = c + col*GI_Color*max(lights[i].color,vec3(1.0));
				}
			} else {
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
		c = c + calcFog(fog_pos, rd);

		//Physics
		COLRESULT colres = calcCollision(pos, nor);
		if (colres.b == 1)
		{
			c = c * vec3(1.0,0.0,0.0);
		}
	} else {
		return (vec3(0.7, 0.9, 1.0) + rd.y*0.8);
	}

	return vec3( clamp(c,0.0,1.0) );
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec2 fragCoord = vec2(screen_coords.x, love_ScreenSize.y - screen_coords.y);
	float time = 15.0 + iTime.x;

  vec3 tot = vec3(0.0,0.0,0.0);
#if AA>1
  for( int m=0; m<AA; m++ )
  for( int n=0; n<AA; n++ )
  {
    // pixel coordinates
    vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
    vec2 p = (-love_ScreenSize.xy + 2.0*(fragCoord+o))/love_ScreenSize.y;
#else
    vec2 p = (-love_ScreenSize.xy + 2.0*fragCoord)/love_ScreenSize.y;
#endif

		// camera
    vec3 ro = cam_pos;
		vec3 ta = cam_pos + cam_dir;
		// camera-to-world matrix
		mat3 ca = setCamera(ro, ta, 0.0);
    // ray direction
    vec3 rd = ca * normalize(vec3(p.xy,2.0));

    // render
    vec3 col = render( ro, rd );

		// gamma
    col = pow( col, vec3(0.4545) );

    tot += col;
#if AA>1
    }
    tot /= float(AA*AA);
#endif

    return vec4( tot, 1.0 );
}
