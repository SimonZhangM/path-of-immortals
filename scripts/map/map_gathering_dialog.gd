class_name MapGatheringDialog
extends Control

signal cancelled
signal gathering_requested(forecast: Dictionary)

# Coordinates follow the existing artwork; trim only the outer transparent canvas.
const FRAME := Rect2(32, 32, 1474, 840)
const CARD_RECTS := [Rect2(657,548,216,245), Rect2(918,548,211,245), Rect2(1175,548,214,245)]
# Source-art bands calibrated to the 2026-10-09 background update.
const HERB_FRAME := Rect2(730,198,267,286)
const HERB_IMAGE_BOTTOM := 413.0
const HERB_NAME_BOTTOM := 449.0
const FORECAST_FRAME := Rect2(1049,198,268,286)
const METHOD_TIME_BOTTOM := 733.0
const INK := Color("fbf4bf")
const DISPLAY_SCALE := 0.9
# Source-art inner rim x80 / y80..822 and heading divider's left end x618.
const ILLUSTRATION_AREA := Rect2(80, 80, 538, 742)
var options := MapGatheringOptions.new()
var selected_index := -1
var canvas: Control
var heading: Label
var location_description: Label
var method_note: Label
var location_illustration: TextureRect
var location_frame: TextureRect
var _location: Dictionary = {}
var later_button: Button
var method_cards: Array[Button] = []
var action_buttons: Array[BaseButton] = []
var value_labels: Array[RichTextLabel] = []
var herb_slot: HerbSlot
var herb_art: MapItemArtwork
var herb_name: Label
var herb_grade: Label
var herb_category: Label
var method_heading: Label
var error_label: Label
var selection_frames: Array[Panel] = []
var _geometry: Array[Control] = []
var _font: SystemFont
var _title_font: SystemFont
var _kai_font: SystemFont
var _idle_textures: Array[Texture2D] = []
var _selected_textures: Array[Texture2D] = []
var _busy := false

class HerbSlot extends Control:
	var model: MapLoadoutState
	var item_id := ""
	func _ready() -> void:
		ItemTooltipHost.bind(self, func(_point: Vector2): return item_id, build_item_tooltip)
	func _get_tooltip(_point: Vector2) -> String:
		return ""
	func build_item_tooltip(_text: String) -> Object:
		if model == null or item_id.is_empty(): return null
		var tip := ItemTooltip.new()
		tip.configure(model.registry.get_item(item_id), {}, -1, 0, true)
		return tip

func _init(options_path := "res://data/ui/gathering_options.json") -> void:
	name = "MapGatheringDialog"
	z_index = 42
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	var error := options.load_options(options_path)
	if not error.is_empty():
		push_error(error)
		return
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["SimSun", "宋体", "serif"])
	_title_font = SystemFont.new()
	_title_font.font_names = PackedStringArray(["SimHei", "黑体", "Microsoft YaHei", "sans-serif"])
	_kai_font = SystemFont.new()
	_kai_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.02,0.03,0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	var art := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(options.background)
	atlas.region = FRAME
	art.texture = atlas
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.add_child(art)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_location_illustration()
	# Logo's visible right edge is source x689: halve the former 52px gap to 26px.
	heading = _label("药村西坡", Rect2(715,91,208,86), 52, INK, false, true)
	location_description = _label("", Rect2(947,91,257,86), options.location_font_size)
	location_description.add_theme_font_override("font", _kai_font)
	location_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	later_button = _hit_button("Later", Rect2(1216,108,204,55))
	later_button.pressed.connect(cancel)
	_label("稍后再说", Rect2(1235,114,167,43), 27, INK, true, true)
	_label(">", Rect2(1379,114,18,43), 27, INK, true, true).name = "LaterChevron"
	_label("预计收获", Rect2(FORECAST_FRAME.get_center().x-42,213,84,36), 20, INK, true, true)
	var names := ["基础收获", "随机额外", options.activity+"方式", options.activity+"耗时"]
	for row in 4:
		var y := 257.5 + row * 41.0
		_label(names[row], Rect2(1105,y,92,35), 18, INK, false, true)
		var value := _rich_label("—", Rect2(1191,y,98,35), 19, Color("8be2bb"))
		value.add_theme_font_override("normal_font", _kai_font)
		value_labels.append(value)
	# Center the note in the free band below the last row (y416) and above y484.
	method_note = _label("", Rect2(FORECAST_FRAME.get_center().x-118,422,236,56), 18, INK, true)
	method_note.add_theme_font_override("font", _kai_font)
	method_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	method_heading = _label("选择"+options.activity+"方式", Rect2(CARD_RECTS[1].get_center().x-108.5,497.5,217,37), 23, INK, true, true)
	herb_slot = HerbSlot.new()
	herb_slot.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(herb_slot, HERB_FRAME)
	var herb_center := HERB_FRAME.get_center().x
	herb_name = _label("", Rect2(herb_center-117.5,(HERB_IMAGE_BOTTOM+HERB_NAME_BOTTOM)*0.5-17.5+options.item_name_offset_y,235,35), 26, INK, true)
	herb_name.remove_theme_font_override("font")
	var tag_y := (HERB_NAME_BOTTOM+HERB_FRAME.end.y)*0.5-11.5+options.item_tags_offset_y
	herb_grade = _herb_tag("", Rect2(herb_center-52.5,tag_y,49,23))
	herb_category = _herb_tag("药材", Rect2(herb_center+3.5,tag_y,49,23))
	error_label = _label("", Rect2(herb_center-131,383,262,26), 14, Color("ffb9a8"), true)
	for index in options.methods.size():
		_build_method(index)
	resized.connect(_layout)

func _place(control: Control, rect: Rect2) -> void:
	control.set_meta("source_rect", rect)
	_geometry.append(control)
	canvas.add_child(control)

func _build_location_illustration() -> void:
	if options.illustration_frame.is_empty(): return
	var frame_texture := load(options.illustration_frame) as Texture2D
	# Preserve the border's native 463x694 source size; only follow popup scaling.
	var frame_rect := Rect2(ILLUSTRATION_AREA.get_center()-frame_texture.get_size()*0.5, frame_texture.get_size())
	location_illustration = TextureRect.new()
	location_illustration.name = "LocationIllustration"
	location_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	location_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	location_illustration.clip_contents = true
	location_illustration.mouse_filter = MOUSE_FILTER_IGNORE
	_place(location_illustration, frame_rect.grow(-4))
	location_frame = TextureRect.new()
	location_frame.name = "LocationIllustrationFrame"
	location_frame.texture = frame_texture
	location_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	location_frame.mouse_filter = MOUSE_FILTER_IGNORE
	# Overlay the transparent original border; no extra tint or image editing.
	_place(location_frame, frame_rect)

func bind_herb(record: Dictionary, model: MapLoadoutState) -> void:
	_location = options.locations.get(record.id, {})
	if location_illustration != null:
		var picture_path: String = _location.get("illustration", "")
		location_illustration.texture = null if picture_path.is_empty() else load(picture_path)
		location_illustration.visible = not picture_path.is_empty()
		location_frame.visible = location_illustration.visible
	location_description.text = _location.get("description", "")
	_refresh_selection()
	herb_slot.model = model
	herb_slot.item_id = record.id
	herb_name.text = record.name
	herb_grade.text = record.quality
	herb_category.text = record.get("subcategory", "药材")
	if herb_art != null:
		_geometry.erase(herb_art)
		herb_art.queue_free()
	herb_art = MapItemArtwork.new()
	herb_art.configure(record)
	# Align visible pixels, not the file's transparent margins, within the image band.
	_place(herb_art, Rect2(HERB_FRAME.get_center().x-95,(HERB_FRAME.position.y+HERB_IMAGE_BOTTOM)*0.5-77.5,190,155))
	_layout()

func _rich_label(text: String, rect: Rect2, font_size: int, color := INK) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.scroll_active = false
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("normal_font", _font)
	label.add_theme_color_override("default_color", color)
	label.set_meta("source_font_size", font_size)
	_place(label,rect)
	return label

func _herb_tag(text: String, rect: Rect2) -> Label:
	var label := _label(text, rect, 14, Color("c5d0d6"), true)
	# Match inventory-card tags: inherited UI font, dark fill and rounded rim.
	label.remove_theme_font_override("font")
	var box := StyleBoxFlat.new()
	box.bg_color = Color("12212ac0")
	box.border_color = Color("61727a")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 1
	box.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", box)
	return label

func _label(text: String, rect: Rect2, font_size: int, color := INK, centered := false, title := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", _title_font if title else _font)
	label.add_theme_color_override("font_color", color)
	label.set_meta("source_font_size", font_size)
	_place(label, rect)
	return label

func _hit_button(node_name: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_place(button, rect)
	return button

func _build_method(index: int) -> void:
	var method := options.methods[index]
	var rect: Rect2 = CARD_RECTS[index]
	var card := _hit_button("Method%d" % index, rect)
	card.pressed.connect(func(): select_method(index))
	method_cards.append(card)
	var highlight := Panel.new()
	highlight.name = "Selection%d" % index
	highlight.mouse_filter = MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color(method.color)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(method.color, 0.3)
	box.shadow_size = 7
	highlight.add_theme_stylebox_override("panel", box)
	_place(highlight, rect.grow(2))
	highlight.hide()
	selection_frames.append(highlight)
	_label(method.name, Rect2(rect.position.x+8,600+options.method_name_offset_y,rect.size.x-16,39), 26, Color(method.color), true, true).name = "MethodName%d" % index
	var forecast := options.forecast(index)
	var gain := _label("获得 %d～%d %s" % [forecast.total_min,forecast.total_max,options.unit], Rect2(rect.position.x+76,649,rect.size.x-85,38), 18)
	var time := _label("耗时 %d天" % forecast.days, Rect2(rect.position.x+76,694,rect.size.x-85,37), 18)
	gain.add_theme_font_override("font", _kai_font)
	time.add_theme_font_override("font", _kai_font)
	var action: BaseButton
	if options.text_buttons:
		var button := Button.new()
		button.text = "开始采矿"
		button.add_theme_font_override("font", _title_font)
		button.set_meta("source_font_size", 22)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, Color(method.color))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		action = button
		_idle_textures.append(null)
		_selected_textures.append(null)
	else:
		var button := TextureButton.new()
		_idle_textures.append(load(method.button_idle))
		_selected_textures.append(load(method.button_selected))
		button.texture_normal = _idle_textures[index]
		button.texture_hover = _idle_textures[index]
		button.texture_pressed = _idle_textures[index]
		button.texture_disabled = _idle_textures[index]
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		action = button
	action.name = "Gather%d" % index
	action.focus_mode = FOCUS_NONE
	action.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	# Center between the updated time-box bottom and the card bottom.
	_place(action, Rect2(rect.position.x+9,(METHOD_TIME_BOTTOM+rect.end.y)*0.5-29.5,rect.size.x-18,59))
	action.pressed.connect(func(): activate_method(index))
	action_buttons.append(action)
	if options.text_buttons: _style_mining_button(index)

func _style_mining_button(index: int) -> void:
	var tint := Color(options.methods[index].color)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var lit: bool = index == selected_index and state in ["hover", "pressed"]
		var box := StyleBoxFlat.new()
		box.bg_color = Color("12252a").lerp(tint, 0.22 if lit else 0.04)
		box.border_color = tint if lit else tint.darkened(0.35)
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		action_buttons[index].add_theme_stylebox_override(state, box)

func present(title := "药村西坡") -> void:
	heading.text = title
	error_label.text = ""
	selected_index = -1
	set_busy(false)
	_refresh_selection()
	show()
	_layout()

func select_method(index: int) -> void:
	if _busy or index < 0 or index >= options.methods.size(): return
	selected_index = index
	_refresh_selection()

func activate_method(index: int) -> void:
	if _busy or index < 0 or index >= options.methods.size(): return
	# First click chooses. Only a subsequent click on the lit button starts gathering.
	if selected_index != index:
		select_method(index)
		return
	set_busy(true)
	gathering_requested.emit(options.forecast(index))

func _refresh_selection() -> void:
	for index in action_buttons.size():
		selection_frames[index].visible = index == selected_index
		# Selection alone keeps the idle art; only a hovered selected button lights up.
		if options.text_buttons:
			_style_mining_button(index)
		else:
			var action := action_buttons[index] as TextureButton
			action.texture_normal = _idle_textures[index]
			action.texture_hover = _selected_textures[index] if index == selected_index else _idle_textures[index]
			action.texture_pressed = action.texture_hover
	var forecast := options.forecast(selected_index)
	if forecast.is_empty():
		for label in value_labels: label.text = "—"
		method_note.text = ""
		return
	method_note.text = _location.get("notes", {}).get(forecast.method_id, "")
	var values := ["%d[color=#ffffff]%s[/color]" % [forecast.base,options.unit], "%d～%d[color=#ffffff]%s[/color]" % [forecast.extra_min,forecast.extra_max,options.unit], forecast.name, "%d[color=#ffffff]天[/color]" % forecast.days]
	for index in value_labels.size(): value_labels[index].text = "[right]%s[/right]" % values[index]

func set_busy(value: bool) -> void:
	_busy = value
	later_button.disabled = value
	for button in method_cards: button.disabled = value
	for button in action_buttons: button.disabled = value

func cancel() -> void:
	if _busy or not visible: return
	hide()
	cancelled.emit()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()

func _layout() -> void:
	if canvas == null: return
	var factor := minf(size.x / 1920.0, size.y / 1080.0) * DISPLAY_SCALE
	canvas.size = (FRAME.size * factor).round()
	canvas.position = ((size - canvas.size) * 0.5).round()
	# Native pixel layout and integer font sizes avoid a scaled text surface at 2K.
	for control in _geometry:
		var rect: Rect2 = control.get_meta("source_rect")
		if control.has_meta("source_font_size"):
			control.add_theme_font_size_override("normal_font_size" if control is RichTextLabel else "font_size", roundi(float(control.get_meta("source_font_size")) * factor))
		control.position = ((rect.position - FRAME.position) * factor).round()
		control.size = (rect.size * factor).round()
		if control in [herb_name, herb_grade, herb_category]:
			# Center the final font/style minimum size inside its own artwork band.
			control.position.y = roundf((rect.get_center().y-FRAME.position.y)*factor-control.size.y*0.5)
		if control == herb_art:
			herb_art.center_visible_at((rect.get_center() - FRAME.position) * factor)

func _gui_input(_event: InputEvent) -> void:
	accept_event()
