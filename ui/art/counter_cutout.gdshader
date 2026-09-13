shader_type canvas_item;
uniform bool chroma_key = false;
uniform bool clean_chroma_edges = false;
uniform bool hand_contact_shadow = false;
varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }
vec4 cutout(vec4 pixel) {
	if (chroma_key) {
		// RGB source art can use pure magenta. Keep the original asset intact.
		float magenta = min(pixel.r, pixel.b) - pixel.g;
		float alpha = 1.0 - smoothstep(clean_chroma_edges ? 0.06 : 0.12, 0.40, magenta);
		pixel.a *= alpha;
		if (alpha < 1.0) {
			pixel.r = min(pixel.r, pixel.g + 0.12);
			pixel.b = min(pixel.b, pixel.g + 0.12);
		}
		if (clean_chroma_edges) {
			// Remove backing spill from fine hair without recoloring neutral cloth or skin.
			float spill = max(0.0, min(pixel.r, pixel.b) - pixel.g);
			pixel.rb -= vec2(spill);
		}
	}
	return pixel;
}
void fragment() {
	vec4 pixel = cutout(texture(TEXTURE, UV));
	if (hand_contact_shadow) {
		// Only the forward hands touch the table; derive their small shadow from the sprite.
		float shadow = cutout(texture(TEXTURE, UV - vec2(0.003, 0.006))).a * smoothstep(0.87, 0.90, UV.y) * 0.24;
		float combined_alpha = pixel.a + shadow * (1.0 - pixel.a);
		pixel.rgb = (pixel.rgb * pixel.a + vec3(0.08, 0.06, 0.04) * shadow * (1.0 - pixel.a)) / max(combined_alpha, 0.0001);
		pixel.a = combined_alpha;
	}
	COLOR = pixel * sprite_tint;
}
