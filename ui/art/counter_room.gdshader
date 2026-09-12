shader_type canvas_item;

uniform int atmosphere = 0;
uniform int night_band = -1;
uniform bool lamp_dead = false;
uniform bool lamp_wrong = false;
uniform sampler2D lamp_off_texture : source_color, filter_linear;
uniform sampler2D incense_lit_texture : source_color, filter_linear;
uniform float incense_strength : hint_range(0.0, 1.0) = 1.0;

float soft_region(vec2 p, vec4 bounds, float feather) {
	vec2 edges = smoothstep(bounds.xy, bounds.xy + vec2(feather), p)
		* (vec2(1.0) - smoothstep(bounds.zw - vec2(feather), bounds.zw, p));
	return edges.x * edges.y;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// One painted room, fixed camera. Only local light and palette change.
	float lane = smoothstep(0.20, 0.30, UV.x) * (1.0 - smoothstep(0.66, 0.73, UV.x)) * (1.0 - smoothstep(0.43, 0.54, UV.y));
	vec3 color = source.rgb;
	if (atmosphere == 1) {
		color *= mix(vec3(0.79, 0.80, 0.78), vec3(0.41, 0.51, 0.55), lane);
	} else if (atmosphere == 2) {
		float grey = dot(color, vec3(0.299, 0.587, 0.114));
		color = mix(color, vec3(grey), 0.56) * vec3(0.69, 0.89, 0.96);
		color += lane * vec3(0.075, 0.13, 0.15);
		// The same door jamb takes a restrained ink-red cast, not a new room.
		float jamb = smoothstep(0.704, 0.72, UV.x) * (1.0 - smoothstep(0.75, 0.765, UV.x)) * (1.0 - smoothstep(0.36, 0.49, UV.y));
		color = mix(color, color * vec3(1.8, 0.55, 0.48), jamb * 0.55);
	}
	if (night_band >= 0) {
		// Relight the existing painting. The warm desk pool never reaches the street.
		float desk = exp(-dot((UV - vec2(0.655, 0.660)) / vec2(0.270, 0.235), (UV - vec2(0.655, 0.660)) / vec2(0.270, 0.235)) * 1.7);
		desk *= smoothstep(0.455, 0.545, UV.y);
		float fitting = exp(-dot((UV - vec2(0.767, 0.457)) / vec2(0.115, 0.145), (UV - vec2(0.767, 0.457)) / vec2(0.115, 0.145)) * 2.0);
		float glass = 1.0 - smoothstep(0.55, 1.0, length((UV - vec2(0.746, 0.421)) / vec2(0.017, 0.015)));
		if (night_band == 0) {
			// Replace baked emission across the complete fitting and nearby spill,
			// preserving ambient-lit metal/glass instead of painting over the bulb.
			float fixture = soft_region(UV, vec4(0.675, 0.24, 0.885, 0.645), 0.025);
			float spill = soft_region(UV, vec4(0.55, 0.445, 0.88, 0.74), 0.07);
			vec3 unlit = mix(source.rgb, texture(lamp_off_texture, UV).rgb, max(fixture, spill));
			color = pow(unlit, vec3(0.78)) * vec3(1.23, 1.20, 1.14);
		} else {
			vec3 room = vec3(0.22, 0.25, 0.29);
			vec3 street = vec3(0.18, 0.23, 0.30);
			float pool = 1.10;
			if (night_band == 2) { room = vec3(0.085, 0.115, 0.145); street = vec3(0.025, 0.043, 0.063); pool = 0.97; }
			if (night_band == 3) { room = vec3(0.043, 0.065, 0.085); street = vec3(0.009, 0.018, 0.028); pool = 0.80; }
			color = source.rgb * mix(room, street, lane);
			color += source.rgb * vec3(1.20, 0.96, 0.64) * (desk * pool + fitting * 0.70);
			color = mix(color, vec3(1.0, 0.82, 0.48), glass * 0.94);
		}
		// Registered painted embers and reflected light: only add the local
		// illumination difference, so darkness cannot hide the smouldering tips.
		float incense = soft_region(UV, vec4(0.005, 0.555, 0.19, 0.915), 0.025);
		vec3 warmth = max(texture(incense_lit_texture, UV).rgb - source.rgb, vec3(0.0));
		float strength = night_band == 0 ? 0.35 : (night_band == 1 ? 0.62 : 0.72);
		color += warmth * incense * strength * incense_strength;
	}
	float bulb = (1.0 - smoothstep(0.029, 0.052, length((UV - vec2(0.772, 0.399)) * vec2(1.0, 1.5))));
	if (lamp_dead) color *= 1.0 - bulb * 0.88;
	else if (lamp_wrong || atmosphere == 2) color = mix(color, vec3(dot(color, vec3(0.333))) * vec3(0.82, 1.02, 1.12), bulb);
	COLOR = vec4(color, source.a);
}
