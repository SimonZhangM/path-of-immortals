shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float fade = smoothstep(0.0, 0.025, edge.x) * smoothstep(0.0, 0.16, edge.y);
	COLOR = vec4(0.0, 0.0, 0.0, 0.28 * fade);
}
