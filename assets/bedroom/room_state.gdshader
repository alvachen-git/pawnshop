shader_type canvas_item;

#include "res://assets/bedroom/night_lighting.gdshaderinc"

uniform sampler2D rest_texture : source_color, filter_linear;
uniform sampler2D shell_texture : source_color, filter_linear;
uniform bool photo_placed = false;
uniform bool lamp_dead = false;
uniform bool haunting = false;
uniform int lamp_grade = 0;
uniform int personal_damage = -1;

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
	float patch = max(photo_placed ? 0.0 : photo, (lamp_dead || personal_damage > 0) ? lamp : 0.0);
	vec4 painted = mix(normal, rest, patch);
	if (haunting && !lamp_dead && personal_damage < 0) {
		float flame = region(p, vec4(205.0, 345.0, 248.0, 401.0), 12.0);
		painted.rgb = mix(painted.rgb, painted.rgb * vec3(0.74, 0.91, 1.12), flame * 0.6);
	}
	if (lamp_grade > 0 && !lamp_dead && personal_damage < 0) {
		float flame = region(p, vec4(205.0, 345.0, 248.0, 401.0), 12.0);
		vec3 tint = lamp_grade >= 4 ? vec3(0.5, 0.48, 0.51) : (lamp_grade == 2 ? vec3(0.6, 0.52, 0.46) : vec3(0.42, 0.85, 1.3));
		painted.rgb = mix(painted.rgb, painted.rgb * tint, flame * 0.9);
	}

	if (personal_damage > 0 && personal_damage < 4 && !lamp_dead) {
		// The extinguished painting supplies the same glass and lamp body. Only
		// the small flame is rebuilt, with a continuous, subpixel sway.
		float d = float(personal_damage);
		float sway = sin(TIME * 2.1) * 0.65 + sin(TIME * 3.7) * 0.25;
		float height = d < 1.5 ? 13.0 : (d < 2.5 ? 9.0 : 5.0);
		vec2 f = p - vec2(225.0, 384.0 - height * 0.35);
		f.x += f.y * (0.12 + d * 0.02) + sway;
		float flame = exp(-dot(f / vec2(4.8 - d * 0.8, height), f / vec2(4.8 - d * 0.8, height)) * 1.8);
		vec3 tint = d < 1.5 ? vec3(1.0, 0.63, 0.22) : vec3(0.34, 0.77, 0.69);
		painted.rgb += tint * flame * (d < 2.5 ? 0.95 : 0.62);
	}
	if (personal_damage == 0) {
		float local_flame = region(p, vec4(216.0, 365.0, 238.0, 392.0), 7.0);
		painted.rgb *= 1.0 + local_flame * sin(TIME * 2.2) * 0.018;
	}
	// Mask the six glass panes, keeping the wooden mullions and lamp chimney.
	float top_left_edge = mix(201.0, 176.0, smoothstep(65.0, 95.0, p.y));
	float upper_left = region(p, vec4(174.0, 65.0, 259.0, 187.0), 2.0)
		* smoothstep(top_left_edge, top_left_edge + 2.0, p.x);
	float panes = max(upper_left, region(p, vec4(276.0, 65.0, 367.0, 187.0), 2.0));
	panes = max(panes, region(p, vec4(382.0, 65.0, 471.0, 187.0), 2.0));
	panes = max(panes, region(p, vec4(175.0, 198.0, 260.0, 335.0), 2.0));
	panes = max(panes, region(p, vec4(276.0, 198.0, 367.0, 335.0), 2.0));
	panes = max(panes, region(p, vec4(382.0, 198.0, 471.0, 335.0), 2.0));
	float chimney = region(p, vec4(207.0, 312.0, 237.0, 347.0), 3.0);
	panes *= 1.0 - chimney;
	painted.rgb *= bedroom_exposure(p);
	painted.rgb *= mix(vec3(1.0), vec3(0.055, 0.065, 0.080), panes);
	COLOR = painted;
}
