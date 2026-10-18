shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(1203.5, 425.0);
uniform float corner_radius = 13.0;
uniform float line_width = 2.0;
uniform vec4 line_color : source_color = vec4(0.851, 0.733, 0.447, 1.0);
uniform vec2 title_gap = vec2(20.0, 252.0);

void fragment() {
	// Same rounded-rectangle distance/coverage as map_panel_border, restricted
	// to its top strip. The two quarter circles join the existing side rims.
	vec2 point = UV * vec2(panel_size.x + 4.0, corner_radius + 4.0) - vec2(2.0);
	vec2 q = abs(point - panel_size * 0.5) - (panel_size * 0.5 - vec2(corner_radius));
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float pixel_width = max(fwidth(distance_to_edge), 0.001);
	float outer_coverage = clamp(0.5 - distance_to_edge / pixel_width, 0.0, 1.0);
	float inner_coverage = clamp(0.5 - (distance_to_edge + line_width) / pixel_width, 0.0, 1.0);
	float coverage = outer_coverage - inner_coverage;
	if (point.y > corner_radius || (point.x >= title_gap.x && point.x <= title_gap.y)) {
		coverage = 0.0;
	}
	COLOR = vec4(line_color.rgb, line_color.a * coverage);
}
