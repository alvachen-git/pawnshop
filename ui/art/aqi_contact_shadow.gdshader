shader_type canvas_item;
// A small shadow uses the actual lower sleeve/hand silhouette, not a body crop.
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    float key = min(pixel.r, pixel.b) - pixel.g;
    float alpha = pixel.a * (1.0 - smoothstep(0.12, 0.40, key));
    alpha *= smoothstep(0.78, 0.90, UV.y);
    COLOR = vec4(0.035, 0.024, 0.012, alpha * 0.42);
}
