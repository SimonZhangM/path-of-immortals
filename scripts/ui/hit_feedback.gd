class_name HitFeedback
extends Control

const HP_COLOR := Color("af3549")
const DURATION := 0.8
const SLASH_DURATION := 0.22
var elapsed: float = 0.0
var damage_label: Label
var _start: Vector2

func configure(amount: int, slot: int = 0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	damage_label = Label.new()
	damage_label.text = "-%d" % amount
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.add_theme_font_size_override("font_size", 32)
	damage_label.add_theme_color_override("font_color", HP_COLOR)
	damage_label.add_theme_color_override("font_outline_color", Color("21151b"))
	damage_label.add_theme_constant_override("outline_size", 5)
	damage_label.add_theme_color_override("font_shadow_color", Color("000000", 0.8))
	damage_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(damage_label)
	damage_label.size = damage_label.get_combined_minimum_size()
	var column: int = [0, -1, 1][slot % 3]
	var spacing := maxf(72, damage_label.size.x + 12)
	_start = size * Vector2(0.5, 0.44) - damage_label.size * 0.5 + Vector2(column * spacing, -(slot / 3) * (damage_label.size.y + 8))
	damage_label.position = _start
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / DURATION, 0, 1)
	damage_label.position = _start + Vector2(0, 45 * progress)
	damage_label.modulate.a = 1.0 - progress
	queue_redraw()
	if elapsed >= DURATION:
		queue_free()

func _draw() -> void:
	if elapsed >= SLASH_DURATION:
		return
	var fade := 1.0 - elapsed / SLASH_DURATION
	var center := size * 0.5
	var extent := minf(size.x, size.y) * 0.34
	var direction := Vector2(0.76, -0.65)
	var normal := Vector2(0.65, 0.76)
	var points := PackedVector2Array([center - direction * extent, center + normal * 6, center + direction * extent, center - normal * 6])
	draw_colored_polygon(points, Color("f9cf8d", fade * 0.45))
	draw_line(center - direction * extent, center + direction * extent, Color("fff4d8", fade), 2.5, true)
	for index in 5:
		var angle := index * TAU / 5.0 + 0.25
		var ray := Vector2.from_angle(angle)
		draw_line(center + ray * 10, center + ray * (22 + elapsed * 80), Color("f1c37a", fade * 0.8), 1.5, true)
