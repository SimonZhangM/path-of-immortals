shader_type canvas_item;
render_mode unshaded;

uniform float top_fade_fraction = 0.0;
uniform vec2 panel_size = vec2(718.0);
uniform vec2 art_size = vec2(718.0);
uniform vec2 art_position = vec2(0.0);
uniform vec2 uv_origin = vec2(0.0);
uniform vec2 uv_size = vec2(1.0);
uniform float corner_radius = 18.0;

void fragment() {
	vec2 local_uv = (UV - uv_origin) / uv_size;
	vec2 point = local_uv * art_size + art_position;
	vec2 q = abs(point - panel_size * 0.5) - (panel_size * 0.5 - vec2(corner_radius));
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	// One screen pixel of coverage inside the boundary, even at fractional scale.
	float coverage = 1.0 - smoothstep(-max(fwidth(distance_to_edge), 0.001), 0.0, distance_to_edge);
	float fade = top_fade_fraction > 0.0 ? smoothstep(0.0, top_fade_fraction, local_uv.y) : 1.0;
	COLOR.a *= coverage * fade;
}
