shader_type canvas_item;

uniform vec2 portrait_size = vec2(1.0);
varying vec2 mask_uv;

void vertex() {
	mask_uv = VERTEX / portrait_size;
}

void fragment() {
	float distance_to_center = length((mask_uv - vec2(0.5)) * 2.0);
	float feather = max(fwidth(distance_to_center), 0.001);
	COLOR.a *= 1.0 - smoothstep(1.0 - feather, 1.0, distance_to_center);
}
