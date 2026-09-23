shader_type canvas_item;
uniform float light_x = 0.0;
uniform float warmth = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE,UV);
	vec2 cell_uv = fract(UV*vec2(3.0,2.0));
	float magenta = smoothstep(.1,.4,min(c.r,c.b)-c.g);
	float silhouette = 1.0-smoothstep(.388,.400,length(cell_uv-vec2(.5)));
	float illumination = clamp(1.0+light_x*(cell_uv.x-.5),.65,1.18);
	c.rgb *= vec3(1.0+warmth,1.0,1.0-warmth)*illumination;
	COLOR = vec4(c.rgb,c.a*silhouette*(1.0-magenta));
}
