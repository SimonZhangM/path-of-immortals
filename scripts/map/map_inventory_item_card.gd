class_name MapInventoryItemCard
extends Control

signal selection_changed

const DESIGN_WIDTH := 190.0
# Card height divided by width.
const CARD_ASPECT := 4.0 / 3.0
const NAME_STRIP_HEIGHT := 37.0
const STORAGE_ASPECT := (DESIGN_WIDTH + NAME_STRIP_HEIGHT) / DESIGN_WIDTH
const BACKGROUND_INTERIOR := Rect2(48, 48, 416, 672)
const BORDER_WIDTH := 2.0
const CORNER_RADIUS := 10.0
const TextureMetrics = preload("res://scripts/map/map_texture_metrics.gd")
const QUALITY_BADGE_DESIGN_WIDTH := 42.0
const ORIGINAL_ART_SIZE := Vector2(106, 99)
const ORIGINAL_ART_SCALE := 543.0 / 490.0
var entry: Dictionary
var frame: Texture2D
var background: TextureRect
var canvas: Control
var quality_badge: TextureRect
var footprint_cells: Array[Rect2] = []
var loadout: MapLoadoutState
var target_board: MapLoadoutBoard
var equipment_actions_enabled := true
var _drag_active := false
var identified := true
var quantity_picker: SpinBox
var square_layout := false
var selected := false
var _left_armed := false
var _drag_requested := false
var _press_position := Vector2.ZERO
var _selection_overlay: Control
var transfer_drag_provider: Callable
var transfer_request: Callable

func configure_transfer(provider: Callable, request: Callable) -> void:
	transfer_drag_provider = provider
	transfer_request = request
	if quantity_picker != null: quantity_picker.visible = not provider.is_valid()

func _ready() -> void:
	ItemTooltipHost.bind(self, func(_point: Vector2): return entry.get("id", ""), build_item_tooltip)

func _get_tooltip(_point: Vector2) -> String:
	return ""

func set_selected(value: bool) -> void:
	selected = value
	if background != null: background.material.set_shader_parameter("selected", value)
	if is_instance_valid(_selection_overlay): _selection_overlay.visible = value
	selection_changed.emit()

func _storage_drag_data() -> Dictionary:
	if transfer_drag_provider.is_valid(): return transfer_drag_provider.call(entry.id)
	if entry.category == "book": return {}
	return loadout.drag_data("storage", entry.get("storage_id", ""), selected_quantity()) if loadout != null and equipment_actions_enabled else {}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_left_armed = false
		_drag_requested = false

func _handle_selection_input(event: InputEvent) -> bool:
	if not square_layout: return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			ItemTooltipHost.for_control(self).select_card(self)
			_press_position = get_global_transform_with_canvas() * event.position
			_left_armed = true
		else: _left_armed = false
		accept_event()
		return true
	if event is InputEventMouseMotion and _left_armed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if (get_global_transform_with_canvas() * event.position).distance_to(_press_position) >= 6.0:
			_left_armed = false
			var data := _storage_drag_data()
			if not data.is_empty():
				_drag_requested = true
				_start_selection_drag.call_deferred(data)
		accept_event()
		return true
	return false

func _start_selection_drag(data: Dictionary) -> void:
	# A release arriving before the deferred call must not leave a stuck drag.
	if not _drag_requested: return
	_drag_requested = false
	_begin_drag(data)

func bind_loadout(model: MapLoadoutState, board: MapLoadoutBoard) -> void:
	loadout = model
	target_board = board
	set_identified(loadout.can_use_item(entry.id))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if _handle_selection_input(event): return
	if transfer_request.is_valid() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		transfer_request.call(entry.id)
		accept_event()
		return
	if loadout == null or not equipment_actions_enabled or not event is InputEventMouseButton or not event.pressed:
		return
	if entry.category == "book": return
	# Let wheel events reach the enclosing storage ScrollContainer.
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if entry.category == "board":
		if event.button_index == MOUSE_BUTTON_RIGHT:
			target_board.request_board_change(loadout.drag_data("storage", entry.get("storage_id", "")))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_begin_drag.call_deferred(loadout.drag_data("storage", entry.get("storage_id", "")))
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		loadout.equip_random(entry.get("storage_id", ""), selected_quantity())
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_begin_drag.call_deferred(loadout.drag_data("storage", entry.get("storage_id", ""), selected_quantity()))
		accept_event()

func build_item_tooltip(_for_text: String) -> Object:
	if loadout == null:
		return null
	var tooltip := ItemTooltip.new()
	tooltip.configure(loadout.registry.get_item(entry.id), CultivationDescription.tooltip_context(loadout.knowledge, entry.id, loadout.registry.get_item(entry.id)), -1, 0, loadout.can_use_item(entry.id))
	return tooltip

func _begin_drag(data: Dictionary) -> void:
	if data.get("kind") == "warehouse_transfer":
		if not transfer_drag_provider.is_valid() or not is_visible_in_tree() or get_viewport().gui_is_dragging(): return
		var preview := MapItemArtwork.new()
		preview.configure(entry,true)
		preview.size = Vector2(110,110)
		preview.mouse_filter = MOUSE_FILTER_IGNORE
		_drag_active = true
		ItemTooltipHost.for_control(self).dismiss()
		loadout.interaction.emit("pick")
		force_drag(data,preview)
		modulate.a = 0.4
		return
	if entry.category == "book" or not equipment_actions_enabled or not is_visible_in_tree() or not loadout.valid_drag(data) or not loadout.can_use_item(entry.id) or get_viewport().gui_is_dragging():
		return
	_drag_active = true
	ItemTooltipHost.for_control(self).dismiss()
	loadout.interaction.emit("pick")
	force_drag(data, target_board.make_preview(data))
	modulate.a = 0.4

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_active:
		_drag_active = false
		modulate.a = 1.0
		if not get_viewport().gui_is_drag_successful():
			loadout.interaction.emit("invalid")

func configure(record: Dictionary, category_name: String, square: bool = false) -> void:
	square_layout = square
	entry = record.duplicate(true)
	name = "Item_" + String(entry.id).get_file()
	var frame_path := str(entry.get("card_frame", "")) if entry.category == "book" else MapItemQuality.background_path(entry.quality)
	frame = load(frame_path) if not frame_path.is_empty() else null
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(DESIGN_WIDTH, DESIGN_WIDTH * (STORAGE_ASPECT if square_layout else CARD_ASPECT))
	# The quality badge intentionally straddles the lower border.
	clip_contents = false
	background = TextureRect.new()
	background.name = "QualityBackground"
	background.texture = frame
	if frame == null:
		# Unlearned books use the tooltip's solid fill, with no rarity artwork.
		var fill := GradientTexture2D.new()
		fill.width = 2
		fill.height = 2
		fill.gradient = Gradient.new()
		fill.gradient.colors = PackedColorArray([ItemTooltip.SUMMARY_BACKGROUND, ItemTooltip.SUMMARY_BACKGROUND])
		background.texture = fill
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_item_card_background.gdshader")
	paint.set_shader_parameter("corner_radius", CORNER_RADIUS)
	paint.set_shader_parameter("line_width", BORDER_WIDTH)
	paint.set_shader_parameter("line_color", Color.from_string(entry.get("card_border_color", ""), MapItemQuality.color(entry.quality)))
	paint.set_shader_parameter("selection_color", Color.from_string(entry.get("card_border_color", ""), MapItemQuality.color(entry.quality)).lightened(0.35))
	background.material = paint
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	if square_layout:
		_build_square_contents()
		_finish_contents()
		return
	var art := MapItemArtwork.new()
	art.name = "ItemArtwork"
	art.position = Vector2(42, 44)
	art.size = ORIGINAL_ART_SIZE
	art.configure(entry, true)
	canvas.add_child(art)
	art.apply_inventory_pose(entry)
	var title := _label(entry.name, Rect2(16, 151, 158, 28), 20, Color("f9f8c8"))
	title.name = "ItemName"
	var tags := HBoxContainer.new()
	tags.name = "CategoryTags"
	tags.z_index = 1
	tags.add_theme_constant_override("separation", 7)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.position = Vector2(15, 185)
	tags.size = Vector2(160, 26)
	canvas.add_child(tags)
	var categories: Array[String] = [category_name]
	if entry.category == "mineral": categories = ["矿石"]
	if entry.category == "board": categories = [entry.get("board_level", "")]
	var subcategory: String = entry.get("subcategory", "")
	if entry.category == "armor" and subcategory.begins_with("护具·"):
		subcategory = ItemTooltip.classification_caption(subcategory)
	if not subcategory.is_empty():
		categories.append(subcategory)
	if entry.category == "weapon" and entry.has("damage_type"):
		categories.append(entry.damage_type)
	if entry.category == "book": categories.assign(entry.get("tags", []))
	if entry.has("armor_type"):
		categories.append(entry.armor_type)
	var seen_tags := {}
	for caption: String in categories:
		if caption.is_empty() or seen_tags.has(caption):
			continue
		seen_tags[caption] = true
		var tag := Label.new()
		tag.text = caption
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
		# Preserve the tag height while centering the visible CJK strokes.
		border.content_margin_top = 1
		border.content_margin_bottom = 3
		tag.add_theme_stylebox_override("normal", border)
		tags.add_child(tag)
	if int(entry.quantity) > 1:
		var quantity_label := _label("×%d" % entry.quantity, Rect2(137, 207, 30, 20), 15, Color("b1bec4"))
		quantity_label.name = "Quantity"
	var quality_level := MapItemQuality.level(entry.quality)
	if quality_level > 0:
		quality_badge = TextureRect.new()
		quality_badge.name = "QualityBadge"
		var badge_texture := AtlasTexture.new()
		badge_texture.atlas = load("res://assets/levelbq-%d.webp" % quality_level)
		# Each badge has its own transparent margins; never clip its decoration
		# using another grade's (or an older source image's) fixed crop.
		badge_texture.region = TextureMetrics.inspect(badge_texture.atlas).used_rect
		quality_badge.texture = badge_texture
		quality_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quality_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		quality_badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		quality_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quality_badge.z_index = 2
		add_child(quality_badge)
	_finish_contents()

func _build_square_contents() -> void:
	var art := MapItemArtwork.new()
	art.name = "ItemArtwork"
	# Retain the pre-square card's on-screen artwork size. Its foreground used
	# a 543/490 reference scale; only the available image area is now square.
	art.size = ORIGINAL_ART_SIZE * ORIGINAL_ART_SCALE
	art.position = (Vector2.ONE * DESIGN_WIDTH - art.size) * 0.5
	art.configure(entry, true)
	canvas.add_child(art)
	art.apply_inventory_pose(entry)
	art.center_visible_at(Vector2(95, 95))
	var name_shade := Panel.new()
	name_shade.name = "NameShade"
	name_shade.position = Vector2(2, 188)
	name_shade.size = Vector2(186, 37)
	name_shade.mouse_filter = MOUSE_FILTER_IGNORE
	name_shade.z_index = 1
	var shade_style := StyleBoxFlat.new()
	shade_style.bg_color = Color(0, 0, 0, 0.42)
	shade_style.corner_radius_bottom_left = 8
	shade_style.corner_radius_bottom_right = 8
	name_shade.add_theme_stylebox_override("panel", shade_style)
	canvas.add_child(name_shade)
	var title := _label(entry.name, Rect2(7, 189, 176, 34), 22, Color.WHITE)
	title.name = "ItemName"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if int(entry.quantity) > 1:
		var number := str(int(entry.quantity))
		var label := _label(number, Rect2(0, 0, 0, 29), 21, Color.WHITE)
		label.name = "Quantity"
		var number_width := maxf(28.0, label.get_theme_font("font").get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 12.0)
		label.position = Vector2(183 - number_width, 156)
		label.size = Vector2(number_width, 29)
		var shade := StyleBoxFlat.new()
		shade.bg_color = Color(0, 0, 0, 0.42)
		shade.set_corner_radius_all(6)
		label.add_theme_stylebox_override("normal", shade)

func _finish_contents() -> void:
	if square_layout:
		_selection_overlay = Control.new()
		_selection_overlay.name = "SelectionOutline"
		_selection_overlay.mouse_filter = MOUSE_FILTER_IGNORE
		_selection_overlay.z_index = 4
		add_child(_selection_overlay)
		_selection_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_selection_overlay.draw.connect(_draw_selection)
		_selection_overlay.resized.connect(_selection_overlay.queue_redraw)
		_selection_overlay.hide()
	var rows: int = entry.get("footprint_rows", 1)
	var columns: int = entry.get("footprint_columns", 1)
	for row in rows:
		for column in columns:
			footprint_cells.append(Rect2(168 - columns * 13 + column * 13, 24 + row * 13, 10, 10))
	set_identified(entry.get("identified", true))
	if entry.category in ["pill", "throwable"] and int(entry.quantity) > 1:
		quantity_picker = SpinBox.new()
		quantity_picker.name = "DeployQuantity"
		quantity_picker.min_value = 1
		quantity_picker.max_value = mini(10, int(entry.quantity))
		quantity_picker.value = 1
		quantity_picker.prefix = "上阵"
		quantity_picker.position = Vector2(7, 7) if square_layout else Vector2(25, 214)
		quantity_picker.size = Vector2(108, 28) if square_layout else Vector2(135, 30)
		if square_layout:
			quantity_picker.z_index = 2
			quantity_picker.add_theme_font_size_override("font_size", 14)
		canvas.add_child(quantity_picker)
	resized.connect(_layout)
	_layout()

func selected_quantity() -> int:
	return int(quantity_picker.value) if quantity_picker != null else 1

func set_identified(value: bool) -> void:
	identified = value
	canvas.get_node("ItemName").text = entry.name if identified else "？"
	tooltip_text = ""
	var tags := canvas.get_node_or_null("CategoryTags")
	if tags == null: return
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
	# Keep all card text explicitly above the artwork's glow and outline layers.
	label.z_index = 1
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	canvas.add_child(label)
	return label

func set_card_width(width: float) -> void:
	custom_minimum_size = Vector2(width, width * (STORAGE_ASPECT if square_layout else CARD_ASPECT))

func artwork_rect() -> Rect2:
	if square_layout: return Rect2(Vector2.ZERO, Vector2.ONE * size.x)
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
		var art := canvas.get_node_or_null("ItemArtwork") as MapItemArtwork
		if art != null and canvas.scale.x > 0:
			art.center_visible_horizontally((size.x * 0.5 - canvas.position.x) / canvas.scale.x)
	if background != null and size.x > 0 and size.y > 0:
		var region := background_region()
		background.material.set_shader_parameter("panel_size", size)
		background.material.set_shader_parameter("source_region", Vector4(region.position.x / frame.get_width(), region.position.y / frame.get_height(), region.size.x / frame.get_width(), region.size.y / frame.get_height()) if frame != null else Vector4(0, 0, 1, 1))
	if quality_badge != null and size.x > 0:
		var badge_width := size.x * QUALITY_BADGE_DESIGN_WIDTH / DESIGN_WIDTH
		var badge_height := badge_width * quality_badge.texture.get_height() / quality_badge.texture.get_width()
		quality_badge.size = Vector2(badge_width, badge_height)
		quality_badge.position = Vector2((size.x - badge_width) * 0.5, size.y - badge_height * 0.5)
	queue_redraw()

func _draw() -> void:
	if frame == null or entry.get("category", "") in ["plant", "beast", "mineral", "exotic", "material", "board", "food", "book"]:
		return
	var artwork := artwork_rect()
	var factor := artwork.size.x / DESIGN_WIDTH
	for cell in footprint_cells:
		var rect := Rect2(artwork.position + cell.position * factor, cell.size * factor)
		draw_rect(rect, Color("becde0"))
		draw_rect(rect, Color("45576b"), false, 1.0, true)

func _draw_selection() -> void:
	# The shader highlights the existing border, with identical coverage and
	# width. Corner marks follow that same rounded path, not an inset frame.
	var tint := Color.from_string(entry.get("card_border_color", ""), MapItemQuality.color(entry.quality)).lightened(0.65)
	var inset := BORDER_WIDTH * 0.5
	var radius := CORNER_RADIUS - inset
	var centers := [Vector2(CORNER_RADIUS,CORNER_RADIUS),Vector2(size.x-CORNER_RADIUS,CORNER_RADIUS),size-Vector2.ONE*CORNER_RADIUS,Vector2(CORNER_RADIUS,size.y-CORNER_RADIUS)]
	for index in 4:
		var angle := PI + index * PI * 0.5
		_selection_overlay.draw_arc(centers[index],radius,angle,angle+PI*0.5,16,tint,BORDER_WIDTH,true)
		var start: Vector2 = centers[index] + Vector2.from_angle(angle) * radius
		var end: Vector2 = centers[index] + Vector2.from_angle(angle+PI*0.5) * radius
		_selection_overlay.draw_line(start,start-Vector2.from_angle(angle+PI*0.5)*7,tint,BORDER_WIDTH,true)
		_selection_overlay.draw_line(end,end+Vector2.from_angle(angle+PI)*7,tint,BORDER_WIDTH,true)
