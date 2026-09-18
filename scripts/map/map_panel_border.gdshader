shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(718.0);
uniform float corner_radius = 18.0;
uniform float line_width = 1.2;
uniform vec4 line_color : source_color = vec4(0.851, 0.733, 0.447, 1.0);

void fragment() {
	// The quad has a2px apron so outer-edge coverage is never cut off.
	vec2 point = UV * (panel_size + vec2(4.0)) - vec2(2.0);
	vec2 q = abs(point - panel_size * 0.5) - (panel_size * 0.5 - vec2(corner_radius));
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	// Analytic pixel coverage for BOTH edges of the thin rounded stroke.
	// Derivatives keep the transition one screen pixel wide at any UI scale.
	float pixel_width = max(fwidth(distance_to_edge), 0.001);
	float outer_coverage = clamp(0.5 - distance_to_edge / pixel_width, 0.0, 1.0);
	float inner_coverage = clamp(0.5 - (distance_to_edge + line_width) / pixel_width, 0.0, 1.0);
	COLOR = vec4(line_color.rgb, line_color.a * (outer_coverage - inner_coverage));
}
