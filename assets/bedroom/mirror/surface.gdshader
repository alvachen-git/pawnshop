shader_type canvas_item;

#include "res://assets/bedroom/night_lighting.gdshaderinc"

uniform bool lamp_lit = true;
uniform float ripple : hint_range(0.0, 1.0) = 0.0;
uniform float fog : hint_range(0.0, 1.0) = 0.0;

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
	color *= bedroom_exposure(vec2(1050.0, 93.0) + UV * vec2(178.0, 260.0));
	COLOR = vec4(color, paint.a);
}
