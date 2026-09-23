shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float ink = 1.0-smoothstep(.46,.91,dot(c.rgb,vec3(.299,.587,.114)));
	COLOR = vec4(.22,.14,.075,ink*c.a);
}
