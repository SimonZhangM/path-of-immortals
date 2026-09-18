shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float fade = 1.0 - smoothstep(0.0, 1.0, radius);
	COLOR = vec4(0.73, 0.80, 0.83, fade * fade * 0.16);
}
