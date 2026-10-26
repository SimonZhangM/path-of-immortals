shader_type canvas_item;
render_mode unshaded;

uniform float opacity : hint_range(0.0, 1.0) = 0.82;
uniform float fade_start = 0.08;
uniform float fade_end = 0.63;

void fragment() {
	float fade = 1.0 - smoothstep(fade_start, fade_end, UV.x);
	COLOR = vec4(0.0, 0.0, 0.0, opacity * fade);
}
