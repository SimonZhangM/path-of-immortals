shader_type canvas_item;
render_mode unshaded;

// A tapered light falloff for this open landscape, without a flat dark panel
// or intersecting hard side/bottom fades. The Gaussian tail blends into clouds.
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
uniform float top_half_width = 0.245;
uniform float bottom_half_width = 0.18;
uniform float bottom_y = 0.46;
uniform float bottom_fade_start = 0.30;
uniform float bottom_feather = 0.105;

void fragment() {
	float depth = smoothstep(0.0, bottom_y, UV.y);
	float half_width = mix(top_half_width, bottom_half_width, depth);
	float across = abs(UV.x - 0.5) / half_width;
	float below = max(UV.y - bottom_fade_start, 0.0) / bottom_feather;
	float falloff = exp(-pow(across, 4.0) - 0.5 * below * below);
	float density = mix(1.0, 0.86, depth);
	COLOR = vec4(0.015, 0.03, 0.045, opacity * density * falloff);
}
