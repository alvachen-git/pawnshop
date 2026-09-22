// Art-space exposure shared by the room, fixed mirror frame and reflection.
// UI is drawn separately and keeps its original readable contrast.
uniform float lamp_light : hint_range(0.0, 1.0) = 1.0;
vec3 bedroom_exposure(vec2 p) {
	vec2 near_lamp = (p - vec2(233.0, 418.0)) / (vec2(270.0, 225.0) * mix(0.40, 1.0, lamp_light));
	float pool = exp(-dot(near_lamp, near_lamp) * 1.6);
	vec2 flame = (p - vec2(225.0, 374.0)) / vec2(45.0, 70.0);
	float wick = exp(-dot(flame, flame) * 1.8);
	float exposure = min(0.98, 0.27 + 0.09 * lamp_light + (pool * 0.55 + wick * 0.16) * lamp_light);
	vec3 tint = mix(vec3(0.89, 0.93, 0.98), vec3(1.0, 0.98, 0.94), pool);
	return tint * exposure;
}
