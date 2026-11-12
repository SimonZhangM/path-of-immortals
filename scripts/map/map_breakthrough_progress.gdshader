shader_type canvas_item;
render_mode unshaded;

uniform sampler2D filled_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 endpoints = vec2(0.03024, 0.96976);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	float edge = mix(endpoints.x, endpoints.y, progress);
	float revealed = progress <= 0.0 ? 0.0 : (progress >= 1.0 ? 1.0 : step(UV.x, edge));
	// Replace matching pixels rather than stacking two translucent frames/glows.
	COLOR = mix(texture(TEXTURE, UV), texture(filled_texture, UV), revealed) * vertex_tint;
}
