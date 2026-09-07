shader_type canvas_item;

uniform int atmosphere = 0;
uniform bool lamp_dead = false;
uniform bool lamp_wrong = false;

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
	float bulb = (1.0 - smoothstep(0.029, 0.052, length((UV - vec2(0.772, 0.399)) * vec2(1.0, 1.5))));
	if (lamp_dead) color *= 1.0 - bulb * 0.88;
	else if (lamp_wrong || atmosphere == 2) color = mix(color, vec3(dot(color, vec3(0.333))) * vec3(0.82, 1.02, 1.12), bulb);
	COLOR = vec4(color, source.a);
}
