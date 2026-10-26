shader_type canvas_item;
uniform bool disabled = false;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	if (disabled) {
		float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
		pixel.rgb = vec3(gray * 0.65);
	}
	COLOR = pixel;
}
