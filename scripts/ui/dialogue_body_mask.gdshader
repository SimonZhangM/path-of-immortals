shader_type canvas_item;
void fragment() {
	// Atlas UVs address the original 2169 x 725 source. Follow the old oval
	// instead of slicing away the nameplate/cloud ornaments with a vertical edge.
	vec2 source = UV / TEXTURE_PIXEL_SIZE;
	float y = (source.y - 344.5) / 218.0;
	float old_rim_right = 282.0 + 213.0 * sqrt(max(0.0, 1.0 - y * y));
	if (source.x < old_rim_right) COLOR.a = 0.0;
}
