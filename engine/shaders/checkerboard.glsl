vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords)
{
  vec4 pixel = Texel(tex, tex_coords);
  vec2 fragCoord = vec2(screen_coords.x, love_ScreenSize.y - screen_coords.y);
  float offset = mod(fragCoord.y, 2.0);
  if (mod(fragCoord.x + offset, 2.0) > 0.5)
  {
    vec4 pixel1 = Texel(tex, (tex_coords - vec2(1.0, 0.0)) / love_ScreenSize.xy);
    vec4 pixel2 = Texel(tex, (tex_coords + vec2(1.0, 0.0)) / love_ScreenSize.xy);
    vec4 pixel3 = Texel(tex, (tex_coords - vec2(0.0, 1.0)) / love_ScreenSize.xy);
    vec4 pixel4 = Texel(tex, (tex_coords + vec2(0.0, 1.0)) / love_ScreenSize.xy);
    return (pixel1 + pixel2 + pixel3 + pixel4) / 4.0;
  }
  return pixel * color;
}
