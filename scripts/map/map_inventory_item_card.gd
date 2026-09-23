class_name MapInventoryItemCard
extends Control

const DESIGN_WIDTH := 190.0
# Card height divided by width.
const CARD_ASPECT := 4.0 / 3.0
const BACKGROUND_INTERIOR := Rect2(48, 48, 416, 672)
const BORDER_WIDTH := 2.0
const CORNER_RADIUS := 10.0
const QUALITY_BADGE_PATHS := {"下品": "res://assets/levelbq-1.webp"}
const QUALITY_BADGE_REGION := Rect2(14, 7, 327, 384)
const QUALITY_BADGE_DESIGN_WIDTH := 42.0
var entry: Dictionary
var frame: Texture2D
var background: TextureRect
var canvas: Control
var quality_badge: TextureRect
var footprint_cells: Array[Rect2] = []
var loadout: MapLoadoutState
var target_board: MapLoadoutBoard
var _drag_active := false
var identified := true

func bind_loadout(model: MapLoadoutState, board: MapLoadoutBoard) -> void:
	loadout = model
	target_board = board
	set_identified(loadout.can_use_item(entry.id))
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

func _make_custom_tooltip(_for_text: String) -> Object:
	if loadout == null:
		return null
	var tooltip := ItemTooltip.new()
	tooltip.configure(loadout.registry.get_item(entry.id), {}, -1, 0, loadout.can_use_item(entry.id))
	return tooltip

func _begin_drag(data: Dictionary) -> void:
	if not is_visible_in_tree() or not loadout.valid_drag(data) or not loadout.can_use_item(entry.id) or get_viewport().gui_is_dragging():
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
	frame = load(MapItemQuality.background_path(entry.quality))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(DESIGN_WIDTH, DESIGN_WIDTH * CARD_ASPECT)
	# The quality badge intentionally straddles the lower border.
	clip_contents = false
	background = TextureRect.new()
	background.name = "QualityBackground"
	background.texture = frame
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_item_card_background.gdshader")
	paint.set_shader_parameter("corner_radius", CORNER_RADIUS)
	paint.set_shader_parameter("line_width", BORDER_WIDTH)
	paint.set_shader_parameter("line_color", MapItemQuality.color(entry.quality))
	background.material = paint
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	var art := MapItemArtwork.new()
	art.name = "ItemArtwork"
	art.position = Vector2(42, 44)
	art.size = Vector2(106, 99)
	art.configure(entry, true)
	canvas.add_child(art)
	var title := _label(entry.name, Rect2(16, 151, 158, 28), 20, Color("ffd700"))
	title.name = "ItemName"
	var tags := HBoxContainer.new()
	tags.name = "CategoryTags"
	tags.add_theme_constant_override("separation", 7)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.position = Vector2(15, 185)
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
		tag.set_meta("identified_text", caption)
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
	if int(entry.quantity) > 1:
		var quantity_label := _label("×%d" % entry.quantity, Rect2(137, 207, 30, 20), 15, Color("b1bec4"))
		quantity_label.name = "Quantity"
	if QUALITY_BADGE_PATHS.has(entry.quality):
		quality_badge = TextureRect.new()
		quality_badge.name = "QualityBadge"
		var badge_texture := AtlasTexture.new()
		badge_texture.atlas = load(QUALITY_BADGE_PATHS[entry.quality])
		badge_texture.region = QUALITY_BADGE_REGION
		quality_badge.texture = badge_texture
		quality_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quality_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		quality_badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		quality_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quality_badge.z_index = 2
		add_child(quality_badge)
	var rows: int = entry.get("footprint_rows", 1)
	var columns: int = entry.get("footprint_columns", 1)
	for row in rows:
		for column in columns:
			footprint_cells.append(Rect2(168 - columns * 13 + column * 13, 24 + row * 13, 10, 10))
	tooltip_text = entry.name
	set_identified(entry.get("identified", true))
	resized.connect(_layout)
	_layout()

func set_identified(value: bool) -> void:
	identified = value
	canvas.get_node("ItemName").text = entry.name if identified else "？"
	tooltip_text = entry.name if identified else "？"
	var tags := canvas.get_node("CategoryTags")
	for index in tags.get_child_count():
		var tag := tags.get_child(index) as Label
		tag.text = tag.get_meta("identified_text") if identified else "？"
		tag.visible = identified or index == 0

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
	custom_minimum_size = Vector2(width, width * CARD_ASPECT)

func artwork_rect() -> Rect2:
	# Foreground reference only; the background fills the actual card bounds.
	var factor := size.x / 490.0
	return Rect2(Vector2(-27, 0) * factor, Vector2(543, 740) * factor)

func background_region() -> Rect2:
	# Aspect-cover within the safe interior; never sample the source's rim.
	var region := BACKGROUND_INTERIOR
	var ratio := size.x / maxf(size.y, 1.0)
	if region.size.x / region.size.y < ratio:
		var height := region.size.x / maxf(ratio, 0.001)
		region.position.y += (region.size.y - height) * 0.5
		region.size.y = height
	else:
		var width := region.size.y * ratio
		region.position.x += (region.size.x - width) * 0.5
		region.size.x = width
	return region

func _layout() -> void:
	if canvas != null:
		canvas.position = artwork_rect().position
		canvas.scale = Vector2.ONE * artwork_rect().size.x / DESIGN_WIDTH
	if background != null and size.x > 0 and size.y > 0:
		var region := background_region()
		background.material.set_shader_parameter("panel_size", size)
		background.material.set_shader_parameter("source_region", Vector4(region.position.x / frame.get_width(), region.position.y / frame.get_height(), region.size.x / frame.get_width(), region.size.y / frame.get_height()))
	if quality_badge != null and size.x > 0:
		var badge_width := size.x * QUALITY_BADGE_DESIGN_WIDTH / DESIGN_WIDTH
		var badge_height := badge_width * QUALITY_BADGE_REGION.size.y / QUALITY_BADGE_REGION.size.x
		quality_badge.size = Vector2(badge_width, badge_height)
		quality_badge.position = Vector2((size.x - badge_width) * 0.5, size.y - badge_height * 0.5)
	queue_redraw()

func _draw() -> void:
	if frame == null:
		return
	var artwork := artwork_rect()
	var factor := artwork.size.x / DESIGN_WIDTH
	for cell in footprint_cells:
		var rect := Rect2(artwork.position + cell.position * factor, cell.size * factor)
		draw_rect(rect, Color("becde0"))
		draw_rect(rect, Color("45576b"), false, 1.0, true)
