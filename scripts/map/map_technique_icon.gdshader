shader_type canvas_item;
render_mode unshaded;

uniform vec2 icon_size = vec2(64.0);
uniform float corner_radius = 3.0;
uniform float line_width = 1.0;
uniform vec4 line_color : source_color = vec4(0.851, 0.733, 0.447, 1.0);

void fragment() {
	vec2 q = abs(UV * icon_size - icon_size * 0.5) - (icon_size * 0.5 - vec2(corner_radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float pixel = max(fwidth(d), 0.001);
	float outer = 1.0 - smoothstep(-pixel, 0.0, d);
	float inner = 1.0 - smoothstep(-line_width - pixel, -line_width, d);
	COLOR = vec4(mix(line_color.rgb, COLOR.rgb, inner), mix(line_color.a, COLOR.a, inner) * outer);
}
