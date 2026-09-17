shader_type canvas_item;

uniform int night_band = 0;
uniform int atmosphere = 0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Matte painted skin in the unlit left corner, away from the right-hand lamp.
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 paint = pow(mix(source.rgb, vec3(luminance), 0.20), vec3(1.08));
	vec3 exposure = vec3(0.78, 0.75, 0.70);
	if (night_band == 1) exposure = vec3(0.43, 0.44, 0.44);
	else if (night_band >= 2) exposure = vec3(0.29, 0.32, 0.34);
	else if (night_band < 0 && atmosphere > 0) exposure = vec3(0.37, 0.42, 0.44);
	// A little light reaches the right cheek; the collar sits in the counter's shade.
	float facing_lamp = smoothstep(0.40, 0.82, UV.x);
	float collar_shade = 1.0 - 0.20 * smoothstep(0.67, 0.93, UV.y);
	paint *= exposure * mix(0.78, 1.0, facing_lamp) * collar_shade;
	COLOR = vec4(paint, source.a);
}
