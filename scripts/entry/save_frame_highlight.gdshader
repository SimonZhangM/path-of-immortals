shader_type canvas_item;
render_mode unshaded;

uniform vec4 highlight_color : source_color = vec4(0.90, 0.75, 0.43, 1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Illuminate the artwork's own strokes, including its stepped corners.
	// Restrict to the perimeter so the number diamond and panel fill stay intact.
	vec2 edge_pixels = min(UV, vec2(1.0) - UV) / TEXTURE_PIXEL_SIZE;
	float perimeter = 1.0 - smoothstep(22.0, 30.0, min(edge_pixels.x, edge_pixels.y));
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float strokes = smoothstep(0.12, 0.33, luminance);
	COLOR = vec4(highlight_color.rgb, source.a * strokes * perimeter * highlight_color.a);
}
