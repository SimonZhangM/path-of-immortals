shader_type canvas_item;
render_mode unshaded;
uniform float left_join_x = 529.36;
varying vec2 local_point;
void vertex() {
	local_point = VERTEX;
}
void fragment() {
	float y = clamp(local_point.y / 112.0, 0.0, 1.0);
	float edge = pow(abs(local_point.x / 960.0 - 1.0), 1.7);
	vec3 center = vec3(11.0, 19.0, 32.0) / 255.0;
	vec3 side = vec3(16.0, 34.0, 53.0) / 255.0;
	vec3 color = mix(center, side, edge);
	color += vec3(1.0, 2.0, 3.0) / 255.0 * smoothstep(0.0, 1.0, y);
	float left_blend = 1.0 - smoothstep(left_join_x, left_join_x + 360.0, local_point.x);
	color = mix(color, vec3(20.0, 34.0, 48.0) / 255.0, left_blend);
	COLOR = vec4(color, 1.0);
}
