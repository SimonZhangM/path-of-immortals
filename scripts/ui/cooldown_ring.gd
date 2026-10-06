class_name CooldownRing
extends RefCounted

const SIZE_SCALE := 2.0 / 3.0
const FONT_SIZE := 10

static func countdown_text(remaining: float) -> String:
	return "%.1f" % remaining if remaining > 0 else "就绪"

static func ink_vertical_bounds(font: Font, text: String, font_size: int) -> Vector2:
	var server := TextServerManager.get_primary_interface()
	var top := INF
	var bottom := -INF
	for character in text.length():
		for rid: RID in font.get_rids():
			var glyph := server.font_get_glyph_index(rid, font_size, text.unicode_at(character), 0)
			if glyph == 0: continue
			var offset := server.font_get_glyph_offset(rid, Vector2i(font_size,0), glyph)
			var extent := server.font_get_glyph_size(rid, Vector2i(font_size,0), glyph)
			if extent.y > 0:
				top = minf(top, offset.y)
				bottom = maxf(bottom, offset.y + extent.y)
			break
	return Vector2(top,bottom) if is_finite(top) else Vector2(-font.get_ascent(font_size),font.get_descent(font_size))

static func paint_text(canvas: Control, center: Vector2, text: String, font_size: int) -> void:
	var font := canvas.get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ink := ink_vertical_bounds(font,text,font_size)
	var baseline := -(ink.x + ink.y) * .5
	canvas.draw_string(font, center + Vector2(-width * .5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

static func tint(registry: ContentRegistry, element: String) -> Color:
	return Color(registry.get_element(element).get("color", "ffffff"))

static func paint(canvas: Control, center: Vector2, radius: float, remaining: float, duration: float, color: Color) -> void:
	radius *= SIZE_SCALE
	canvas.draw_circle(center, radius, Color("15191c", 0.94))
	canvas.draw_arc(center, radius - 2 * SIZE_SCALE, -PI / 2, TAU - PI / 2, 48, Color(color, 0.2), 2 * SIZE_SCALE, true)
	var fraction := clampf(remaining / duration, 0, 1) if duration > 0 else 0.0
	if fraction > 0:
		canvas.draw_arc(center, radius - 2 * SIZE_SCALE, -PI / 2, -PI / 2 + TAU * fraction, 48, color, 2.5 * SIZE_SCALE, true)
	paint_text(canvas, center, countdown_text(remaining), FONT_SIZE)
