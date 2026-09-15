shader_type canvas_item;

#include "res://assets/bedroom/night_lighting.gdshaderinc"

uniform bool lamp_lit = true;
uniform float ripple : hint_range(0.0, 1.0) = 0.0;
uniform float fog : hint_range(0.0, 1.0) = 0.0;
uniform float wall_shadow : hint_range(0.0, 1.0) = 0.0;

// A motionless cast shadow on the existing opposite wall, without facial
// features or an extra reflected light source. It never extends beyond glass.
float corner_shadow(vec2 uv) {
	float head = 1.0 - smoothstep(0.65, 1.2, length((uv - vec2(0.79, 0.255)) / vec2(0.065, 0.10)));
	float shoulders = smoothstep(0.27, 0.37, uv.y);
	float width = mix(0.095, 0.059, smoothstep(0.43, 0.95, uv.y));
	float center = mix(0.785, 0.83, smoothstep(0.36, 0.94, uv.y));
	float body = (1.0 - smoothstep(width * 0.65, width * 1.3, abs(uv.x - center))) * shoulders;
	return max(head, body) * (1.0 - smoothstep(0.88, 1.0, uv.y));
}

void fragment() {
	vec2 uv = UV;
	uv.x += sin(UV.y * 18.0 + TIME * 1.7) * 0.012 * ripple;
	uv.y += sin(UV.x * 11.0 - TIME * 0.8) * 0.004 * ripple;
	vec4 paint = texture(TEXTURE, clamp(uv, vec2(0.005), vec2(0.995)));
	// Indirect lamplight only: the lamp itself is outside this mirror's view.
	float luminance = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
	vec3 silvered = mix(paint.rgb, vec3(luminance), 0.32);
	vec3 tint = mix(vec3(0.44, 0.49, 0.53), vec3(0.76, 0.70, 0.62), lamp_lit ? lamp_light : 0.0);
	vec3 color = silvered * tint;
	float mist = (0.48 + 0.12 * sin(UV.y * 7.0 + TIME * 0.15)) * fog;
	color = mix(color, vec3(0.33, 0.34, 0.32), mist);
	color *= 1.0 - corner_shadow(UV) * wall_shadow;
	color *= bedroom_exposure(vec2(1050.0, 93.0) + UV * vec2(178.0, 260.0));
	COLOR = vec4(color, paint.a);
}
