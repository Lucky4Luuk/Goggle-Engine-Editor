#define AA 1

uniform vec2 iTime;
uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform int object_amount;
uniform struct Object
{
	int Type;
	vec3 p; //Vector 3: position
	vec3 b; //Vector 3: size (if sphere, only x is used)
	vec3 color;
	float alpha;
} objects[3000];

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
    if (a > 1.0)
        a = 1.0;
    if (a < 0.0)
        a = 0.0;
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

vec4 map(vec3 pos)
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
	
	if (object_amount > 0)
	{
		if (objects[0].Type == 1)
		{
			res = vec4(sdPlane(pos - objects[0].p),objects[0].color);
		} else if (objects[0].Type == 2)
		{
			res = vec4(sdSphere(pos - objects[0].p,objects[0].b.x),objects[0].color);
		} else if (objects[0].Type == 3)
		{
			res = vec4(udBox(pos - objects[0].p,objects[0].b),objects[0].color);
		} else if (objects[0].Type == 4)
		{
			res = vec4(sdBox(pos - objects[0].p,objects[0].b),objects[0].color);
		}
		
		for (int o = 1; o < object_amount; o++)
		{
			if (objects[o].Type == 1)
			{
				res = opU(res,vec4(sdPlane(pos - objects[o].p),objects[o].color));
			} else if (objects[o].Type == 2)
			{
				res = opU(res,vec4(sdSphere(pos - objects[o].p,objects[o].b.x),objects[o].color));
			} else if (objects[o].Type == 3)
			{
				res = opU(res,vec4(udBox(pos - objects[o].p,objects[o].b),objects[o].color));
			} else if (objects[o].Type == 4)
			{
				res = opU(res,vec4(sdBox(pos - objects[o].p,objects[o].b),objects[o].color));
			}
		}
	}
    
    return res;
}

vec4 castRay(vec3 pos, vec3 dir)
{    
    float tmin = 0.05;
    float tmax = 20.0;

    float tp1 = (0.0 - pos.y)/dir.y; if (tp1 > 0.0) tmax = min(tmax, tp1);
    float tp2 = (1.6 - pos.y)/dir.y; if (tp2 > 0.0) { if (pos.y > 1.6) tmin = max(tmin, tp2);
                                                     else tmax = min(tmax, tp2); }
    
    float t = tmin;
    vec3 m = vec3(-1.0);
    for (int i=0; i<64; i++)
    {
        float precis = 0.0005*t;
        vec4 res = map(pos + dir*t);
        if (res.x<precis || t>tmax) break;
        t += res.x;
        m = res.yzw;
    }
    
    if (t>tmax) m=vec3(-1.0);
    return vec4(t, m);
}

float softshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax )
{
	float res = 1.0;
    float t = mint;
    for( int i=0; i<16; i++ )
    {
		float h = map( ro + rd*t ).x;
        res = min( res, 8.0*h/t );
        t += clamp( h, 0.02, 0.10 );
        if( h<0.001 || t>tmax ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*map( pos + e.xyy ).x + 
					  e.yyx*map( pos + e.yyx ).x + 
					  e.yxy*map( pos + e.yxy ).x + 
					  e.xxx*map( pos + e.xxx ).x );
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
    for( int i=0; i<5; i++ )
    {
        float hr = 0.01 + 0.12*float(i)/4.0;
        vec3 aopos =  nor * hr + pos;
        float dd = map( aopos ).x;
        occ += -(dd-hr)*sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );    
}

vec3 render( in vec3 ro, in vec3 rd )
{
    vec3 col = vec3(0.7, 0.9, 1.0) +rd.y*0.8;
    vec4 res = castRay(ro,rd);
    float t = res.x;
	vec3 m = res.yzw;
	
	if (m != vec3(-1.0))
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
		vec3  lig = normalize( vec3(-0.4, 0.7, -0.6) );
		float amb = clamp( 0.5+0.5*nor.y, 0.0, 1.0 );
		float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
		float bac = clamp( dot( nor, normalize(vec3(-lig.x,0.0,-lig.z))), 0.0, 1.0 )*clamp( 1.0-pos.y,0.0,1.0);
		float dom = smoothstep( -0.1, 0.1, ref.y );
		float fre = pow( clamp(1.0+dot(nor,rd),0.0,1.0), 2.0 );
		float spe = pow(clamp( dot( ref, lig ), 0.0, 1.0 ),16.0);
		
		dif *= softshadow( pos, lig, 0.02, 2.5 );
		dom *= softshadow( pos, ref, 0.02, 2.5 );

		vec3 lin = vec3(0.0);
		lin += 1.30*dif*vec3(1.00,0.80,0.55);
		lin += 2.00*spe*vec3(1.00,0.90,0.70)*dif;
		lin += 0.40*amb*vec3(0.40,0.60,1.00)*occ;
		lin += 0.50*dom*vec3(0.40,0.60,1.00)*occ;
		lin += 0.50*bac*vec3(0.25,0.25,0.25)*occ;
		lin += 0.25*fre*vec3(1.00,1.00,1.00)*occ;
		col = col*lin;

		col = mix( col, vec3(0.8,0.9,1.0), 1.0-exp( -0.0002*t*t*t ) );
	}

	return vec3( clamp(col,0.0,1.0) );
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