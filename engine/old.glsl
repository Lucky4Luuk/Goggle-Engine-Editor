vec3 lig = normalize(lights[i].d);
float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
float bac = clamp( dot( nor, normalize(vec3(-lig.x,0.0,-lig.z))), 0.0, 1.0 )*clamp( 1.0-pos.y,0.0,1.0);
float dom = smoothstep( -0.1, 0.1, ref.y );
float fre = pow( clamp(1.0+dot(nor,rd),0.0,1.0), 2.0 );
float spe = pow(clamp( dot( ref, lig ), 0.0, 1.0 ),16.0);

dif *= softshadow( pos, lig, 0.02, 2.5 );
dom *= softshadow( pos, ref, 0.02, 2.5 );

vec3 lin = vec3(0.0);
lin += 1.30*dif*lights[i].color;
lin += 2.00*spe*lights[i].color*dif;
lin += 0.50*dom*vec3(0.40,0.60,1.00)*occ*lights[i].color;
lin += 0.50*bac*vec3(0.25,0.25,0.25)*occ*lights[i].color;
lin += 0.25*fre*vec3(1.00,1.00,1.00)*occ*lights[i].color;

c = c + col*lin;

//GI stuff
//vec3 light_color = lights[i].color;
vec3 light_color = vec3(0.0);
vec3 light_pos = pos;
vec3 prev_light_pos = pos;
vec3 gi_lig = reflect(normalize(lights[i].d),nor);
vec3 lnor = vec3(0.0);
int cur_id = id;
for (int l=0; l<GI_maxBounces; l++)
{
  L_RESULT res = castLightRay(light_pos, gi_lig, light_color, cur_id);

  if (cur_id == res.id) break;

  cur_id = res.id;

  lnor = calcNormal(light_pos);
  gi_lig = reflect(gi_lig, lnor);
  prev_light_pos = light_pos;
  light_pos = light_pos + gi_lig*res.t;
  //light_color = light_color + 0.1 * res.yzw;

  float gi_dif = clamp( dot( lnor, gi_lig ), 0.0, 1.0 );

  dif *= softshadow( light_pos, gi_lig, 0.02, 2.5 );

  //vec3 gi_lin = 1.30*gi_dif*lights[i].color*res.m;

  //light_color += gi_lin*distance(prev_light_pos, light_pos);
  //light_color += gi_lin;
  vec3 gi_ref = 1.30*gi_dif*res.m;
  vec3 BRDF = 2 * gi_ref * gi_dif;
  light_color += gi_dif + (BRDF * gi_ref);
}
if (lights[i].p.x > -10000.0) {
  c = c + light_color;
}
