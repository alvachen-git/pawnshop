shader_type canvas_item;

// Muted old recollection, limited to the painting. UI retains full contrast.
void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	float luminance = dot(painted.rgb, vec3(0.299, 0.587, 0.114));
	vec3 faded = mix(vec3(luminance) * vec3(1.01, 0.98, 0.91), painted.rgb, 0.28);
	faded = mix(vec3(0.085, 0.08, 0.07), faded, 0.82) * 0.82;
	float edge = smoothstep(0.30, 0.72, length(UV - vec2(0.5)));
	COLOR = vec4(faded * (1.0 - 0.12 * edge), painted.a);
}
