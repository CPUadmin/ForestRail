shader_type canvas_item;
render_mode unshaded;
uniform float presence : hint_range(0.0,1.0) = 1.0;
void fragment() {
	vec4 c=texture(TEXTURE,UV);
	float edge=smoothstep(0.0,0.12,UV.x)*smoothstep(0.0,0.12,1.0-UV.x);
	c.a*=edge*smoothstep(0.0,0.12,UV.y)*presence;
	COLOR=c;
}
