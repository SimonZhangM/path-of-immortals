class_name CooldownRing
extends RefCounted

static func tint(registry: ContentRegistry, element: String) -> Color:
	return Color(registry.get_element(element).get("color", "ffffff"))

static func paint(canvas: Control, center: Vector2, radius: float, remaining: float, duration: float, color: Color) -> void:
	canvas.draw_circle(center, radius, Color("15191c", 0.94))
	canvas.draw_arc(center, radius - 2, -PI / 2, TAU - PI / 2, 48, Color(color, 0.2), 2, true)
	var fraction := clampf(remaining / duration, 0, 1) if duration > 0 else 0.0
	if fraction > 0:
		canvas.draw_arc(center, radius - 2, -PI / 2, -PI / 2 + TAU * fraction, 48, color, 2.5, true)
	var text := "%.1fs" % remaining if remaining > 0 else "就绪"
	canvas.draw_string(canvas.get_theme_default_font(), center + Vector2(-radius, 4), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 12, Color.WHITE)
