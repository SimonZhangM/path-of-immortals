class_name MapHeaderUtilityButton
extends Button

enum Kind {
	SETTINGS,
	TASKS,
}

const BACKGROUND := Color("08141f")
const BORDER := Color("263b49")
const ICON := Color("d8e0e5")

var kind := Kind.SETTINGS

func configure(button_kind: Kind, hint: String) -> void:
	kind = button_kind
	tooltip_text = hint
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", _style(BACKGROUND, BORDER))
	add_theme_stylebox_override("hover", _style(BACKGROUND.lightened(0.08), BORDER.lightened(0.18)))
	add_theme_stylebox_override("pressed", _style(BACKGROUND.darkened(0.08), BORDER.lightened(0.08)))
	add_theme_stylebox_override("disabled", _style(BACKGROUND, BORDER))
	queue_redraw()

func _draw() -> void:
	if kind == Kind.SETTINGS:
		_draw_settings()
	else:
		_draw_tasks()

func _draw_settings() -> void:
	var center := size * 0.5
	var ring_radius := minf(size.x, size.y) * 0.16
	var tooth_inner := ring_radius * 1.18
	var tooth_outer := ring_radius * 1.58
	draw_arc(center, ring_radius, 0.0, TAU, 32, ICON, 3.0, true)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var direction := Vector2.from_angle(angle)
		draw_line(center + direction * tooth_inner, center + direction * tooth_outer, ICON, 3.0, true)
	draw_circle(center, ring_radius * 0.38, BACKGROUND)

func _draw_tasks() -> void:
	var center := size * 0.5
	var half_length := minf(size.x * 0.25, 9.0)
	for offset in [-6.0, 0.0, 6.0]:
		var from := center + Vector2(-half_length, offset)
		var to := center + Vector2(half_length, offset)
		draw_line(from, to, ICON, 2.0, true)
		draw_circle(from, 1.0, ICON)
		draw_circle(to, 1.0, ICON)

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	var radius := roundi(minf(size.x, size.y) * 0.5) if kind == Kind.SETTINGS else 6
	style.set_corner_radius_all(radius)
	return style
