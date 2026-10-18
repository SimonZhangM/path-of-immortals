shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Retain contrast on the left, then fade increasingly fast toward the right.
	float horizontal_fade = 1.0 - pow(clamp(UV.x, 0.0, 1.0), 2.2);
	float vertical_fade = smoothstep(0.0, 0.07, UV.y) * (1.0 - smoothstep(0.9, 1.0, UV.y));
	COLOR = vec4(0.015, 0.03, 0.045, 0.82 * horizontal_fade * vertical_fade);
}
