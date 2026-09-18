class_name MapInventoryItemCard
extends Control

const DESIGN_WIDTH := 190.0
const CARD_SCALE := 0.98
var entry: Dictionary
var frame: Texture2D
var canvas: Control
var footprint_cells: Array[Rect2] = []
var loadout: MapLoadoutState
var target_board: MapLoadoutBoard
var _drag_active := false

func bind_loadout(model: MapLoadoutState, board: MapLoadoutBoard) -> void:
	loadout = model
	target_board = board
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if loadout == null or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		loadout.equip_random(entry.get("storage_id", ""))
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_begin_drag.call_deferred(loadout.drag_data("storage", entry.get("storage_id", "")))
		accept_event()

func _begin_drag(data: Dictionary) -> void:
	if not is_visible_in_tree() or not loadout.valid_drag(data) or get_viewport().gui_is_dragging():
		return
	_drag_active = true
	loadout.interaction.emit("pick")
	force_drag(data, target_board.make_preview(data))
	modulate.a = 0.4

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_active:
		_drag_active = false
		modulate.a = 1.0
		if not get_viewport().gui_is_drag_successful():
			loadout.interaction.emit("invalid")

func configure(record: Dictionary, category_name: String) -> void:
	entry = record.duplicate(true)
	name = "Item_" + String(entry.id).get_file()
	frame = load(entry.card_frame)
	custom_minimum_size = Vector2(DESIGN_WIDTH, DESIGN_WIDTH * frame.get_height() / frame.get_width())
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	var art := MapItemArtwork.new()
	art.name = "ItemArtwork"
	art.position = Vector2(42, 44)
	art.size = Vector2(106, 99)
	art.configure(entry, true)
	canvas.add_child(art)
	var title := _label(entry.name, Rect2(16, 151, 158, 28), 20, Color("eee1bd"))
	title.name = "ItemName"
	var song := SystemFont.new()
	song.font_names = PackedStringArray(["SimSun", "宋体", "Noto Serif SC", "serif"])
	song.font_weight = 700
	var bold_song := FontVariation.new()
	bold_song.base_font = song
	bold_song.variation_embolden = 0.5
	title.add_theme_font_override("font", bold_song)
	var tags := HBoxContainer.new()
	tags.name = "CategoryTags"
	tags.add_theme_constant_override("separation", 7)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.position = Vector2(15, 181)
	tags.size = Vector2(160, 26)
	canvas.add_child(tags)
	var categories: Array[String] = [category_name]
	var subcategory: String = entry.get("subcategory", "")
	if not subcategory.is_empty():
		categories.append(subcategory)
	if entry.category == "weapon" and entry.has("damage_type"):
		categories.append(entry.damage_type)
	if entry.has("armor_type"):
		categories.append(entry.armor_type)
	for caption: String in categories:
		if caption.is_empty():
			continue
		var tag := Label.new()
		tag.text = caption
		tag.mouse_filter = MOUSE_FILTER_IGNORE
		tag.add_theme_font_size_override("font_size", 15)
		tag.add_theme_color_override("font_color", Color("c5d0d6"))
		var border := StyleBoxFlat.new()
		border.bg_color = Color("12212ac0")
		border.border_color = Color("61727a")
		border.set_border_width_all(1)
		border.set_corner_radius_all(4)
		border.content_margin_left = 7
		border.content_margin_right = 7
		border.content_margin_top = 2
		border.content_margin_bottom = 2
		tag.add_theme_stylebox_override("normal", border)
		tags.add_child(tag)
	_label("×%d" % entry.quantity, Rect2(137, 211, 30, 20), 15, Color("b1bec4"))
	var rows: int = entry.get("footprint_rows", 1)
	var columns: int = entry.get("footprint_columns", 1)
	for row in rows:
		for column in columns:
			footprint_cells.append(Rect2(168 - columns * 13 + column * 13, 24 + row * 13, 10, 10))
	tooltip_text = "%s\n品质：%s\n类别：%s\n占格：%d列 × %d行" % [entry.name, entry.quality, " · ".join(categories), columns, rows]
	tooltip_text += "\n强化等级：%d级" % entry.get("enhancement_level", 0)
	if entry.has("damage_type"):
		tooltip_text += "\n伤害类型：%s\n基础伤害：%d\n轮转CD：%.1f秒\n基础耗体：%d" % [entry.damage_type, entry.base_damage, entry.cooldown, entry.base_stamina_cost]
	if entry.category == "armor":
		tooltip_text += "\n轮转CD：%.1f秒\n每轮获得%d护甲\n护甲上限 +%d" % [entry.cooldown, entry.armor_gain, entry.armor_capacity]
		if entry.has("armor_type"):
			tooltip_text += "\n甲型：" + String(entry.armor_type)
	resized.connect(_layout)
	_layout()

func _label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	canvas.add_child(label)
	return label

func set_card_width(width: float) -> void:
	custom_minimum_size = Vector2(width, width * CARD_SCALE * frame.get_height() / frame.get_width())

func artwork_rect() -> Rect2:
	var width := size.x * CARD_SCALE
	return Rect2(Vector2((size.x - width) * 0.5, 0), Vector2(width, width * frame.get_height() / frame.get_width()))

func _layout() -> void:
	if canvas != null:
		canvas.position = artwork_rect().position
		canvas.scale = Vector2.ONE * artwork_rect().size.x / DESIGN_WIDTH
	queue_redraw()

func _draw() -> void:
	if frame == null:
		return
	var artwork := artwork_rect()
	draw_texture_rect(frame, artwork, false)
	var factor := artwork.size.x / DESIGN_WIDTH
	for cell in footprint_cells:
		var rect := Rect2(artwork.position + cell.position * factor, cell.size * factor)
		draw_rect(rect, Color("becde0"))
		draw_rect(rect, Color("45576b"), false, 1.0, true)
