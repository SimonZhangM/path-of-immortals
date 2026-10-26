shader_type canvas_item;
render_mode unshaded;

uniform float fade_start = 0.5;
uniform float fade_end = 1.0;
uniform float right_opacity : hint_range(0.0, 1.0) = 0.25;
// AtlasTexture UVs still refer to the complete source image.
uniform vec2 source_x = vec2(0.0, 1.0);

void fragment() {
	float local_x = (UV.x - source_x.x) / (source_x.y - source_x.x);
	COLOR.a *= mix(1.0, right_opacity, smoothstep(fade_start, fade_end, local_x));
}
