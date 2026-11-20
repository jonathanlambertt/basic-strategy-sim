shader_type canvas_item;
// Pixel-quantised felt: a soft table light rendered in three dithered bands.

uniform vec4 felt_dark : source_color = vec4(0.106, 0.255, 0.192, 1.0);
uniform vec4 felt_mid : source_color = vec4(0.165, 0.384, 0.286, 1.0);
uniform vec4 felt_light : source_color = vec4(0.224, 0.471, 0.353, 1.0);
uniform vec2 size = vec2(640.0, 360.0);
uniform vec2 light_center = vec2(0.62, 0.47);

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * size);
	vec2 q = (p / size - light_center) * vec2(size.x / size.y, 1.0);
	float l = clamp(1.2 - length(q) * 1.15, 0.0, 1.0);
	l += 0.05 * sin((p.x + p.y) * 0.03 + TIME * 0.35);
	l = clamp(l, 0.0, 0.999);
	float t = bayer4(p);
	float v = l * 2.0;
	vec3 col;
	if (v < 1.0) {
		col = v > t ? felt_mid.rgb : felt_dark.rgb;
	} else {
		col = v - 1.0 > t ? felt_light.rgb : felt_mid.rgb;
	}
	// sparse fibres
	if (hash(p) > 0.985) {
		col *= 0.9;
	}
	COLOR = vec4(col, 1.0);
}
