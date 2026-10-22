shader_type canvas_item;
render_mode unshaded;

// Trace the existing painted frame, preserving its silhouette and title.
uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform vec2 source_size = vec2(1605.0, 567.0);
uniform vec4 source_region;
uniform vec4 card_rect;
uniform vec4 heading_rect;
uniform vec2 ring_center;
uniform float ring_radius = 44.0;
uniform float strength = 1.0;
uniform vec4 glow_color : source_color = vec4(0.08, 0.65, 1.0, 1.0);

float painted_edge(vec2 p) {
	vec4 ink = texture(artwork, p / source_size);
	float brightest = max(ink.r, max(ink.g, ink.b));
	float chroma = brightest - min(ink.r, min(ink.g, ink.b));
	float ring_distance = length(p - ring_center);
	float ring = smoothstep(ring_radius * 0.58, ring_radius * 0.68, ring_distance) * (1.0 - smoothstep(ring_radius + 5.0, ring_radius + 9.0, ring_distance));
	vec2 q = p - card_rect.xy;
	bool in_card = all(greaterThanEqual(q, vec2(-4.0))) && all(lessThanEqual(q, card_rect.zw + vec2(4.0)));
	// Source has no skill pictures; exclude only the baked-in gold heading.
	vec2 text_point = p - heading_rect.xy;
	bool heading = all(greaterThanEqual(text_point, vec2(0.0))) && all(lessThanEqual(text_point, heading_rect.zw));
	float gold = smoothstep(0.07, 0.22, ink.r - ink.b) * smoothstep(0.25, 0.65, ink.r);
	float frame = (in_card && !heading) ? gold : 0.0;
	return ink.a * max(frame, ring * smoothstep(0.23, 0.65, brightest) * smoothstep(0.06, 0.23, chroma));
}

void fragment() {
	vec2 p = source_region.xy + UV * source_region.zw;
	float core = painted_edge(p);
	float near_glow = 0.0;
	float far_glow = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle));
		near_glow += painted_edge(p + direction * 3.0);
		far_glow += painted_edge(p + direction * 9.0);
	}
	near_glow /= 8.0;
	far_glow /= 8.0;
	vec2 r = p - ring_center;
	float halo = exp(-pow((length(r) - ring_radius) / 11.0, 2.0)) * 0.19;
	vec2 star = abs(p - (ring_center - vec2(0.0, ring_radius + 7.0)));
	float glint = exp(-star.x / 1.1 - star.y / 9.0) + exp(-star.x / 7.0 - star.y / 1.1);
	float ring_area = 1.0 - smoothstep(ring_radius + 10.0, ring_radius + 14.0, length(r));
	float alpha = clamp(core * 1.55 + near_glow * 0.62 + far_glow * 0.42 + halo + glint * 0.55, 0.0, 1.0);
	// Preserve the original connecting line, including its native thickness.
	// Contract the solid band from [-8, 8] to [-4, 3] source pixels,
	// retaining five-pixel feathering above and below the new edges.
	float connection_band = smoothstep(-9.0, -4.0, r.y) * (1.0 - smoothstep(3.0, 8.0, r.y));
	float connection = smoothstep(ring_radius - 1.0, ring_radius + 2.0, abs(r.x)) * connection_band;
	alpha *= 1.0 - connection;
	// Leave the engraved ring's dark details visible beneath the themed light.
	alpha *= mix(1.0, 0.66, ring_area) * strength;
	vec3 highlight = mix(glow_color.rgb, vec3(1.0), 0.42);
	vec3 tint = mix(glow_color.rgb, highlight, clamp(core * 0.85 + glint * 0.35, 0.0, 1.0));
	COLOR = vec4(tint, alpha);
}
