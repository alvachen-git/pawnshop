shader_type canvas_item;
render_mode unshaded;

uniform sampler2D smoke_texture : filter_linear;
uniform float drift : hint_range(0.0, 1.0) = 0.0;
uniform float preview_time = -1.0;
uniform float opacity = 0.62;

float wisp(vec2 p, vec2 tip, float seed, float t) {
	float height = mix(154.0, 68.0, drift);
	float age = (tip.y - p.y) / height;
	if (age <= 0.0 || age >= 1.0) return 0.0;
	// The inlet remains pinned to the incense. Slow disturbances grow upstream.
	float curl = (sin(age * 9.0 - t * 0.43 + seed) * 6.0
		+ sin(age * 17.0 - t * 0.29 + seed * 2.0) * 2.5) * pow(age, 1.25);
	float bend = drift * 115.0 * age * age;
	float width = mix(22.0, 64.0, age);
	float u = 0.5 + (p.x - tip.x - curl - bend) / width;
	if (u <= 0.0 || u >= 1.0) return 0.0;
	float v = 0.925 - age * 0.875 + sin(age * 15.0 - t * 0.55 + seed) * age * 0.025;
	// Lift the translucent filaments without filling the transparent gaps.
	float density = pow(texture(smoke_texture, vec2(u, v)).a, 0.85);
	float breath = 0.74 + 0.17 * sin(age * 18.0 - t * 0.72 + seed)
		+ 0.09 * sin(age * 31.0 - t * 0.44 + seed);
	return density * breath * smoothstep(0.0, 0.01, age)
		* (1.0 - smoothstep(0.48, 1.0, age));
}

void fragment() {
	// Matches the background painting's coordinates, including its hidden foot.
	vec2 p = UV * vec2(1672.0, 941.0);
	float alpha = 0.0;
	if (p.x > 85.0 && p.x < 310.0 && p.y > 385.0 && p.y < 562.0) {
		float t = preview_time >= 0.0 ? preview_time : TIME;
		alpha = wisp(p, vec2(121.0, 559.0), 0.4, t) * 0.7
			+ wisp(p, vec2(140.0, 550.0), 2.2, t)
			+ wisp(p, vec2(158.0, 560.0), 4.1, t) * 0.65;
	}
	COLOR = vec4(vec3(0.80, 0.82, 0.80), min(alpha * opacity, 0.55));
}
