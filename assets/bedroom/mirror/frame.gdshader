shader_type canvas_item;

#include "res://assets/bedroom/night_lighting.gdshaderinc"

void fragment() {
	vec2 p = UV * vec2(217.0, 305.0);
	if (p.x > 19.0 && p.x < 197.0 && p.y > 22.0 && p.y < 282.0) discard;
	COLOR = texture(TEXTURE, (p + vec2(1031.0, 71.0)) / vec2(1672.0, 941.0));
	COLOR.rgb *= bedroom_exposure(p + vec2(1031.0, 71.0));
}
