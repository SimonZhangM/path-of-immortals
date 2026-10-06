class_name MapEncounterDialog
extends Control

signal fight_requested
signal retreat_requested

const DESIGN_SIZE := Vector2(MapExitDialog.DESIGN_SIZE.x * 4.0 / 3.0, 1008)
const DISPLAY_SCALE := 0.8
# Inside the preview's gold line, below its heading; artwork clouds may be covered.
const PREVIEW_RECT := Rect2(45.75, 714, 630, 178)
const ENEMY_ITEMS_RECT := Rect2(45.75, 494, 630, 166)
const ENEMY_ITEMS_SPLIT := 0.6
const ACTION_BOTTOM_GAP := 30.0
const ACTION_SCALE := 0.8
const TEXT_COLOR := Color("fbf4bf")
var canvas: Control
var backing: TextureRect
var battle_preview: TextureRect
var heading: Label
var description: Label
var portrait: TextureRect
var enemy_name: Label
var rank_label: Label
var category_label: Label
var enemy_description: Label
var enemy_summary: VBoxContainer
var item_slots: Array[MapEncounterItemSlot] = []
var fight_button: TextureButton
var retreat_button: TextureButton
var error_label: Label

func _init() -> void:
	name = "MapEncounterDialog"
	z_index = 40
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.size = DESIGN_SIZE
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	backing = _image(canvas, Rect2(Vector2.ZERO, DESIGN_SIZE))
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	battle_preview = _image(canvas, PREVIEW_RECT)
	battle_preview.name = "BattlePreview"
	battle_preview.stretch_mode = TextureRect.STRETCH_SCALE
	var preview_mask := ShaderMaterial.new()
	preview_mask.shader = preload("res://scripts/ui/concave_image_mask.gdshader")
	preview_mask.set_shader_parameter("panel_size", PREVIEW_RECT.size)
	preview_mask.set_shader_parameter("corner_radius", 18.0)
	battle_preview.material = preview_mask
	heading = _label(canvas, "", Rect2(130, 52, 460, 72), 42)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description = _label(canvas, "", Rect2(48, 140, 624, 60), 18)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing", 4)
	# Preserve the portrait/text arrangement inside the new upper information frame.
	portrait = _image(canvas, Rect2(94.875, 264, 153, 153))
	var details := VBoxContainer.new()
	details.position.x = 256
	details.size = Vector2(397, 0)
	# Center the complete text block after font metrics and wrapping determine its height.
	details.minimum_size_changed.connect(func():
		details.size.y = details.get_combined_minimum_size().y
	)
	details.resized.connect(func():
		details.position.y = portrait.position.y + (portrait.size.y - details.size.y) * 0.5
	)
	details.mouse_filter = MOUSE_FILTER_IGNORE
	details.add_theme_constant_override("separation", 9)
	canvas.add_child(details)
	enemy_name = _label(details, "", Rect2(), 28)
	enemy_name.custom_minimum_size.y = 36
	var description_font := SystemFont.new()
	description_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	var tags := HBoxContainer.new()
	tags.custom_minimum_size.y = 28
	tags.add_theme_constant_override("separation", 12)
	tags.mouse_filter = MOUSE_FILTER_IGNORE
	details.add_child(tags)
	rank_label = _tag(tags, description_font)
	category_label = _tag(tags, description_font)
	enemy_description = _label(details, "", Rect2(), 20)
	enemy_description.custom_minimum_size.y = 72
	enemy_description.add_theme_font_override("font", description_font)
	enemy_description.add_theme_color_override("font_color", Color("deded9"))
	enemy_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	enemy_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_description.add_theme_constant_override("line_spacing", 5)
	_build_enemy_items(description_font)
	fight_button = _button("开战", "res://assets/button-queren.webp", 200)
	retreat_button = _button("撤退", "res://assets/button-quxiao.webp", 520)
	fight_button.pressed.connect(func(): fight_requested.emit())
	retreat_button.pressed.connect(func(): retreat_requested.emit())
	error_label = _label(canvas, "", Rect2(45, 982, 630, 20), 14)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color("ffb9a8"))
	resized.connect(_layout)

func _image(parent: Control, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _build_enemy_items(font: Font) -> void:
	var area := Control.new()
	area.name = "EnemyItems"
	area.position = ENEMY_ITEMS_RECT.position
	area.size = ENEMY_ITEMS_RECT.size
	area.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.add_child(area)
	var slots := CenterContainer.new()
	slots.name = "EmptyItemSlots"
	slots.mouse_filter = MOUSE_FILTER_IGNORE
	area.add_child(slots)
	slots.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	slots.anchor_right = ENEMY_ITEMS_SPLIT
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	grid.mouse_filter = MOUSE_FILTER_IGNORE
	slots.add_child(grid)
	for index in 6:
		var slot := MapEncounterItemSlot.new()
		slot.name = "EmptySlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(72, 72)
		slot.mouse_filter = MOUSE_FILTER_PASS
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color.TRANSPARENT
		frame.border_color = Color("a89165")
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(2)
		slot.add_theme_stylebox_override("panel", frame)
		grid.add_child(slot)
		item_slots.append(slot)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.84, 1.0])
	gradient.colors = PackedColorArray([Color("aeada8", 0.0), Color("aeada8", 0.75), Color("aeada8", 0.75), Color("aeada8", 0.0)])
	var line_texture := GradientTexture2D.new()
	line_texture.gradient = gradient
	line_texture.width = 2
	line_texture.height = 256
	line_texture.fill_from = Vector2(0, 0)
	line_texture.fill_to = Vector2(0, 1)
	var divider := _image(area, Rect2(ENEMY_ITEMS_RECT.size.x * ENEMY_ITEMS_SPLIT - 0.75, 0, 1.5, ENEMY_ITEMS_RECT.size.y))
	divider.name = "EnemyItemsDivider"
	divider.texture = line_texture
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	var right := MarginContainer.new()
	right.name = "EnemySummaryMargin"
	right.mouse_filter = MOUSE_FILTER_IGNORE
	area.add_child(right)
	right.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	right.anchor_left = ENEMY_ITEMS_SPLIT
	right.add_theme_constant_override("margin_left", 12)
	right.add_theme_constant_override("margin_right", 6)
	right.add_theme_constant_override("margin_top", 0)
	right.add_theme_constant_override("margin_bottom", 0)
	enemy_summary = VBoxContainer.new()
	enemy_summary.name = "EnemySummary"
	enemy_summary.size_flags_vertical = SIZE_SHRINK_CENTER
	enemy_summary.add_theme_constant_override("separation", 4)
	enemy_summary.mouse_filter = MOUSE_FILTER_IGNORE
	var summary_theme := Theme.new()
	summary_theme.default_font = font
	enemy_summary.theme = summary_theme
	right.add_child(enemy_summary)

func _show_enemy_summary(rows: Array) -> void:
	for child in enemy_summary.get_children():
		enemy_summary.remove_child(child)
		child.queue_free()
	for entry: Dictionary in rows:
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		enemy_summary.add_child(row)
		var icon := _image(row, Rect2())
		icon.custom_minimum_size = Vector2(20, 20)
		icon.size_flags_vertical = SIZE_SHRINK_BEGIN
		icon.texture = load(entry.icon)
		# Separate columns keep continuation lines aligned with the value, not the label.
		var fields := HBoxContainer.new()
		fields.size_flags_horizontal = SIZE_EXPAND_FILL
		fields.mouse_filter = MOUSE_FILTER_IGNORE
		fields.add_theme_constant_override("separation", 7)
		row.add_child(fields)
		for field in ["label", "value"]:
			var text := Label.new()
			text.name = "SummaryLabel" if field == "label" else "SummaryValue"
			text.text = entry[field]
			text.autowrap_mode = TextServer.AUTOWRAP_OFF
			text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			text.size_flags_vertical = SIZE_SHRINK_BEGIN
			text.mouse_filter = MOUSE_FILTER_IGNORE
			text.add_theme_font_size_override("font_size", 20)
			text.add_theme_color_override("font_color", Color("d9c59a") if field == "label" else Color("deded9"))
			if field == "value":
				text.size_flags_horizontal = SIZE_EXPAND_FILL
			if field == "value" and entry.get("below_label", false):
				# A free child is excluded from the VBox minimum: only the four
				# heading rows are centered. The extra trait line hangs below.
				var caption: Label = fields.get_child(0)
				caption.add_child(text)
				caption.resized.connect(func(): text.position = Vector2(0, caption.size.y + 4))
				text.position = Vector2(0, caption.get_minimum_size().y + 4)
			else:
				fields.add_child(text)

func _label(parent: Control, text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimHei", "黑体", "Microsoft YaHei", "sans-serif"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	parent.add_child(label)
	return label

func _tag(parent: Control, font: Font) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.33, 0.35, 0.85)
	style.border_color = Color(0.73, 0.76, 0.77, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var label := _label(panel, "", Rect2(), 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", Color("deded9"))
	return label

func _button(text: String, path: String, center_x: float) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = load(path)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.size = MapRewardDialog.ACTION_SIZE
	# Shrink both buttons, captions and their gap together about the old group center.
	button.scale = Vector2.ONE * ACTION_SCALE / DISPLAY_SCALE
	var displayed_size := button.size * button.scale
	var group_center_y := DESIGN_SIZE.y - ACTION_BOTTOM_GAP - button.size.y / DISPLAY_SCALE * 0.5
	center_x = DESIGN_SIZE.x * 0.5 + (center_x - DESIGN_SIZE.x * 0.5) * ACTION_SCALE
	button.position = Vector2(center_x, group_center_y) - displayed_size * 0.5
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.focus_mode = FOCUS_NONE
	canvas.add_child(button)
	var caption := _label(button, text, Rect2(Vector2.ZERO, button.size), 26)
	caption.name = "Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return button

func present(event: Dictionary, enemy: PartyMemberState) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(event.presentation.background)
	var region: Array = event.presentation.background_region
	atlas.region = Rect2(region[0], region[1], region[2], region[3])
	backing.texture = atlas
	var background_path: String = event.presentation.get("battle_background", "")
	battle_preview.texture = load(background_path) if not background_path.is_empty() else null
	battle_preview.visible = battle_preview.texture != null
	heading.text = event.title
	description.text = event.description
	portrait.texture = load(enemy.definition.portrait)
	enemy_name.text = enemy.definition.name
	rank_label.text = event.enemy_rank
	category_label.text = event.get("enemy_category", "")
	category_label.get_parent().visible = not category_label.text.is_empty()
	enemy_description.text = event.enemy_description
	var equipment := enemy.inventory.get_instances()
	for index in item_slots.size():
		item_slots[index].show_item(enemy._registry.get_item(equipment[index].item_id) if index < equipment.size() else null)
	var rows: Array = event.presentation.get("enemy_summary", []).duplicate(true)
	for row: Dictionary in rows:
		if row.get("stat") == "hp":
			row.value = str(enemy.maximum("hp"))
		elif row.get("stat") == "resources":
			row.value = "%d / %d" % [enemy.maximum("hp"), enemy.maximum("stamina")]
		elif row.get("stat") == "armor":
			row.value = enemy.armor_type
	_show_enemy_summary(rows)
	error_label.text = ""
	set_busy(false)
	show()
	_layout()

func set_busy(busy: bool) -> void:
	fight_button.disabled = busy
	retreat_button.disabled = busy

func _layout() -> void:
	canvas.scale = Vector2.ONE * minf(size.x / 1920.0, size.y / 1080.0) * DISPLAY_SCALE
	canvas.position = (size - DESIGN_SIZE * canvas.scale) * 0.5

func _gui_input(_event: InputEvent) -> void:
	accept_event()
