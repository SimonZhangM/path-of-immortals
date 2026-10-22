shader_type canvas_item;
uniform sampler2D spell_art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 viewport_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 art_rect = vec4(0.1, 0.1, 0.8, 0.8);
uniform vec4 clip_rect = vec4(0.1, 0.1, 0.8, 0.8);
uniform float corner_radius_px = 0.0;
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

void fragment() {
	vec2 source_uv = viewport_rect.xy + UV * viewport_rect.zw;
	vec4 frame = texture(TEXTURE, source_uv);
	if (any(lessThan(source_uv, vec2(0.0))) || any(greaterThan(source_uv, vec2(1.0)))) frame = vec4(0.0);
	vec4 art = vec4(0.0);
	if (all(greaterThanEqual(source_uv, clip_rect.xy)) && all(lessThanEqual(source_uv, clip_rect.xy + clip_rect.zw))) {
		art = texture(spell_art, (source_uv - art_rect.xy) / art_rect.zw);
	}
	float alpha = frame.a + art.a * (1.0 - frame.a);
	vec3 rgb = (frame.rgb * frame.a + art.rgb * art.a * (1.0 - frame.a)) / max(alpha, 0.00001);
	// Screen-space radius stays 3 px on both inventory and battle boards.
	vec2 pixel_dimensions = 1.0 / max(fwidth(UV), vec2(0.000001));
	vec2 corner = abs((UV - 0.5) * pixel_dimensions) - pixel_dimensions * 0.5 + corner_radius_px;
	float distance = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - corner_radius_px;
	if (corner_radius_px > 0.0) alpha *= 1.0 - smoothstep(-0.5, 0.5, distance);
	COLOR = vec4(rgb, alpha) * item_tint;
}
