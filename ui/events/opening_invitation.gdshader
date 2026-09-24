shader_type canvas_item;

// Atlas UVs refer to the full source. Isolate the generated paper silhouette,
// retaining a narrow soft contact-shadow margin, never the surrounding lap.
float edge_distance(vec2 p, vec2 a, vec2 b) {
	vec2 e = b - a;
	return (e.x * (p.y - a.y) - e.y * (p.x - a.x)) / length(e);
}

void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	vec2 p = UV * vec2(1672.0, 941.0);
	float d = edge_distance(p, vec2(735.0, 550.0), vec2(958.0, 579.0));
	d = min(d, edge_distance(p, vec2(958.0, 579.0), vec2(934.0, 822.0)));
	d = min(d, edge_distance(p, vec2(934.0, 822.0), vec2(655.0, 775.0)));
	d = min(d, edge_distance(p, vec2(655.0, 775.0), vec2(735.0, 550.0)));
	COLOR = vec4(painted.rgb, painted.a * smoothstep(-8.0, -1.0, d));
}
