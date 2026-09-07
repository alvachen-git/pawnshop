shader_type canvas_item;
uniform bool chroma_key = false;
varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (chroma_key) {
		// RGB source art can use pure magenta. Keep the original asset intact.
		float magenta = min(pixel.r, pixel.b) - pixel.g;
		float alpha = 1.0 - smoothstep(0.12, 0.40, magenta);
		pixel.a *= alpha;
		if (alpha < 1.0) {
			pixel.r = min(pixel.r, pixel.g + 0.12);
			pixel.b = min(pixel.b, pixel.g + 0.12);
		}
	}
	COLOR = pixel * sprite_tint;
}
