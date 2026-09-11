shader_type canvas_item;

uniform sampler2D rest_texture : source_color, filter_linear;
uniform sampler2D shell_texture : source_color, filter_linear;
uniform bool photo_placed = false;
uniform bool lamp_dead = false;
uniform bool haunting = false;

// State changes sample only the affected prop from the matched second painting.
float region(vec2 p, vec4 bounds, float feather) {
	vec2 inside = smoothstep(bounds.xy, bounds.xy + vec2(feather), p)
		* (vec2(1.0) - smoothstep(bounds.zw - vec2(feather), bounds.zw, p));
	return inside.x * inside.y;
}

void fragment() {
	vec2 p = UV * vec2(1672.0, 941.0);
	vec4 normal = texture(TEXTURE, UV);
	float removed_mirror = region(p, vec4(1027.0, 67.0, 1252.0, 380.0), 3.0);
	normal = mix(normal, texture(shell_texture, UV), removed_mirror);
	vec4 rest = texture(rest_texture, UV);
	float photo = region(p, vec4(265.0, 365.0, 333.0, 446.0), 4.0);
	float lamp = region(p, vec4(174.0, 302.0, 262.0, 461.0), 12.0);
	float patch = max(photo_placed ? 0.0 : photo, lamp_dead ? lamp : 0.0);
	vec4 painted = mix(normal, rest, patch);
	if (haunting && !lamp_dead) {
		float flame = region(p, vec4(205.0, 345.0, 248.0, 401.0), 12.0);
		painted.rgb = mix(painted.rgb, painted.rgb * vec3(0.74, 0.91, 1.12), flame * 0.6);
	}
	COLOR = painted;
}
