shader_type canvas_item;
render_mode unshaded;
uniform sampler2D source_tex : source_color, filter_linear, repeat_enable;
uniform vec4 source_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool repeat_y = true;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
vec4 sample_region(vec2 q) {
	vec2 half_pixel = 0.5 / vec2(textureSize(source_tex, 0));
	vec2 at = source_region.xy + q * source_region.zw;
	at = clamp(at, source_region.xy + half_pixel, source_region.xy + source_region.zw - half_pixel);
	vec4 c = texture(source_tex, at);
	if (c.r > 0.90 && c.g < 0.12 && c.b < 0.12) c.a = 0.0;
	if (c.r > 0.97 && c.g > 0.97 && c.b < 0.08) c.a = 0.0;
	return vec4(c.rgb * c.a, c.a);
}
void fragment() {
	vec2 p = vec2(fract(UV.x), repeat_y ? fract(UV.y) : clamp(UV.y, 0.0, 1.0));
	vec2 w = sin(p * PI); w *= w;
	if (!repeat_y) w.y = 1.0;
	vec4 a = sample_region(p);
	vec4 b = sample_region(vec2(fract(p.x + 0.5), p.y));
	vec4 c = sample_region(vec2(p.x, repeat_y ? fract(p.y + 0.5) : p.y));
	vec4 d = sample_region(vec2(fract(p.x + 0.5), repeat_y ? fract(p.y + 0.5) : p.y));
	vec4 result = a*w.x*w.y + b*(1.0-w.x)*w.y + c*w.x*(1.0-w.y) + d*(1.0-w.x)*(1.0-w.y);
	if (result.a > 0.00001) result.rgb /= result.a;
	COLOR = result * vertex_tint;
}
