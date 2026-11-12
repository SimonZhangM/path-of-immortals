extends Control

const DESIGN_SIZE := Vector2(1120, 884)
const FONT := preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
const FONT_SIZE := 18
const FILTERS := [["all", "全部"], ["me", "我方"], ["enemy", "敌方"], ["damage", "伤害"], ["recovery", "治疗"], ["buff", "增益"], ["debuff", "减益"]]
const PLAYER_PORTRAITS := preload("res://scripts/presentation/player_portrait_frames.gd")
const FACE_CROP := Rect2(154, 125, 228, 228)
const CLOSE_CENTER := Vector2(1078, 56.5)
const CLOSE_GOLD_REGION := Rect2(20, 20, 280, 280)
const CLOSE_GOLD_DIAMETER := 48.0
var manager: GameManager
var log: BattleLog
var canvas: Control
var tabs: HBoxContainer
var close_button: TextureButton
var scroll: ScrollContainer
var content: Control
var header: HBoxContainer
var header_panel: PanelContainer
var header_margin: MarginContainer
var empty_label: Label
var active_filter := "all"
var filter_buttons: Dictionary = {}
var _rows: Array[Dictionary] = []
var _positions: Array[float] = []
var _heights: Array[float] = []
var _widths: Array[float] = []
var _shown_range := Vector2i(-1, -1)
var _revision := -1
var _portraits: Dictionary = {}

func configure(game: GameManager, records: BattleLog) -> void:
	manager = game
	log = records
	name = "BattleRecordPanel"
	z_index = 60
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.size = DESIGN_SIZE
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	var backing := _image(canvas, load("res://assets/UI-battle-record.webp"))
	backing.size = DESIGN_SIZE
	close_button = TextureButton.new()
	close_button.name = "CloseBattleRecord"
	close_button.texture_normal = load("res://assets/UI-battle-record-close.webp")
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_button.tooltip_text = "关闭战斗记录"
	close_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	var close_scale := CLOSE_GOLD_DIAMETER / CLOSE_GOLD_REGION.size.x
	close_button.size = close_button.texture_normal.get_size() * close_scale
	close_button.position = CLOSE_CENTER - CLOSE_GOLD_REGION.get_center() * close_scale
	var click_mask := BitMap.new()
	click_mask.create_from_image_alpha(close_button.texture_normal.get_image(), .1)
	close_button.texture_click_mask = click_mask
	canvas.add_child(close_button)
	close_button.pressed.connect(hide)
	var margins := MarginContainer.new()
	margins.position = Vector2(36, 140)
	margins.size = DESIGN_SIZE - Vector2(72, 174)
	margins.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)
	tabs = HBoxContainer.new()
	tabs.name = "RecordFilters"
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for filter: Array in FILTERS:
		var button := _button("")
		button.name = "Filter_" + filter[0]
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		var center := CenterContainer.new()
		center.name = "CenteredCaption"
		center.mouse_filter = MOUSE_FILTER_IGNORE
		button.add_child(center)
		center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var caption := HBoxContainer.new()
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		caption.add_theme_constant_override("separation", 12)
		center.add_child(caption)
		var icon := _image(caption, _trimmed("res://assets/UI-battle-record-%s.webp" % filter[0]))
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_vertical = SIZE_SHRINK_CENTER
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label := _label(filter[1])
		label.add_theme_font_size_override("font_size", 20)
		caption.add_child(label)
		button.pressed.connect(select_filter.bind(filter[0]))
		tabs.add_child(button)
		filter_buttons[filter[0]] = button
	var table := VBoxContainer.new()
	table.name = "TableSection"
	table.size_flags_vertical = SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 5)
	column.add_child(table)
	header = HBoxContainer.new()
	header.name = "ColumnHeaders"
	header.custom_minimum_size.y = 36
	header.add_theme_constant_override("separation", 0)
	header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_right", 12)
	table.add_child(header_margin)
	header_panel = PanelContainer.new()
	header_panel.name = "HeaderBackground"
	header_panel.add_theme_stylebox_override("panel", _table_style(0, 0))
	header_margin.add_child(header_panel)
	header_panel.add_child(header)
	header_panel.draw.connect(_draw_column_dividers.bind(header_panel))
	for caption in ["时间", "来源", "技能／事件", "目标", "结果"]:
		var label := _label(caption)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)
	scroll = ScrollContainer.new()
	scroll.name = "RecordScroll"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	table.add_child(scroll)
	_style_scrollbar()
	content = Control.new()
	content.name = "RecordTable"
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.mouse_filter = MOUSE_FILTER_PASS
	scroll.add_child(content)
	empty_label = _label("暂无此类记录")
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.size = Vector2(margins.size.x, 64)
	content.add_child(empty_label)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float): _render_visible())
	scroll.resized.connect(_measure.call_deferred)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	_layout()
	hide()

func present() -> void:
	show()
	select_filter("all")
	close_button.grab_focus()

func select_filter(id: String) -> void:
	active_filter = id
	for key: String in filter_buttons: filter_buttons[key].set_pressed_no_signal(key == id)
	_rows = log.filtered(id)
	_revision = log.revision
	scroll.scroll_vertical = 0
	_measure()

func refresh_records() -> void:
	if visible and _revision != log.revision:
		_rows = log.filtered(active_filter)
		_revision = log.revision
		_measure()

func _layout() -> void:
	if canvas == null: return
	var factor := minf(1.0, minf((size.x - 32) / DESIGN_SIZE.x, (size.y - 32) / DESIGN_SIZE.y))
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - DESIGN_SIZE * factor) * 0.5

func _measure() -> void:
	if scroll == null or scroll.size.x < 100: return
	var width := scroll.size.x - scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var time_width := 86.0
	for row: Dictionary in _rows: time_width = maxf(time_width, FONT.get_string_size(format_time(row.at_usec), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 12)
	_widths = [time_width, 180.0, 214.0, 124.0, width - time_width - 534.0]
	for index in header.get_child_count():
		header.get_child(index).custom_minimum_size.x = _widths[index]
	header_margin.add_theme_constant_override("margin_right", ceili(scroll.get_v_scroll_bar().get_combined_minimum_size().x))
	header_panel.queue_redraw()
	_positions.clear()
	_heights.clear()
	var top := 0.0
	for row: Dictionary in _rows:
		var item := manager.registry.get_item(row.item_id)
		var art_size := _event_art_size(item)
		var result_height := FONT.get_multiline_string_size(log.result_text(row), HORIZONTAL_ALIGNMENT_LEFT, _widths[4] - 12, FONT_SIZE).y
		var event_height := FONT.get_multiline_string_size(row.event_name, HORIZONTAL_ALIGNMENT_LEFT, _widths[2] - art_size.x - 18, FONT_SIZE).y
		var source_height := FONT.get_multiline_string_size(row.source_name, HORIZONTAL_ALIGNMENT_LEFT, _widths[1] - 44, FONT_SIZE).y
		var target_height := FONT.get_multiline_string_size(row.target_name, HORIZONTAL_ALIGNMENT_LEFT, _widths[3] - 12, FONT_SIZE).y
		var minimum_height := 76.0 if item != null and item.category == "spell" and item.grid_size == Vector2i(1, 2) else 38.0
		var height := maxf(minimum_height, maxf(maxf(result_height, event_height), maxf(source_height, target_height)) + 8)
		_positions.append(top)
		_heights.append(height)
		top += height
	content.custom_minimum_size.y = maxf(top, 64)
	empty_label.visible = _rows.is_empty()
	empty_label.size.x = width
	_shown_range = Vector2i(-1, -1)
	_render_visible()

func _render_visible() -> void:
	if _widths.is_empty(): return
	var first := _positions.bsearch(float(scroll.scroll_vertical))
	first = maxi(0, first - 1)
	var last := mini(_rows.size(), _positions.bsearch(float(scroll.scroll_vertical) + scroll.size.y) + 1)
	var range_now := Vector2i(first, last)
	if range_now == _shown_range: return
	_shown_range = range_now
	for child: Node in content.get_children():
		if child == empty_label: continue
		content.remove_child(child)
		child.queue_free()
	for index in range(first, last): _build_row(index)

func _build_row(index: int) -> void:
	var row := _rows[index]
	var panel := PanelContainer.new()
	panel.name = "RecordRow_%d" % index
	panel.position.y = _positions[index]
	panel.size = Vector2(scroll.size.x - scroll.get_v_scroll_bar().get_combined_minimum_size().x, _heights[index])
	panel.mouse_filter = MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _table_style(index))
	panel.draw.connect(_draw_column_dividers.bind(panel))
	content.add_child(panel)
	var cells := HBoxContainer.new()
	cells.name = "Cells"
	cells.add_theme_constant_override("separation", 0)
	panel.add_child(cells)
	var time := _label(format_time(row.at_usec))
	time.name = "Time"
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell(cells, time, 0)
	var source := HBoxContainer.new()
	source.name = "Source"
	source.alignment = BoxContainer.ALIGNMENT_BEGIN
	source.add_theme_constant_override("separation", 6)
	_cell(cells, source, 1)
	if log.actors.has(row.source_id): source.add_child(_portrait(log.actors[row.source_id]))
	var source_name := _label(row.source_name)
	source_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_name.custom_minimum_size.x = minf(_widths[1] - 44, FONT.get_string_size(row.source_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	source.add_child(source_name)
	var event := HBoxContainer.new()
	event.name = "Event"
	event.alignment = BoxContainer.ALIGNMENT_BEGIN
	event.add_theme_constant_override("separation", 6)
	_cell(cells, event, 2)
	var item := manager.registry.get_item(row.item_id)
	if item != null:
		if item.category == "spell":
			var art := MapItemArtwork.new()
			art.name = "SpellArtwork"
			art.configure(MapItemArtwork.battle_record(manager, item))
			art.custom_minimum_size = _event_art_size(item)
			art.size_flags_vertical = SIZE_SHRINK_CENTER
			event.add_child(art)
		else:
			MapItemThumbnail.create(event, MapItemArtwork.battle_record(manager, item), 30, -1, 0.85)
	var event_name := _label(row.event_name)
	event_name.custom_minimum_size.x = minf(_widths[2] - (_event_art_size(item).x + 18 if item != null else 12), FONT.get_string_size(row.event_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	event_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event.add_child(event_name)
	var target := _label("自身" if not row.source_id.is_empty() and row.source_id == row.target_id else row.target_name)
	target.name = "Target"
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cell(cells, target, 3)
	var result := RichTextLabel.new()
	result.name = "Result"
	result.bbcode_enabled = true
	result.fit_content = true
	result.size_flags_vertical = SIZE_SHRINK_CENTER
	result.scroll_active = false
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("normal_font", FONT)
	result.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	result.mouse_filter = MOUSE_FILTER_PASS
	result.tooltip_text = log.details_text(row)
	var parts: PackedStringArray = []
	for part: Dictionary in log.segments(row):
		var joiner := "" if parts.is_empty() or str(part.text).begins_with("（") or str(part.text).begins_with("〔") else "，"
		parts.append(joiner + "[color=#%s]%s[/color]" % [part.color, str(part.text).replace("[", "[lb]")])
	result.text = "".join(parts)
	_cell(cells, result, 4)

func _table_style(index: int, vertical_margin: float = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182f38", 0.68) if index % 2 == 0 else Color("0b222c", 0.58)
	style.border_color = Color("5c737c", 0.22)
	style.border_width_bottom = 1
	style.set_content_margin_all(8)
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style

func _draw_column_dividers(panel: Control) -> void:
	if _widths.size() < 5: return
	var edge := 8.0
	for column in 4:
		edge += _widths[column]
		panel.draw_line(Vector2(edge - 4, 0), Vector2(edge - 4, panel.size.y), Color("5c737c", .16))

static func format_time(at_usec: int) -> String:
	return "%.1f秒" % (at_usec / 1000000.0)

func _event_art_size(item: ItemData) -> Vector2:
	if item == null: return Vector2.ZERO
	return Vector2(item.grid_size) * 30.0 if item.category == "spell" else Vector2(30, 30)

func _cell(parent: HBoxContainer, cell: Control, index: int) -> void:
	var slot := MarginContainer.new()
	slot.name = cell.name + "Cell"
	slot.custom_minimum_size.x = _widths[index]
	slot.add_theme_constant_override("margin_right", 12)
	slot.mouse_filter = MOUSE_FILTER_PASS
	if not cell is HBoxContainer: cell.custom_minimum_size.x = _widths[index] - 12
	cell.size_flags_horizontal = SIZE_FILL
	cell.size_flags_vertical = SIZE_SHRINK_CENTER
	cell.mouse_filter = MOUSE_FILTER_PASS
	parent.add_child(slot)
	slot.add_child(cell)

func _portrait(actor: Dictionary) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(30, 30)
	slot.size_flags_vertical = SIZE_SHRINK_CENTER
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	var frame := _image(slot, load("res://assets/mapdot3.webp"))
	frame.size = Vector2(30, 30)
	var key: String = actor.rank if actor.player else actor.portrait
	if not _portraits.has(key):
		var portrait := AtlasTexture.new()
		if actor.player:
			portrait.atlas = PLAYER_PORTRAITS.portrait_for(actor.rank).atlas
			portrait.region = FACE_CROP
		else:
			portrait.atlas = load(actor.portrait)
			portrait.region = MapItemArtwork.TextureMetrics.inspect(portrait.atlas).visible_rect
		_portraits[key] = portrait
	var face := _image(slot, _portraits[key])
	face.position = Vector2(4.5, 4.5)
	face.size = Vector2(21, 21)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/ui/portrait_mask.gdshader")
	mask.set_shader_parameter("portrait_size", face.size)
	face.material = mask
	return slot

func _label(caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(BattleLog.COLORS.normal))
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var selected: bool = state in ["pressed", "hover_pressed"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("20504f") if selected else Color("0d232c", 0.9)
		style.border_color = Color("edce7a") if selected else Color("73857d")
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state, style)
	return button

func _image(parent: Node, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _trimmed(path: String) -> AtlasTexture:
	var texture: Texture2D = load(path)
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = MapItemArtwork.TextureMetrics.inspect(texture).visible_rect
	return cropped

func _style_scrollbar() -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 12
	for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142e36") if state == "scroll" else Color("d6c38c")
		style.set_corner_radius_all(5)
		style.content_margin_left = 5
		style.content_margin_right = 5
		bar.add_theme_stylebox_override(state, style)

func _visibility_changed() -> void:
	if visible: refresh_records()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE: hide()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: hide()
		get_viewport().set_input_as_handled()
