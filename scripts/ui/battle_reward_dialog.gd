extends MapRewardDialog

signal review_requested

var review_button: TextureButton
var scroll: ScrollContainer
var grid: GridContainer
var empty_label: Label

func _init() -> void:
	super()
	name = "BattleRewardDialog"
	z_index = 44
	(get_child(0) as ColorRect).color = Color(0, 0, 0, 0.5)
	accept_button.position.x = 300
	accept_button.get_node("AcceptCaption").text = "确定"
	review_button = TextureButton.new()
	review_button.name = "ReviewBattle"
	review_button.texture_normal = load("res://assets/button-quxiao.webp")
	review_button.ignore_texture_size = true
	review_button.stretch_mode = TextureButton.STRETCH_SCALE
	review_button.size = ACTION_SIZE
	review_button.position = Vector2(80, accept_button.position.y)
	review_button.focus_mode = FOCUS_NONE
	review_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	canvas.add_child(review_button)
	var caption := _label("复盘", Rect2(Vector2.ZERO, ACTION_SIZE), 26, Color.WHITE, review_button)
	caption.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	review_button.pressed.connect(func(): review_requested.emit())
	scroll = ScrollContainer.new()
	scroll.name = "LootScroll"
	scroll.position = Vector2(66, 163)
	scroll.size = Vector2(408, 244)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)
	var center := CenterContainer.new()
	center.name = "LootCenter"
	margin.add_child(center)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 28)
	center.add_child(grid)
	empty_label = _label("本次未获得物品", Rect2(66, 210, 408, 90), 24, Color("f9f8c8"))
	error_label.position = Vector2(50, 388)
	error_label.add_theme_font_size_override("font_size", 13)

func present_loot(records: Array[Dictionary], categories: Dictionary, error: String = "") -> void:
	grid.columns = clampi(records.size(), 1, 3)
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for record in records:
		var item_card := MapInventoryItemCard.new()
		item_card.configure(record, categories.get(record.category, record.category))
		item_card.set_card_width(120)
		item_card.tooltip_text = ""
		item_card.mouse_filter = MOUSE_FILTER_IGNORE
		grid.add_child(item_card)
	empty_label.visible = records.is_empty()
	empty_label.text = "物品结算未完成" if not error.is_empty() else "本次未获得物品"
	error_label.text = error
	scroll.scroll_vertical = 0
	set_busy(false)
	show()
	_layout()

func set_busy(busy: bool) -> void:
	accept_button.disabled = busy
	review_button.disabled = busy
