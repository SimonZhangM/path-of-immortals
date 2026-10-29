shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(946.0, 910.0);
uniform vec2 art_size = vec2(946.0, 315.0);
uniform float corner_radius = 18.0;
uniform float edge_fade_fraction = 0.05;
uniform float midpoint_opacity = 0.1;
uniform float fade_end = 0.5;
uniform float fade_start = 0.75;

void fragment() {
	vec2 point = UV * art_size;
	vec2 q = abs(point - panel_size * 0.5) - (panel_size * 0.5 - vec2(corner_radius));
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float coverage = 1.0 - smoothstep(-max(fwidth(edge), 0.001), 0.0, edge);
	// Two linear segments: 100% at x=75%, 10% at center, transparent at the left edge.
	float remaining = clamp((UV.x - fade_end) / (fade_start - fade_end), 0.0, 1.0);
	float horizontal = UV.x < fade_end
		? midpoint_opacity * clamp(UV.x / fade_end, 0.0, 1.0)
		: mix(midpoint_opacity, 1.0, remaining);
	float top = smoothstep(0.0, edge_fade_fraction, UV.y);
	float bottom = 1.0 - smoothstep(1.0 - edge_fade_fraction, 1.0, UV.y);
	// All three edge bands use 5% of the image height, giving equal physical widths.
	float right_fade_fraction = edge_fade_fraction * art_size.y / max(art_size.x, 0.001);
	float right = 1.0 - smoothstep(1.0 - right_fade_fraction, 1.0, UV.x);
	COLOR.a *= horizontal * top * bottom * right * coverage;
}
