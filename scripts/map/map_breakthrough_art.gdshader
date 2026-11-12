shader_type canvas_item;
uniform bool change_disabled = false;
uniform vec4 change_rect;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 local = (UV - change_rect.xy) / (change_rect.zw - change_rect.xy);
	float bevel = 0.11 * abs(local.y * 2.0 - 1.0);
	if (change_disabled && local.y >= 0.0 && local.y <= 1.0 && local.x >= bevel && local.x <= 1.0 - bevel) {
		float value = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		tex.rgb = vec3(value * 0.65);
	}
	COLOR = tex;
}
