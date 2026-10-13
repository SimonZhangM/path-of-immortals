shader_type canvas_item;

// Source-image coordinates include the AtlasTexture's outer crop.
// Keep the shell/divider fixed; move only the strip with the three baked cards.
uniform float offset_y = 3.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec2 source = UV / TEXTURE_PIXEL_SIZE;
	if (source.x >= 618.0 && source.x <= 1432.0 &&
			source.y >= 648.0 && source.y <= 802.0) {
		// Extend the empty upper margin into the newly exposed narrow gap.
		source.y = max(648.0, source.y - offset_y);
	}
	COLOR = vertex_tint * texture(TEXTURE, source * TEXTURE_PIXEL_SIZE);
}
