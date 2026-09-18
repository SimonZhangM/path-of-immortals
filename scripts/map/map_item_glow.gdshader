shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(0.73, 0.80, 0.83, 0.16);
uniform float inner_radius = 0.0;
uniform float falloff_power = 2.0;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float fade = 1.0 - smoothstep(inner_radius, 1.0, radius);
	COLOR = vec4(glow_color.rgb, pow(fade, falloff_power) * glow_color.a);
}
