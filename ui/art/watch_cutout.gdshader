shader_type canvas_item;
uniform bool engraving = false;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float warm = max(c.r, c.g);
	float navy = smoothstep(0.025, 0.11, warm - c.b * 0.77);
	float light = smoothstep(0.10, 0.28, warm);
	c.a *= max(navy, light);
	if (engraving) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = mix(vec3(0.13,0.09,0.055),vec3(0.49,0.36,0.20),l);
		c.a *= .88;
	}
	COLOR = c * tint;
}
