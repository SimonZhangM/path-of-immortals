shader_type canvas_item;
render_mode unshaded;

uniform sampler2D glyph_distance : filter_linear, repeat_disable;
uniform float ink_density : hint_range(0.0, 1.0) = 0.45;
// Radius as a fraction of source height, independent of the display resolution.
uniform float feather_width : hint_range(0.001, 0.15) = 0.045;

void fragment() {
	float stroke = smoothstep(0.28, 0.6, min(COLOR.r, COLOR.g));
	float seal = smoothstep(0.12, 0.4, COLOR.r - max(COLOR.g, COLOR.b)) * smoothstep(0.25, 0.6, COLOR.r);
	float foreground = max(stroke, seal);
	float distance = texture(glyph_distance, UV).r;
	float ink = ink_density * (1.0 - smoothstep(0.0, feather_width, distance));
	// Change opacity only: no blur, recoloring or resampling of the visible strokes.
	COLOR.a *= mix(ink, 1.0, foreground);
}
