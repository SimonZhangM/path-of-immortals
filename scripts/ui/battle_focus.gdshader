shader_type canvas_item;
render_mode unshaded;

uniform vec2 layout_size = vec2(1920.0, 1080.0);
uniform vec4 ally_board = vec4(160.0, 480.0, 570.0, 570.0);
uniform vec4 enemy_board = vec4(1190.0, 480.0, 548.0, 548.0);
varying vec2 layout_position;

void vertex() {
	layout_position = VERTEX;
}

float board_focus(vec2 p, vec4 board) {
	vec2 center = board.xy + board.zw * 0.5;
	float distance_to_center = length((p - center) / (board.zw * 0.78));
	return 1.0 - smoothstep(0.45, 1.0, distance_to_center);
}

float board_shadow(vec2 p, vec4 board) {
	vec2 center = board.xy + board.zw * 0.5 + vec2(0.0, 9.0);
	vec2 q = abs(p - center) - board.zw * 0.45 + vec2(40.0);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 40.0;
	return 1.0 - smoothstep(-12.0, 55.0, distance_to_edge);
}

float atmosphere_mask(vec2 uv) {
	// Wide, feathered darkening of exposed scenery, with an open central road.
	vec2 from_center = (uv - vec2(0.5, 0.56)) / vec2(0.64, 0.78);
	float corners = smoothstep(0.20, 1.0, dot(from_center, from_center));
	float edges = smoothstep(0.08, 0.48, abs(uv.x - 0.5));
	float top = 1.0 - smoothstep(0.0, 0.35, uv.y);
	float bottom = smoothstep(0.70, 1.0, uv.y);
	return min(0.46, 0.02 + corners * 0.10 + edges * 0.23 + top * 0.095 + bottom * 0.125);
}

void fragment() {
	vec4 original = COLOR;
	vec2 screen_uv = layout_position / layout_size;
	float sides = smoothstep(0.14, 0.39, abs(screen_uv.x - 0.5));
	float luminance = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = mix(original.rgb, vec3(luminance), sides * 0.12);
	float focus = max(board_focus(layout_position, ally_board), board_focus(layout_position, enemy_board));
	float shadow = max(board_shadow(layout_position, ally_board), board_shadow(layout_position, enemy_board));
	color *= (1.0 - focus * 0.10) * (1.0 - shadow * 0.07);
	// Background-only charcoal glaze; UI and artwork retain their own colors.
	color = mix(color, vec3(0.012, 0.014, 0.018), atmosphere_mask(screen_uv));
	COLOR = vec4(color, original.a);
}
