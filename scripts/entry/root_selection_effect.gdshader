shader_type canvas_item;
uniform float extent = 170.0;
uniform vec2 radii = vec2(130.0, 125.0);
uniform float angle = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform bool animate = true;
uniform float preview_time = 0.0;

void fragment() {
	vec2 point = (UV - 0.5) * extent * 2.0;
	float c = cos(angle);
	float s = sin(angle);
	vec2 local = vec2(c * point.x + s * point.y, -s * point.x + c * point.y);
	vec2 ellipse = local / radii;
	float distance_to_rim = (length(ellipse) - 1.0) * min(radii.x, radii.y);
	float clock = animate ? TIME : preview_time;
	float breath = 0.88 + 0.12 * sin(clock * 2.1);
	float inner_stroke = exp(-pow((distance_to_rim - 7.0) / 2.0, 2.0));
	float outer_stroke = exp(-pow((distance_to_rim - 17.0) / 1.15, 2.0));
	float halo = exp(-pow((distance_to_rim - 9.0) / 12.0, 2.0));
	float theta = atan(ellipse.y, ellipse.x);
	float orbit = pow(max(0.0, cos(theta - clock * 0.8)), 45.0);
	float runner = orbit * exp(-pow((distance_to_rim - 9.0) / 4.0, 2.0));
	float markers = pow(max(0.0, cos(theta * 4.0)), 110.0) * exp(-pow((distance_to_rim - 17.0) / 5.0, 2.0));
	float highlight = clamp(inner_stroke + outer_stroke * 0.65 + runner + markers, 0.0, 1.0);
	vec3 color = mix(tint.rgb, vec3(1.0, 0.94, 0.73), highlight);
	float alpha = clamp((inner_stroke * 0.95 + outer_stroke * 0.65 + halo * 0.3 + runner * 0.7 + markers * 0.65) * breath, 0.0, 1.0);
	COLOR = vec4(color, alpha);
}
