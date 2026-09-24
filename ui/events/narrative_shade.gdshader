shader_type canvas_item;

// Readability scrim over the painting, not a replacement for scene artwork.
void fragment() {
	COLOR = vec4(vec3(0.095, 0.092, 0.078), smoothstep(0.0, 0.30, UV.y) * 0.96);
}
