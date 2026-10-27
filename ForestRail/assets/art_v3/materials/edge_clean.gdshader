shader_type canvas_item;
render_mode unshaded;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.r > 0.90 && c.g < 0.12 && c.b < 0.12) c.a = 0.0;
	if (c.r > 0.97 && c.g > 0.97 && c.b < 0.08) c.a = 0.0;
	COLOR = c * vertex_tint;
}
