shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(630.0, 291.0);
uniform float corner_radius = 18.0;
varying vec4 panel_tint;

void vertex() {
	panel_tint = COLOR;
}

void fragment() {
	// Cover with the original aspect ratio. UV stays local to the panel so the
	// four concave notches do not move when a differently shaped image is used.
	vec2 image_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float cover_scale = max(panel_size.x / image_size.x, panel_size.y / image_size.y);
	vec2 visible_uv = panel_size / (image_size * cover_scale);
	vec2 image_uv = (UV - 0.5) * visible_uv + 0.5;
	vec4 source = texture(TEXTURE, image_uv);
	vec2 corner_offset = min(UV, vec2(1.0) - UV) * panel_size;
	float distance_to_corner = length(corner_offset);
	float aa = max(fwidth(distance_to_corner), 0.001);
	// Subtract quarter-discs centered on the actual corners (inward curves).
	float mask = smoothstep(corner_radius - aa * 0.5, corner_radius + aa * 0.5, distance_to_corner);
	COLOR = vec4(source.rgb, source.a * mask) * panel_tint;
}
