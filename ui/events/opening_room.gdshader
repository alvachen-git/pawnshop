shader_type canvas_item;

#include "res://assets/bedroom/night_lighting.gdshaderinc"

uniform sampler2D rest_texture : source_color, filter_linear;
uniform bool photo_placed = false;

float region(vec2 p, vec4 bounds) {
	vec2 inside = smoothstep(bounds.xy, bounds.xy + vec2(2.0), p)
		* (vec2(1.0) - smoothstep(bounds.zw - vec2(2.0), bounds.zw, p));
	return inside.x * inside.y;
}

void fragment() {
	vec2 p = UV * vec2(1672.0, 941.0);
	vec2 mask = smoothstep(vec2(265.0, 365.0), vec2(269.0, 369.0), p)
		* (vec2(1.0) - smoothstep(vec2(329.0, 442.0), vec2(333.0, 446.0), p));
	vec4 painted = mix(texture(TEXTURE, UV), texture(rest_texture, UV), photo_placed ? 0.0 : mask.x * mask.y);
	float edge = mix(201.0, 176.0, smoothstep(65.0, 95.0, p.y));
	float panes = region(p, vec4(174.0, 65.0, 259.0, 187.0)) * smoothstep(edge, edge + 2.0, p.x);
	panes = max(panes, region(p, vec4(276.0, 65.0, 367.0, 187.0)));
	panes = max(panes, region(p, vec4(382.0, 65.0, 471.0, 187.0)));
	panes = max(panes, region(p, vec4(175.0, 198.0, 260.0, 335.0)));
	panes = max(panes, region(p, vec4(276.0, 198.0, 367.0, 335.0)));
	panes = max(panes, region(p, vec4(382.0, 198.0, 471.0, 335.0)));
	panes *= 1.0 - region(p, vec4(207.0, 312.0, 237.0, 347.0));
	painted.rgb *= bedroom_exposure(p);
	painted.rgb *= mix(vec3(1.0), vec3(0.055, 0.065, 0.080), panes);
	COLOR = painted;
}
