shader_type canvas_item;
render_mode unshaded;

uniform vec2 frame_size = vec2(112.0, 110.0);
uniform vec2 image_size = vec2(431.0);
uniform vec2 uv_origin = vec2(0.0);
uniform vec2 uv_size = vec2(1.0);
uniform float image_zoom = 1.04;
uniform float corner_cut = 8.0;

void fragment() {
	vec2 local_uv = (UV - uv_origin) / uv_size;
	float cover_scale = max(frame_size.x / image_size.x, frame_size.y / image_size.y);
	vec2 crop_size = frame_size / (image_size * cover_scale * image_zoom);
	vec2 cropped_uv = (local_uv - vec2(0.5)) * crop_size + vec2(0.5);
	vec4 portrait = texture(TEXTURE, uv_origin + cropped_uv * uv_size);
	vec2 point = local_uv * frame_size;
	vec2 edge = min(point, frame_size - point);
	float distance_to_corner = edge.x + edge.y - corner_cut;
	portrait.a *= smoothstep(0.0, max(fwidth(distance_to_corner), 0.001), distance_to_corner);
	COLOR = portrait;
}
