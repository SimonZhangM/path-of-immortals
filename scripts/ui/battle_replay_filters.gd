class_name BattleReplayFilters
extends Control

signal filter_selected(key: String)
var buttons: Dictionary = {}
var selected_key := "all"
var _layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/battle_replay_filters.json"))
var _background: Texture2D
var _selection: Texture2D
var _positions: Dictionary = {}

func _init() -> void:
	name = "ReplayModes"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_background = load(_layout.background)
	_selection = load(_layout.selection)
	var factor: float = _layout.display_scale
	custom_minimum_size = Vector2(_layout.source_size[0],_layout.source_size[1])*factor
	size = custom_minimum_size
	var button_size := Vector2(_layout.button_size[0],_layout.button_size[1])*factor
	for entry: Dictionary in _layout.items:
		var key: String = entry.id
		_positions[key] = Vector2(entry.selection_x,_layout.selection_y)*factor
		var button := Button.new()
		button.name = "Filter_"+key
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.position = _positions[key]+Vector2(_layout.caption_center_offset[0],_layout.caption_center_offset[1])*factor-button_size*0.5
		button.size = button_size
		for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
			button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var caption := Label.new()
		caption.name = "Caption"
		caption.text = entry.caption
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size",18)
		button.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.pressed.connect(func():
			select_filter(key)
			filter_selected.emit(key))
		add_child(button)
		buttons[key] = button
	select_filter("all")

func select_filter(key: String) -> void:
	if not buttons.has(key): return
	selected_key = key
	for id: String in buttons:
		buttons[id].set_pressed_no_signal(id==key)
		buttons[id].get_node("Caption").add_theme_color_override("font_color",Color.WHITE if id==key else Color("f5dfac"))
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(_background,Rect2(Vector2.ZERO,size),false)
	# Source offsets are calibrated individually from Downloads/11..55.png.
	draw_texture_rect(_selection,Rect2(_positions[selected_key],_selection.get_size()*float(_layout.display_scale)),false)
