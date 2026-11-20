shader_type canvas_item;
// Light CRT pass over the whole screen: scanlines per game pixel row,
// a 1px colour fringe and a vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float scanline_strength = 0.16;
uniform float vignette_strength = 0.3;
uniform float aberration_px = 1.0;
uniform float base_height = 360.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = vec2(SCREEN_PIXEL_SIZE.x * aberration_px, 0.0);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	float line = 0.5 + 0.5 * sin(uv.y * base_height * 6.2831853);
	col *= 1.0 - scanline_strength * (1.0 - line);
	vec2 c = uv - 0.5;
	col *= clamp(1.0 - dot(c, c) * vignette_strength * 2.0, 0.0, 1.0);
	col *= 1.06;
	COLOR = vec4(col, 1.0);
}
