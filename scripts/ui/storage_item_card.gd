class_name StorageItemCard
extends PanelContainer

var manager: GameManager
var storage_id: String
var item: ItemData

func configure(game: GameManager, entry: Dictionary) -> void:
	manager = game
	storage_id = entry["instance_id"]
	item = manager.registry.get_item(entry["item_id"])
	custom_minimum_size = Vector2(238, 245)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := StyleBoxFlat.new()
	box.bg_color = Color("172629")
	box.border_color = Color("586b61")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	add_theme_stylebox_override("panel", box)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = item.display_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("efd49a"))
	title.add_theme_font_size_override("font_size", 21)
	heading.add_child(title)
	var quantity := Label.new()
	quantity.text = "×%d" % entry["units"].size()
	quantity.add_theme_color_override("font_color", Color("b7cfbe"))
	heading.add_child(quantity)
	var icon := TextureRect.new()
	icon.texture = load(item.icon_path) if not item.icon_path.is_empty() else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size.y = 128
	layout.add_child(icon)
	var tags := Label.new()
	tags.text = "%s  ·  %s  ·  %d×%d格" % [StoragePanel.CATEGORIES[item.category], item.quality, item.grid_size.x, item.grid_size.y]
	tags.add_theme_font_size_override("font_size", 14)
	tags.add_theme_color_override("font_color", Color("a3bcb0"))
	layout.add_child(tags)
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 14)
	if item.is_consumable():
		var effect: Dictionary = item.effects[0]
		detail.text = "每瓶%d次 · %d秒回复%d%s" % [item.uses_per_unit, effect["duration"], effect["value"], {"hp": "气血", "spirit": "灵力", "stamina": "体力"}[effect["resource"]]]
	elif item.type == "weapon":
		detail.text = "轮转%s秒 · 伤害%d · 体力−%d" % [str(item.cooldown_usec / 1_000_000.0), item.effects[0]["value"], item.stamina_cost]
	else:
		detail.text = "防具 · 效果待设定"
	layout.add_child(detail)
	if item.is_consumable() and entry["units"][0]["uses_left"] < item.uses_per_unit:
		detail.text = "已开瓶 · 剩余%d次" % entry["units"][0]["uses_left"]
	_ignore(layout)
	tooltip_text = "右键：放入当前阵盘\n拖动：选择阵盘格位"

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
	preview.texture = load(item.icon_path)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(90, 110)
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return data
