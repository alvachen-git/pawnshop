shader_type canvas_item;
uniform sampler2D repaired : source_color, filter_linear;
uniform bool bench_built = false;
uniform bool display_built = false;
uniform bool full_plate = false;
uniform float late_amount = 0.0;
varying vec4 scene_tint;
void vertex() { scene_tint = COLOR; }
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (!full_plate) {
		// Two registered scene plates, selected locally. Buying one facility never repairs the other.
		float display_mask = (1.0 - smoothstep(0.252, 0.262, UV.x)) * smoothstep(0.382, 0.407, UV.y);
		float bench_mask = smoothstep(0.690, 0.710, UV.x) * smoothstep(0.342, 0.378, UV.y);
		float coverage = max(display_built ? display_mask : 0.0, bench_built ? bench_mask : 0.0);
		pixel = mix(pixel, texture(repaired, UV), coverage);
	}
	float lamp_pool = exp(-dot((UV - vec2(0.84, 0.60)) / vec2(0.23, 0.25), (UV - vec2(0.84, 0.60)) / vec2(0.23, 0.25)));
	pixel.rgb *= mix(vec3(1.0), mix(vec3(0.66, 0.72, 0.79), vec3(1.0, 0.94, 0.83), lamp_pool), late_amount);
	COLOR = pixel * scene_tint;
}
