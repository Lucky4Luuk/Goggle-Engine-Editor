uniform vec2 RES;

const float FXAA_SPAN_MAX = 8.0;
const float FXAA_REDUCE_MUL = 1.0/8.0;
const float FXAA_REDUCE_MIN = 1.0/128.0;

vec3 fxaa(vec2 uv, Image tex)
{
	vec2 offset = 1.0/RES.xy;

	vec3 nw = Texel(tex, uv + vec2(-1.0, -1.0) * offset).rgb;
	vec3 ne = Texel(tex, uv + vec2( 1.0, -1.0) * offset).rgb;
	vec3 sw = Texel(tex, uv + vec2(-1.0,  1.0) * offset).rgb;
	vec3 se = Texel(tex, uv + vec2( 1.0, -1.0) * offset).rgb;
	vec3 m  = Texel(tex, uv).rgb;

	vec3 luma = vec3(0.299, 0.587, 0.114);
	float lumaNW = dot(nw, luma);
	float lumaNE = dot(ne, luma);
	float lumaSW = dot(sw, luma);
	float lumaSE = dot(se, luma);
	float lumaM  = dot(m,  luma);

	float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
	float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
	vec2 dir = vec2(
			-((lumaNW + lumaNE) - (lumaSW + lumaSE)),
			((lumaNW + lumaSW) - (lumaNE + lumaSE)));

	float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);
	float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
	dir = min(vec2(FXAA_SPAN_MAX), max(vec2(-FXAA_SPAN_MAX), dir * rcpDirMin)) * offset;

	vec3 rgbA = 0.5 * (Texel(tex, uv + dir * (1.0 / 3.0 - 0.5)).xyz + Texel(tex, uv + dir * (2.0 / 3.0 - 0.5)).xyz);
	vec3 rgbB = rgbA * 0.5 + 0.25 * (Texel(tex, uv + dir * -0.5).xyz + Texel(tex, uv + dir * 0.5).xyz);
	float lumaB = dot(rgbB, luma);
	if (lumaB < lumaMin || lumaB > lumaMax) {
		return rgbA;
	}
	return rgbB;
}

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords)
{
	vec2 uv = screen_coords.xy / RES.xy;

	vec3 col = fxaa(uv, tex);

	return vec4(col,1.0);
}
