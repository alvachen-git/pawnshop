shader_type canvas_item;
uniform bool chroma_key = false;
uniform float exposure = 1.0;
uniform float saturation = 1.0;
uniform float highlight_reduction = 0.0;
uniform int contact_mode = 0;
uniform vec4 footprint = vec4(0.5, 0.9, 0.2, 0.04);
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
vec4 cutout(vec4 p) {
	if (chroma_key) {
		float spill = max(0.0, min(p.r, p.b) - p.g);
		p.a *= 1.0 - smoothstep(0.08, 0.40, spill);
		p.rb -= vec2(spill);
	}
	return p;
}
void fragment() {
	vec4 p = cutout(texture(TEXTURE, UV));
	float luminance = dot(p.rgb, vec3(0.299, 0.587, 0.114));
	p.rgb = mix(vec3(luminance), p.rgb, saturation);
	p.rgb *= exposure * (1.0 - highlight_reduction * smoothstep(0.40, 0.95, luminance));
	float shadow = 0.0;
	if (contact_mode == 1) {
		// Flat goods touch the felt along their silhouette. Light comes from
		// upper right; the short soft shadow falls left/down, never a halo.
		vec2 q = UV - vec2(-0.009, 0.020);
		shadow = (cutout(texture(TEXTURE, q)).a * 0.4 + cutout(texture(TEXTURE, q + vec2(.006, 0.0))).a * 0.15
			+ cutout(texture(TEXTURE, q - vec2(.006, 0.0))).a * 0.15 + cutout(texture(TEXTURE, q + vec2(0.0, .009))).a * 0.15
			+ cutout(texture(TEXTURE, q - vec2(0.0, .009))).a * 0.15) * 0.44;
	} else if (contact_mode == 2) {
		// Standing vessels contact only at the base, not around the rim.
		vec2 q = (UV - footprint.xy) / footprint.zw;
		shadow = (1.0 - smoothstep(.18, 1.25, length(q))) * 0.58;
	}
	float a = p.a + shadow * (1.0 - p.a);
	vec3 rgb = (p.rgb * p.a + vec3(.075, .056, .037) * shadow * (1.0 - p.a)) / max(a, .0001);
	COLOR = vec4(rgb, a) * item_tint;
}
