shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(104.0, 69.4);
uniform float corner_radius = 3.0;
uniform float image_opacity = 0.75;
uniform float fade_start = 0.5;
uniform float left_fade_fraction = 0.05;
uniform float vertical_fade_fraction = 0.05;

void fragment() {
	vec2 q = abs(UV * panel_size - panel_size * 0.5) - (panel_size * 0.5 - vec2(corner_radius));
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float coverage = 1.0 - smoothstep(-max(fwidth(edge), 0.001), 0.0, edge);
	float fade_left = smoothstep(0.0, left_fade_fraction, UV.x);
	// Fade out quickly from the image center, then ease gently into the transparent right edge.
	float right_progress = clamp((UV.x - fade_start) / max(1.0 - fade_start, 0.001), 0.0, 1.0);
	float fade_right = (1.0 - right_progress) * (1.0 - right_progress);
	float fade_top = smoothstep(0.0, vertical_fade_fraction, UV.y);
	float fade_bottom = 1.0 - smoothstep(1.0 - vertical_fade_fraction, 1.0, UV.y);
	COLOR.a *= image_opacity * fade_left * fade_right * fade_top * fade_bottom * coverage;
}
