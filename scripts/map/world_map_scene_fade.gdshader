shader_type canvas_item;

// Fade only the outer tenth of each side; the middle stays fully opaque.
uniform float edge_fraction : hint_range(0.001, 0.5) = 0.1;

void fragment() {
	float edge_alpha = smoothstep(0.0, edge_fraction, UV.x)
		* smoothstep(0.0, edge_fraction, 1.0 - UV.x);
	COLOR.a *= edge_alpha;
}
