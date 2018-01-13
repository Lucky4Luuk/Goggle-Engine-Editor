struct Face
{
  vec3 A;
  vec3 B;
  vec3 C;
};

uniform Face faces[3072];
uniform int face_amount;
uniform int VolumeZ;

float dot2( in vec3 v ) { return dot(v,v); }
float udTriangle( vec3 p, vec3 a, vec3 b, vec3 c )
{
    vec3 ba = b - a; vec3 pa = p - a;
    vec3 cb = c - b; vec3 pb = p - b;
    vec3 ac = a - c; vec3 pc = p - c;
    vec3 nor = cross( ba, ac );

    return sqrt(
    (sign(dot(cross(ba,nor),pa)) +
     sign(dot(cross(cb,nor),pb)) +
     sign(dot(cross(ac,nor),pc))<2.0)
     ?
     min( min(
     dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.0,1.0)-pa),
     dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.0,1.0)-pb) ),
     dot2(ac*clamp(dot(ac,pc)/dot2(ac),0.0,1.0)-pc) )
     :
     dot(nor,pa)*dot(nor,pa)/dot2(nor) );
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
  //love_PixelColor = Texel(MainTex, vec3(VaryingTexCoord.xy, VolumeZ)) * VaryingColor;
  vec3 p = vec3(texture_coords.xy, VolumeZ / 50.0);
  float minvalue = 100000;
  vec3 ray = vec3(1.0,0.0,0.0);
  float d = udTriangle(p, faces[0].A / 50.0, faces[0].B / 50.0, faces[0].C / 50.0);
  for (int i=1; i<3072; i++)
  {
    if (i > face_amount) break;
    vec3 a = faces[i].A / 50.0;
    vec3 b = faces[i].B / 50.0;
    vec3 c = faces[i].C / 50.0;

    d = min(d, udTriangle(p, a, b, c));
  }

  d = clamp(d, 0.0, 1.0);

  return vec4(d, d, d, 1.0);
}
