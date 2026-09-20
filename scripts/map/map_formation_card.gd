extends Button

signal edit_requested

const EDIT_DELAY := 3.0
var edit_button: Button
var hover_seconds := 0.0
var hover_active := false

func enable_edit() -> void:
	edit_button = Button.new()
	edit_button.name = "EditFormation"
	edit_button.tooltip_text = "修改阵型"
	edit_button.focus_mode = Control.FOCUS_NONE
	edit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	edit_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	edit_button.visible = false
	for state in ["normal", "hover", "pressed", "focus"]:
		edit_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(edit_button)
	edit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	edit_button.offset_left = -32
	edit_button.offset_right = -2
	edit_button.offset_top = 2
	edit_button.offset_bottom = 32
	edit_button.draw.connect(func():
		for y in [9.0, 15.0, 21.0]:
			edit_button.draw_line(Vector2(7, y), Vector2(23, y), Color("d9bb72"), 2.0, true)
			edit_button.draw_circle(Vector2(7, y), 1.0, Color("d9bb72"), true, -1, true)
			edit_button.draw_circle(Vector2(23, y), 1.0, Color("d9bb72"), true, -1, true)
	)
	edit_button.pressed.connect(func(): edit_requested.emit())
	set_process(false)

func _input(event: InputEvent) -> void:
	if edit_button == null or not event is InputEventMouseMotion:
		return
	if is_visible_in_tree() and get_global_rect().has_point(event.position):
		_begin_edit_hover()
	elif hover_active:
		_reset_edit_hover()

func _begin_edit_hover() -> void:
	if edit_button == null:
		return
	if not hover_active:
		hover_seconds = 0.0
	hover_active = true
	set_process(true)

func _reset_edit_hover() -> void:
	hover_active = false
	hover_seconds = 0.0
	if edit_button != null:
		edit_button.hide()
	set_process(false)

func _process(delta: float) -> void:
	if edit_button == null:
		set_process(false)
		return
	if not hover_active:
		set_process(false)
		return
	if not is_visible_in_tree() or not get_window().has_focus() or get_viewport().gui_is_dragging():
		_reset_edit_hover()
		return
	hover_seconds += delta
	if hover_seconds >= EDIT_DELAY:
		hover_seconds = EDIT_DELAY
		edit_button.show()
