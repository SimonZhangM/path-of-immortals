shader_type canvas_item;
uniform float blur_radius = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 sample_color = texture(TEXTURE, UV) * 0.25;
	sample_color += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)) * 0.125;
	sample_color += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)) * 0.125;
	sample_color += texture(TEXTURE, UV + vec2(0.0, step_uv.y)) * 0.125;
	sample_color += texture(TEXTURE, UV - vec2(0.0, step_uv.y)) * 0.125;
	sample_color += texture(TEXTURE, UV + step_uv) * 0.0625;
	sample_color += texture(TEXTURE, UV - step_uv) * 0.0625;
	sample_color += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)) * 0.0625;
	sample_color += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)) * 0.0625;
	COLOR = vertex_tint * sample_color;
}
