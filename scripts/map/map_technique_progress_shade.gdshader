shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Match the overview shade, fading faster farther below the divider.
	float vertical_fade = 1.0 - pow(clamp(UV.y, 0.0, 1.0), 2.2);
	float side_fade = smoothstep(0.0, 0.005, UV.x) * (1.0 - smoothstep(0.995, 1.0, UV.x));
	COLOR = vec4(0.015, 0.03, 0.045, 0.82 * vertical_fade * side_fade);
}
