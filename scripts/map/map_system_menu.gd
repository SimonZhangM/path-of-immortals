extends Control
## Presentation only; the map controller owns navigation and save commands.
class InsetButtonStyle extends StyleBox:
	var fill_color := Color(1,0.78,0.3,0.12)

	func _draw(canvas_item: RID, rect: Rect2) -> void:
		var inner := rect.grow(-6.0)
		var radius := 20.0
		var corners := [Vector2(inner.end.x,inner.position.y),inner.end,Vector2(inner.position.x,inner.end.y),inner.position]
		var angles := [PI,-PI/2.0,0.0,PI/2.0]
		var outline := PackedVector2Array()
		for corner in 4:
			for step in 9:
				var angle: float = angles[corner]-PI/2.0*step/8.0
				outline.append(corners[corner]+Vector2(cos(angle),sin(angle))*radius)
		RenderingServer.canvas_item_add_polygon(canvas_item,outline,PackedColorArray([fill_color]))
		outline.append(outline[0])
		RenderingServer.canvas_item_add_polyline(canvas_item,outline,PackedColorArray([Color(1,0.83,0.4,0.8)]),2.0,true)

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
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		for state in ["normal","focus","disabled"]:
			button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var hover := InsetButtonStyle.new()
		button.add_theme_stylebox_override("hover",hover)
		var pressed := InsetButtonStyle.new()
		pressed.fill_color = Color(0,0,0,0.25)
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
