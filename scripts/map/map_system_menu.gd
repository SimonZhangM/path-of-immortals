extends Control
## Presentation only; the map controller owns navigation and save commands.
signal action_requested(action: String)
var canvas: Control
var buttons: Dictionary = {}
var message: Label
var busy := false
var _config: Dictionary

func _ready() -> void:
	name = "SystemMenu"
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/system_menu.json"))
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var art := TextureRect.new()
	art.texture = load(_config.texture)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = art.texture.get_size()
	canvas.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for spec in _config.buttons:
		var button := Button.new()
		button.name = spec.id
		button.position = Vector2(spec.rect[0],spec.rect[1])
		button.size = Vector2(spec.rect[2],spec.rect[3])
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not spec.get("enabled",true)
		button.tooltip_text = spec.label+ ("（暂未开放）" if button.disabled else "")
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		for state in ["normal","focus","disabled"]:
			button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1,0.78,0.3,0.12)
		hover.border_color = Color(1,0.83,0.4,0.8)
		hover.set_border_width_all(2)
		hover.set_corner_radius_all(18)
		button.add_theme_stylebox_override("hover",hover)
		var pressed := hover.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0,0,0,0.25)
		button.add_theme_stylebox_override("pressed",pressed)
		button.pressed.connect(func():
			if not busy: action_requested.emit(spec.id))
		canvas.add_child(button)
		buttons[spec.id] = button
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_override("font",load("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf"))
	message.add_theme_font_size_override("font_size",26)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.position = Vector2(140,1410)
	message.size = Vector2(744,100)
	canvas.add_child(message)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var ratio := float(_config.scale_at_1440)*minf(size.x/2560.0,size.y/1440.0)
	canvas.scale = Vector2.ONE*ratio
	canvas.position = (size-canvas.size*ratio)*0.5
