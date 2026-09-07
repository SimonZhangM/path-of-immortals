class_name StoragePanel
extends PanelContainer

const CATEGORIES := {"all": "全部", "weapon": "法器", "armor": "防具", "pill": "丹药", "item": "道具", "talisman": "符箓"}
var manager: GameManager
var cards: Dictionary = {}
var category: String = "all"
var _grid: GridContainer
var _target: Label
var _hint: Label
var _filters: Dictionary = {}
var _dirty: bool = true

func configure(game: GameManager) -> void:
	manager = game
	var box := StyleBoxFlat.new()
	box.bg_color = Color("101b21", 0.98)
	box.border_color = Color("9c8b61")
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	for edge in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + edge, 22)
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "储物袋"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("efd49a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Button.new()
	close.text = "关闭 ×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): manager.set_adjustment(false))
	heading.add_child(close)
	_target = Label.new()
	_target.add_theme_font_size_override("font_size", 18)
	column.add_child(_target)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 9)
	column.add_child(tabs)
	for key in CATEGORIES:
		var button := Button.new()
		button.text = CATEGORIES[key]
		button.custom_minimum_size = Vector2(94, 40)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(set_category.bind(key))
		tabs.add_child(button)
		_filters[key] = button
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_hint = Label.new()
	_hint.text = "右键放入所选阵盘 · 拖动选择格位\n右键收回1件 · 拖回收回未开瓶 · 已开瓶不可收回"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color("a3bcb0"))
	column.add_child(_hint)
	manager.inventory_changed.connect(func(): _dirty = true)
	manager.selection_changed.connect(_refresh_target)
	manager.feedback.connect(func(message: String): _hint.text = message)
	manager.adjustment_changed.connect(func(): visible = manager.adjustment_open; _dirty = true)
	# Children pass unhandled drop queries to this storage surface.
	_refresh_target()
	visible = manager.adjustment_open

func set_category(value: String) -> void:
	category = value
	_dirty = true

func _refresh_target() -> void:
	_target.text = "当前阵盘：%s" % manager.party[manager.selected_member_index].definition["name"]

func _process(_delta: float) -> void:
	if _dirty and visible:
		_dirty = false
		rebuild()

func rebuild() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	cards.clear()
	for key in _filters:
		_filters[key].set_pressed_no_signal(key == category)
	for entry in manager.storage.entries():
		var item := manager.registry.get_item(entry["item_id"])
		if category != "all" and item.category != category:
			continue
		var card := StorageItemCard.new()
		_grid.add_child(card)
		card.configure(manager, entry)
		cards[entry["instance_id"]] = card
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "此分类暂无物品"
		_grid.add_child(empty)

func _can_drop_data(_point: Vector2, data: Variant) -> bool:
	if not manager.can_edit_inventory() or not data is Dictionary or data.get("kind") != "inventory" or data.get("epoch") != manager.interaction_epoch:
		return false
	var index: int = data.get("member_index", -1)
	return manager.can_unequip(index, data.get("instance_id", ""))

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		manager.unequip(data["member_index"], data["instance_id"])
