class_name MapEncounterDialog
extends Control

signal fight_requested
signal retreat_requested
signal intimidate_requested

const FRAME := Rect2(32, 32, 1474, 840)
const DISPLAY_SCALE := 0.9
const ILLUSTRATION_AREA := Rect2(80, 80, 538, 742)
const LOOT_OFFSET_Y := -3.0
const ACTION_OFFSET_Y := 3.0
const CARD_RECTS := [Rect2(627,655,256,134), Rect2(895,655,257,134), Rect2(1165,655,255,134)]
const INK := Color("fbf4bf")
var options := MapEncounterOptions.new()
var canvas: Control
var backing: TextureRect
var location_illustration: TextureRect
var location_frame: TextureRect
var heading: Label
var description: Label
var portrait: TextureRect
var enemy_name: Label
var rank_label: Label
var category_label: Label
var enemy_description: Label
var trait_labels: Array[Label] = []
var loot_slots: Array[MapEncounterItemSlot] = []
var loot_names: Array[Label] = []
var action_cards: Array[Button] = []
var action_buttons: Array[TextureButton] = []
var selection_frames: Array[Panel] = []
var disabled_masks: Array[Panel] = []
var fight_button: TextureButton
var retreat_button: TextureButton
var intimidate_button: TextureButton
var error_label: Label
var selected_index := -1
var _busy := false
var _geometry: Array[Control] = []
var _tag_labels: Array[Label] = []
var _idle_textures: Array[Texture2D] = []
var _selected_textures: Array[Texture2D] = []
var _title_font := SystemFont.new()
var _kai_font := SystemFont.new()

func _init() -> void:
	name = "MapEncounterDialog"
	z_index = 40
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	var error := options.load_options()
	if not error.is_empty():
		push_error(error)
		return
	_title_font.font_names = PackedStringArray(["SimHei", "黑体", "Microsoft YaHei", "sans-serif"])
	_kai_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	backing = _image(FRAME)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(options.background)
	atlas.region = FRAME
	backing.texture = atlas
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	# The card frames/icons are painted into the source; shift that strip too.
	var backing_material := ShaderMaterial.new()
	backing_material.shader = preload("res://scripts/map/encounter_action_offset.gdshader")
	backing_material.set_shader_parameter("offset_y", ACTION_OFFSET_Y)
	backing.material = backing_material
	var frame_texture := load(options.illustration_frame) as Texture2D
	var frame_rect := Rect2(ILLUSTRATION_AREA.get_center()-frame_texture.get_size()*0.5, frame_texture.get_size())
	location_illustration = _image(frame_rect.grow(-4))
	location_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	location_illustration.clip_contents = true
	location_frame = _image(frame_rect)
	location_frame.texture = frame_texture
	heading = _label("", Rect2(715,91,208,86), 52, true)
	description = _label("", Rect2(947,88,470,88), 22)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	portrait = _image(Rect2(697,251,183,183))
	enemy_name = _label("", Rect2(910,244,441,48), 36, true)
	rank_label = _tag()
	category_label = _tag()
	for index in 2: trait_labels.append(_tag())
	enemy_description = _label("", Rect2(910,354,432,78), 25)
	enemy_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("可能掉落", Rect2(931,480,187,42), 27, true, true)
	for index in 3: _build_action(index)
	retreat_button = action_buttons[0]
	fight_button = action_buttons[1]
	intimidate_button = action_buttons[2]
	error_label = _label("", Rect2(624,794,796,27), 16, false, true)
	error_label.add_theme_color_override("font_color", Color("ffb9a8"))
	resized.connect(_layout)

func _place(control: Control, rect: Rect2) -> void:
	control.set_meta("source_rect", rect)
	_geometry.append(control)
	canvas.add_child(control)

func _image(rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = MOUSE_FILTER_IGNORE
	_place(art, rect)
	return art

func _label(text: String, rect: Rect2, font_size: int, title := false, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", _title_font if title else _kai_font)
	label.add_theme_color_override("font_color", INK)
	label.set_meta("source_font_size", font_size)
	_place(label, rect)
	return label

func _tag() -> Label:
	var label := _label("", Rect2(), 18, false, true)
	# Same typography, fill and rounded rim as herb/card tags.
	label.remove_theme_font_override("font")
	label.add_theme_color_override("font_color", Color("c5d0d6"))
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
	_tag_labels.append(label)
	return label

func _build_action(index: int) -> void:
	var action := options.actions[index]
	var rect: Rect2 = CARD_RECTS[index]
	rect.position.y += ACTION_OFFSET_Y
	var card := Button.new()
	card.name = "ActionCard%d" % index
	card.focus_mode = FOCUS_NONE
	card.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_place(card, rect)
	card.pressed.connect(func(): select_action(index))
	action_cards.append(card)
	var highlight := Panel.new()
	highlight.mouse_filter = MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color(action.color)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(action.color, 0.3)
	box.shadow_size = 7
	highlight.add_theme_stylebox_override("panel", box)
	_place(highlight, rect.grow(2))
	highlight.hide()
	selection_frames.append(highlight)
	_label(action.description, Rect2(rect.position.x+70,674+ACTION_OFFSET_Y,rect.size.x-80,34), 24, false, true)
	var button := TextureButton.new()
	button.name = action.id.capitalize()
	_idle_textures.append(load(action.button_idle))
	_selected_textures.append(load(action.button_selected))
	button.texture_normal = _idle_textures[index]
	button.texture_hover = _idle_textures[index]
	button.texture_pressed = _idle_textures[index]
	button.texture_disabled = _idle_textures[index]
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(button, Rect2(rect.get_center().x-85,715+ACTION_OFFSET_Y,170,66))
	button.pressed.connect(func(): activate_action(index))
	action_buttons.append(button)
	card.tooltip_text = action.get("unavailable_reason", "")
	button.tooltip_text = card.tooltip_text
	# Cover the entire unavailable card, including its baked-in frame and icon.
	var mask := Panel.new()
	mask.name = "DisabledMask%d" % index
	mask.mouse_filter = MOUSE_FILTER_IGNORE
	var mask_style := StyleBoxFlat.new()
	mask_style.bg_color = Color(0.09, 0.09, 0.09, 0.68)
	mask_style.set_corner_radius_all(8)
	mask.add_theme_stylebox_override("panel", mask_style)
	_place(mask, rect.grow(2))
	disabled_masks.append(mask)
	mask.visible = not _action_enabled(index)

func _action_enabled(index: int) -> bool:
	return options.actions[index].get("enabled", true)

func _show_loot(enemy: PartyMemberState) -> void:
	for control in loot_slots + loot_names:
		_geometry.erase(control)
		canvas.remove_child(control)
		control.queue_free()
	loot_slots.clear()
	loot_names.clear()
	var items: Array[ItemData] = []
	var seen: Dictionary = {}
	# Display material drops, not combat organs, including first-victory rewards.
	for drop: Dictionary in enemy.definition.get("loot", []):
		if drop.get("chance", 0) <= 0 and not drop.get("first_victory_guaranteed", false): continue
		if seen.has(drop.item_id): continue
		var item := enemy._registry.get_item(drop.item_id)
		if item != null:
			items.append(item)
			seen[drop.item_id] = true
	var step := minf(138, 732.0 / maxi(items.size(), 1))
	for index in items.size():
		var center_x := 1024.0 + (index-(items.size()-1)*0.5)*step
		var slot := MapEncounterItemSlot.new()
		var border := StyleBoxFlat.new()
		border.bg_color = Color("0b161cb0")
		border.border_color = Color("d9bb72")
		border.set_border_width_all(1)
		border.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("panel", border)
		slot.mouse_filter = MOUSE_FILTER_PASS
		_place(slot, Rect2(center_x-42,531+LOOT_OFFSET_Y,84,84))
		slot.show_item(items[index])
		loot_slots.append(slot)
		var label := _label(items[index].display_name, Rect2(center_x-step*0.5,616+LOOT_OFFSET_Y,step,27), 20, false, true)
		loot_names.append(label)

func present(event: Dictionary, enemy: PartyMemberState) -> void:
	location_illustration.texture = load(event.presentation.illustration)
	heading.text = event.title
	description.text = event.description
	portrait.texture = load(enemy.definition.portrait)
	enemy_name.text = enemy.definition.name
	var art: Dictionary = enemy.definition.get("presentation", {})
	rank_label.text = art.get("rank_label", "")
	category_label.text = art.get("category_label", "")
	enemy_description.text = art.get("description", "")
	var traits: Array = art.get("traits", [])
	for index in trait_labels.size():
		trait_labels[index].text = traits[index] if index < traits.size() else ""
	_show_loot(enemy)
	error_label.text = ""
	selected_index = -1
	set_busy(false)
	_refresh_selection()
	show()
	_layout()

func select_action(index: int) -> void:
	if _busy or not visible or index < 0 or index >= action_buttons.size(): return
	if not _action_enabled(index): return
	selected_index = index
	error_label.text = ""
	_refresh_selection()

func activate_action(index: int) -> void:
	if _busy or not visible or index < 0 or index >= action_buttons.size(): return
	if not _action_enabled(index): return
	if selected_index != index:
		select_action(index)
		return
	# MapScreen owns busy/lifecycle state; failed saves restore the controls there.
	match options.actions[index].id:
		"retreat": retreat_requested.emit()
		"fight": fight_requested.emit()
		"intimidate": intimidate_requested.emit()

func _refresh_selection() -> void:
	for index in action_buttons.size():
		var selected := index == selected_index and _action_enabled(index)
		selection_frames[index].visible = selected
		action_buttons[index].texture_hover = _selected_textures[index] if selected else _idle_textures[index]
		action_buttons[index].texture_pressed = action_buttons[index].texture_hover

func set_busy(value: bool) -> void:
	_busy = value
	for index in action_buttons.size():
		var available := _action_enabled(index)
		action_cards[index].disabled = value or not available
		action_buttons[index].disabled = value or not available
		action_cards[index].mouse_default_cursor_shape = CURSOR_POINTING_HAND if available else CURSOR_ARROW
		action_buttons[index].mouse_default_cursor_shape = action_cards[index].mouse_default_cursor_shape
		disabled_masks[index].visible = not available
		if not available and selected_index == index: selected_index = -1
	_refresh_selection()

func _layout() -> void:
	if canvas == null: return
	var factor := minf(size.x/1920.0, size.y/1080.0)*DISPLAY_SCALE
	canvas.size = (FRAME.size*factor).round()
	canvas.position = ((size-canvas.size)*0.5).round()
	# Native pixel sizes avoid scaling an already-rasterized text surface.
	for control in _geometry:
		var rect: Rect2 = control.get_meta("source_rect")
		if control.has_meta("source_font_size"):
			control.add_theme_font_size_override("font_size", maxi(1,roundi(float(control.get_meta("source_font_size"))*factor)))
		control.position = ((rect.position-FRAME.position)*factor).round()
		control.size = (rect.size*factor).round()
	# Variable-width pills are measured using their actual font, not character count.
	var cursor := Vector2(910,310)
	for label in _tag_labels:
		label.visible = not label.text.is_empty()
		if not label.visible: continue
		label.size = label.get_combined_minimum_size()
		var width := label.size.x / maxf(factor,0.01)
		if cursor.x + width > 1352:
			cursor = Vector2(910,cursor.y+31)
		label.position = ((cursor-FRAME.position)*factor).round()
		cursor.x += width+10

func _gui_input(_event: InputEvent) -> void:
	accept_event()
