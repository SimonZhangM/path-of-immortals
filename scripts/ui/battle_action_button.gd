class_name BattleActionButton
extends Button

var artwork: Texture2D
var action_icon: Texture2D:
	set(value):
		if action_icon != value:
			action_icon = value
			queue_redraw()
var caption: String = "":
	set(value):
		if caption != value:
			caption = value
			queue_redraw()
var feedback_remaining: float = 0.0
var press_depth: float = 0.0
var _held: bool = false

static func trimmed_art(path: String) -> Texture2D:
	var source: Texture2D = load(path)
	var trimmed := AtlasTexture.new()
	trimmed.atlas = source
	trimmed.region = source.get_image().get_used_rect()
	return trimmed

func configure(path: String, minimum: Vector2) -> void:
	artwork = trimmed_art(path)
	custom_minimum_size = minimum
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(func():
		_held = false
		queue_redraw()
	)
	button_down.connect(func(): _held = not disabled)
	button_up.connect(func(): _held = false)
	pressed.connect(func():
		if not disabled:
			# A quick tap still presses once, then returns directly to rest.
			press_depth = maxf(press_depth, 0.65)
			feedback_remaining = 0.16
			queue_redraw()
	)

func _process(delta: float) -> void:
	var target := 1.0 if _held and not disabled else 0.0
	var previous := press_depth
	press_depth = move_toward(press_depth, target, delta / (0.06 if target > 0 else 0.16))
	feedback_remaining = maxf(0, feedback_remaining - delta)
	if not is_equal_approx(previous, press_depth):
		queue_redraw()

func _draw() -> void:
	if artwork == null:
		return
	var press_scale := 1.0 - 0.03 * press_depth
	draw_set_transform(size * (1.0 - press_scale) * 0.5, 0, Vector2.ONE * press_scale)
	var tint := Color.WHITE
	if disabled:
		tint = Color(0.52, 0.52, 0.52, 0.8)
	var art_size := artwork.get_size() * minf(size.x / artwork.get_width(), size.y / artwork.get_height())
	draw_texture_rect(artwork, Rect2((size - art_size) * 0.5, art_size), false, tint)
	if caption.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := 25
	var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_size := Vector2.ZERO
	if action_icon != null:
		icon_size = action_icon.get_size() * (36.0 / maxf(action_icon.get_width(), action_icon.get_height()))
	var gap := 17.0 if action_icon != null else 0.0
	var group_left := (size.x - text_width - icon_size.x - gap) * 0.5
	var baseline := (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	var text_origin := Vector2(group_left + icon_size.x + gap, baseline)
	draw_string(font, text_origin + Vector2(1, 1), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("071b20", tint.a))
	draw_string(font, text_origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff5da") * tint)
	if action_icon != null:
		draw_texture_rect(action_icon, Rect2(Vector2(group_left, (size.y - icon_size.y) * 0.5), icon_size), false, tint)
	draw_set_transform(Vector2.ZERO)
