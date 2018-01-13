#pragma language glsl3

#define SAMPLES 128

#define AA 1
#define GI 1

#define BUMP_FACTOR 0.015

#define STEP_SIZE 1

#define saturate(x) clamp(x, 0.0, 1.0)
#define PI 3.14159265359

int GI_maxDistance = 20;
int GI_maxBounces = 4;

uniform vec2 iTime;
uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform int object_amount;
uniform int light_amount;
uniform sampler2D tex_atlas;
uniform sampler2D bump_atlas;
uniform struct Object
{
	int Type;
	int i; //Object ID
	vec3 p; //Vector 3: position
	vec3 b; //Vector 3: size (if sphere, only x is used)
	mat3 r; //Matrix 3: rotation
	vec3 color;
	bool isTextured;
	bool hasBumpMap;
	vec3 tex_offset;
	vec3 bump_offset;
	vec2 texsize;
	vec2 texrepeat;
	vec3 avg_tex_col;
	float alpha;
	float ref;
	float roughness;
	float metallic;
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
uniform vec2 screen_res;


// mat3 rotate3DX(float a) { return mat3(1.,0.,0.,0.,cos(a),-sin(a),0,sin(a),cos(a));}
// mat3 rotate3DY(float a) { return mat3(cos(a),0.,sin(a),0.,1.,0.,-sin(a),0.,cos(a));}
// mat3 rotate3DZ(float a) { return mat3(cos(a),-sin(a),0.,sin(a),cos(a),0.,0.,0.,1.);}


//Define RESULT
struct RESULT {
	vec4 re;
	int i;
};

struct L_RESULT {
	float t;
	vec4 m; //Material
	int id;
};

struct GI_TRACE {
	vec3 pos;
	vec3 dir;
	int id;
	vec4 m; //Material
};
