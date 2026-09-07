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
	vec3 color = vec3(0.085, 0.108, 0.106);
	float width = bar_size.x * fill_ratio;
	float filled = rounded_box(p, vec2(width, bar_size.y), min(width, bar_size.y) * 0.5);
	float shade = 0.95 + 0.10 * (1.0 - UV.y) - 0.08 * smoothstep(0.2, 0.9, fract((p.x + p.y * 1.8) / 66.0));
	vec3 fill_color = tint.rgb * shade + vec3(0.03 * (1.0 - UV.y));
	float fill_alpha = (1.0 - smoothstep(-0.8, 0.4, filled)) * step(0.001, width);
	color = mix(color, fill_color, fill_alpha);
	color = mix(color, vec3(0.26, 0.23, 0.18), smoothstep(-1.5, -0.5, outer) * 0.45);
	COLOR = vec4(color, 1.0 - smoothstep(-0.8, 0.4, outer));
}
