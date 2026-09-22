shader_type canvas_item;
uniform sampler2D repaired : source_color, filter_linear;
uniform sampler2D specialized : source_color, filter_linear;
uniform bool bench_specialized = false;
uniform bool bench_built = false;
uniform bool display_built = false;
uniform bool full_plate = false;
uniform float late_amount = 0.0;
uniform vec4 cabinet_hover = vec4(0.0);
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
		if (bench_specialized) pixel = mix(pixel, texture(specialized, UV), bench_mask);
	}
	float lamp_pool = exp(-dot((UV - vec2(0.84, 0.60)) / vec2(0.23, 0.25), (UV - vec2(0.84, 0.60)) / vec2(0.23, 0.25)));
	pixel.rgb *= mix(vec3(1.0), mix(vec3(0.66, 0.72, 0.79), vec3(1.0, 0.94, 0.83), lamp_pool), late_amount);
	// Light the existing wood grain; do not place a label or a flat button over it.
	vec2 inset = min(UV - cabinet_hover.xy, cabinet_hover.xy + cabinet_hover.zw - UV);
	float cabinet_light = smoothstep(0.0, 0.007, min(inset.x, inset.y));
	if (cabinet_hover.z > 0.0) pixel.rgb = pixel.rgb * (1.0 + 0.65 * cabinet_light) + vec3(0.055, 0.036, 0.012) * cabinet_light;
	COLOR = pixel * scene_tint;
}
