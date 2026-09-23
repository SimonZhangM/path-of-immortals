shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(132.0, 197.0);
uniform vec4 source_region = vec4(0.09375, 0.0625, 0.8125, 0.875);
uniform float corner_radius = 10.0;
uniform float line_width = 2.0;
uniform vec4 line_color : source_color = vec4(0.647, 0.647, 0.647, 1.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 point = UV * panel_size;
	float radius = min(corner_radius, min(panel_size.x, panel_size.y) * 0.5);
	vec2 q = abs(point - panel_size * 0.5) - (panel_size * 0.5 - vec2(radius));
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float pixel_width = max(fwidth(distance_to_edge), 0.001);
	float outer_coverage = clamp(0.5 - distance_to_edge / pixel_width, 0.0, 1.0);
	float inner_coverage = clamp(0.5 - (distance_to_edge + line_width) / pixel_width, 0.0, 1.0);
	vec4 backing = texture(TEXTURE, source_region.xy + UV * source_region.zw);
	// Sample only authored interior artwork. A single analytic rounded mask
	// clips its corners and draws the independent inward 2px rarity stroke.
	COLOR = mix(line_color, backing, inner_coverage) * vertex_tint;
	COLOR.a *= outer_coverage;
}
