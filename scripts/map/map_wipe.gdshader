shader_type canvas_item;
render_mode unshaded;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool revealing = false;

void fragment() {
	float along = abs(direction.x) > 0.5 ? UV.x : UV.y;
	if (direction.x + direction.y < 0.0) { along = 1.0 - along; }
	// A broad feather makes a gradual fade, with fully clear/black endpoints.
	float edge = mix(-0.12, 1.12, progress);
	float covered = 1.0 - smoothstep(edge - 0.12, edge + 0.12, along);
	COLOR = vec4(0.0, 0.0, 0.0, revealing ? 1.0 - covered : covered);
}
