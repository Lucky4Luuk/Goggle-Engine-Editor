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
