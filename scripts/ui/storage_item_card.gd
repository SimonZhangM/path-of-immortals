class_name StorageItemCard
extends PanelContainer

var manager: GameManager
var storage_id: String
var item: ItemData
var _entry: Dictionary
var icon: TextureRect
var quantity: Label
var _art: Control
var _tags: HBoxContainer
var _native_drag_active: bool = false

func configure(game: GameManager, entry: Dictionary) -> void:
	manager = game
	storage_id = entry["instance_id"]
	_entry = entry.duplicate(true)
	item = manager.registry.get_item(entry["item_id"])
	custom_minimum_size = Vector2(144, 186)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := StyleBoxFlat.new()
	box.bg_color = Color("16232b")
	box.border_color = Color("45596b")
	box.set_border_width_all(1)
	box.set_corner_radius_all(15)
	for edge in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + edge, 10)
	add_theme_stylebox_override("panel", box)
	var highlighted := box.duplicate() as StyleBoxFlat
	highlighted.border_color = Color("e3bd70")
	mouse_entered.connect(func(): add_theme_stylebox_override("panel", highlighted))
	mouse_exited.connect(func(): add_theme_stylebox_override("panel", box))
	var layout := Control.new()
	add_child(layout)
	var art := layout
	_art = art
	var title := Label.new()
	title.text = "\n".join(item.display_name.split(""))
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("9dc9f0"))
	art.add_child(title)
	icon = TextureRect.new()
	if not item.icon_path.is_empty():
		var source: Texture2D = load(item.icon_path)
		var cropped := AtlasTexture.new()
		cropped.atlas = source
		cropped.region = source.get_image().get_used_rect()
		icon.texture = cropped
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.add_child(icon)
	quantity = Label.new()
	quantity.text = "×%d" % entry["units"].size()
	quantity.add_theme_font_size_override("font_size", 16)
	quantity.add_theme_color_override("font_color", Color("efd59c"))
	art.add_child(quantity)
	var shape := ItemFootprint.new()
	shape.dimensions = item.grid_size
	shape.anchor_left = 1
	shape.anchor_right = 1
	shape.offset_left = -26
	shape.offset_bottom = 26
	art.add_child(shape)
	var tags := HBoxContainer.new()
	_tags = tags
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_theme_constant_override("separation", 7)
	layout.add_child(tags)
	tags.add_child(ItemTooltip.chip(StoragePanel.CATEGORIES[item.category]))
	tags.add_child(ItemTooltip.chip(item.quality, Color("c6acdf")))
	_ignore(layout)
	art.resized.connect(_layout_art)
	_layout_art.call_deferred()
	tooltip_text = item.id

func _layout_art() -> void:
	if icon.texture == null:
		return
	var available := Vector2(maxf(1, _art.size.x - 34), maxf(1, _art.size.y - 58))
	var source := icon.texture.get_size()
	icon.size = source * minf(available.x / source.x, available.y / source.y)
	icon.position = (_art.size - icon.size) * 0.5
	quantity.size = quantity.get_combined_minimum_size()
	quantity.position = icon.position + icon.size - Vector2(-3, quantity.size.y)
	quantity.position.x = minf(quantity.position.x, _art.size.x - quantity.size.x)
	_tags.size = _tags.get_combined_minimum_size()
	_tags.position = Vector2((_art.size.x - _tags.size.x) * 0.5, _art.size.y - _tags.size.y)

func _make_custom_tooltip(_for_text: String) -> Object:
	var panel := ItemTooltip.new()
	panel.configure(item, _entry)
	return panel

func _ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore(child)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not drag_data().is_empty():
		manager.inventory_interaction.emit("pick")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		manager.equip_random(storage_id)
		accept_event()

func drag_data() -> Dictionary:
	if not manager.can_edit_inventory() or manager.storage.get_entry(storage_id).is_empty():
		return {}
	return {"kind": "storage", "storage_id": storage_id, "epoch": manager.interaction_epoch}

func _get_drag_data(_point: Vector2) -> Variant:
	var data := drag_data()
	if data.is_empty():
		return null
	_native_drag_active = true
	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.texture = load(item.icon_path)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(90, 110)
	preview.position = -preview.size * 0.5
	preview.modulate.a = 0.8
	var holder := Control.new()
	holder.name = "CenteredItemDragPreview"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	set_drag_preview(holder)
	return data

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _native_drag_active:
		_native_drag_active = false
		if not get_viewport().gui_is_drag_successful():
			manager.inventory_interaction.emit("invalid")
