shader_type canvas_item;
render_mode unshaded;

uniform vec2 bar_size = vec2(200.0, 24.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.686, 0.208, 0.286, 1.0);

float rounded_box(vec2 p, vec2 bounds, float radius) {
	vec2 q = abs(p - bounds * 0.5) - bounds * 0.5 + radius;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = UV * bar_size;
	float outer = rounded_box(p, bar_size, bar_size.y * 0.5);
	// Dark metal rim, inset track and a soft glossy upper surface.
	vec3 color = mix(vec3(0.36, 0.33, 0.25), vec3(0.12, 0.15, 0.15), UV.y);
	vec2 inset_size = max(bar_size - vec2(4.0), vec2(0.01));
	vec2 inset_p = p - vec2(2.0);
	float inner = rounded_box(inset_p, inset_size, inset_size.y * 0.5);
	float inner_alpha = 1.0 - smoothstep(-0.6, 0.6, inner);
	vec3 track = mix(vec3(0.035, 0.055, 0.061), vec3(0.075, 0.11, 0.12), UV.y);
	float width = inset_size.x * fill_ratio;
	float filled = rounded_box(inset_p, vec2(max(width, 0.001), inset_size.y), min(width, inset_size.y) * 0.5);
	float shade = mix(1.14, 0.83, smoothstep(0.12, 0.95, UV.y));
	float gloss = 0.10 * (1.0 - smoothstep(0.18, 0.5, UV.y));
	vec3 fill_color = tint.rgb * shade + vec3(gloss);
	float fill_alpha = (1.0 - smoothstep(-0.6, 0.6, filled)) * step(0.001, width);
	color = mix(color, mix(track, fill_color, fill_alpha), inner_alpha);
	COLOR = vec4(color, 1.0 - smoothstep(-0.8, 0.4, outer));
}
