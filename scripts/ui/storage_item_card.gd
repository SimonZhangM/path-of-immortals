class_name StorageItemCard
extends PanelContainer

var manager: GameManager
var storage_id: String
var item: ItemData
var _entry: Dictionary

func configure(game: GameManager, entry: Dictionary) -> void:
	manager = game
	storage_id = entry["instance_id"]
	_entry = entry.duplicate(true)
	item = manager.registry.get_item(entry["item_id"])
	custom_minimum_size = Vector2(180, 215)
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
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	var art := Control.new()
	art.custom_minimum_size.y = 142
	layout.add_child(art)
	var title := Label.new()
	title.text = "\n".join(item.display_name.split(""))
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("9dc9f0"))
	art.add_child(title)
	var icon := TextureRect.new()
	icon.texture = load(item.icon_path) if not item.icon_path.is_empty() else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1
	icon.anchor_bottom = 1
	icon.offset_left = 25
	icon.offset_right = -6
	icon.offset_top = 15
	icon.offset_bottom = -8
	art.add_child(icon)
	var quantity := Label.new()
	quantity.text = "×%d" % entry["units"].size()
	quantity.anchor_top = 1
	quantity.anchor_bottom = 1
	quantity.offset_top = -26
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
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_theme_constant_override("separation", 7)
	layout.add_child(tags)
	tags.add_child(ItemTooltip.chip(StoragePanel.CATEGORIES[item.category]))
	tags.add_child(ItemTooltip.chip(item.quality, Color("c6acdf")))
	_ignore(layout)
	tooltip_text = item.id

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
