class_name MapInventoryScreen
extends Control

signal close_requested

const GOLD := Color("dec995")
const MUTED := Color("85989f")
var catalog: MapInventoryCatalog
var loadout: MapLoadoutState
var loadout_board: MapLoadoutBoard
var config: Dictionary
var stage: Control
var background_art: TextureRect
var body: HBoxContainer
var sidebar: PanelContainer
var sidebar_art: TextureRect
var sidebar_border: Panel
var faction_slot: Control
var bag_caption: Label
var board_panel: PanelContainer
var formation_panel: PanelContainer
var storage_panel: PanelContainer
var board_art: TextureRect
var return_button: Button
var search: LineEdit
var quality_picker: OptionButton
var order_picker: Button
var level_sort: Button
var storage_toolbar: VBoxContainer
var result_count: Label
var empty_state: VBoxContainer
var empty_title: Label
var empty_caption: Label
var grid: GridContainer
var _collections: Dictionary = {}
var _categories: Dictionary = {}
var _quality_values: Array[String] = []

func configure(model: MapInventoryCatalog, ui_config: Dictionary, board: BoardLayout, equipment: MapLoadoutState = null) -> void:
	catalog = model
	loadout = equipment
	config = ui_config
	name = "MapInventoryScreen"
	z_index = 25
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = _theme()
	var backing := ColorRect.new()
	backing.color = Color("08121c")
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art = TextureRect.new()
	background_art.name = "InventoryBackground"
	background_art.texture = load("res://assets/inv-background.webp")
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.self_modulate.a = 0.5
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_art)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	stage.add_child(body)
	_build_sidebar(board)
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = 780
	middle.add_theme_constant_override("separation", 18)
	body.add_child(middle)
	_build_board(middle, board)
	_build_formations(middle)
	_build_storage()
	catalog.changed.connect(_refresh)
	resized.connect(_layout)
	_refresh()
	_layout()
	if loadout != null:
		loadout.changed.connect(func(): catalog.replace_entries(loadout.storage_records()))
		var sounds := {}
		for kind in ["pick", "place", "invalid"]:
			var player := AudioStreamPlayer.new()
			player.stream = GameAudio.STREAMS[kind]
			player.volume_db = -4
			add_child(player)
			sounds[kind] = player
		loadout.interaction.connect(func(kind: String): sounds[kind].play())

func _theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Serif SC", "Microsoft YaHei", "SimSun", "serif"])
	result.default_font = font
	result.default_font_size = 20
	result.set_color("font_color", "Label", Color("d4dbd8"))
	for type_name in ["Button", "OptionButton", "LineEdit"]:
		result.set_stylebox("normal", type_name, _box(Color("10222d"), Color("334c58"), 7, 12))
		result.set_stylebox("hover", type_name, _box(Color("1b3641"), Color("759795"), 7, 12))
		result.set_stylebox("pressed", type_name, _box(Color("25434b"), Color("b6ad79"), 7, 12))
		result.set_stylebox("focus", type_name, _box(Color(0, 0, 0, 0), Color("ac996a"), 7, 0))
		result.set_stylebox("disabled", type_name, _box(Color("101e27"), Color("35424a"), 7, 12))
		result.set_color("font_color", type_name, Color("b5c7cb"))
		result.set_color("font_hover_color", type_name, Color("f2e4b9"))
		result.set_color("font_pressed_color", type_name, Color("f2e4b9"))
		result.set_color("font_disabled_color", type_name, Color("958d77"))
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_stylebox("panel", "PopupMenu", _box(Color("12232e"), Color("796f55"), 8, 12))
	result.set_stylebox("hover", "PopupMenu", _box(Color("25434b"), Color("25434b"), 4, 5))
	result.set_color("font_color", "PopupMenu", Color("e6dfc9"))
	return result

func _box(color: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _panel(parent: Node, node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _box(Color("0d1c26"), Color("60716d"), 18, 22))
	parent.add_child(panel)
	return panel

func _column(parent: Node, gap: int = 16) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column

func _label(parent: Node, caption: String, font_size: int = 20, color: Color = Color("d4dbd8")) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _heading(parent: Node, caption: String) -> Label:
	var label := _label(parent, caption, 32, GOLD)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	label.add_theme_font_override("font", font)
	return label

func _rule(parent: Node) -> void:
	var rule := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("344c53")
	style.thickness = 1
	rule.add_theme_stylebox_override("separator", style)
	parent.add_child(rule)

func _button(parent: Node, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _storage_theme() -> Theme:
	var result := _theme()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	result.default_font = font
	result.default_font_size = 15
	for type_name in ["Button", "OptionButton", "LineEdit"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var color := Color("142532")
			if state == "hover":
				color = Color("213c49")
			elif state in ["pressed", "hover_pressed"]:
				color = Color("24525c")
			elif state == "disabled":
				color = Color("111e28")
			elif state == "focus":
				color = Color(0, 0, 0, 0)
			var style := _box(color, Color.TRANSPARENT, 5, 0)
			style.set_border_width_all(0)
			style.content_margin_left = 10
			style.content_margin_right = 10
			style.content_margin_top = 3
			style.content_margin_bottom = 3
			if type_name == "LineEdit":
				style.set_corner_radius_all(16)
				style.content_margin_left = 14
			result.set_stylebox(state, type_name, style)
	result.set_constant("arrow_margin", "OptionButton", 6)
	result.set_font_size("font_size", "PopupMenu", 15)
	return result

func _compact_button(parent: Node, caption: String, height: float = 28) -> Button:
	var button := _button(parent, caption)
	button.custom_minimum_size.y = height
	return button

func _build_sidebar(board: BoardLayout) -> void:
	sidebar = _panel(body, "InformationPanel")
	sidebar.add_theme_stylebox_override("panel", _box(Color("0d1c26"), Color.TRANSPARENT, 18, 22))
	sidebar.custom_minimum_size.x = 208
	sidebar.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	# A non-Control holder keeps the background out of PanelContainer layout.
	var art_layer := Node2D.new()
	art_layer.name = "SidebarBackground"
	sidebar.add_child(art_layer)
	sidebar_art = TextureRect.new()
	sidebar_art.texture = load("res://assets/inventory-sidepic.webp")
	sidebar_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sidebar_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sidebar_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_layer.add_child(sidebar_art)
	sidebar.resized.connect(_layout_sidebar_art)
	var column := _column(sidebar, 18)
	var image_button := BattleActionButton.new()
	image_button.configure("res://assets/button-return.webp", Vector2(0, 56))
	return_button = image_button
	column.add_child(return_button)
	return_button.name = "ReturnToMap"
	return_button.pressed.connect(func(): close_requested.emit())
	var gap := Control.new()
	gap.custom_minimum_size.y = 90
	column.add_child(gap)
	faction_slot = Control.new()
	faction_slot.name = "FactionReserved"
	faction_slot.custom_minimum_size.y = 40
	column.add_child(faction_slot)
	var faction := _heading(faction_slot, config.faction_caption)
	faction.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bag_caption = _label(column, board.display_name + "\n" + String(config.bag_caption), 24, GOLD)
	bag_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var song := SystemFont.new()
	song.font_names = PackedStringArray(["FangSong", "仿宋", "STFangsong", "serif"])
	var bold_song := FontVariation.new()
	bold_song.base_font = song
	bold_song.variation_embolden = 0.6
	bag_caption.add_theme_font_override("font", bold_song)
	var motto_group := _column(column, 6)
	_rule(motto_group)
	var motto := _label(motto_group, config.motto, 17, GOLD)
	var kai := SystemFont.new()
	kai.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	motto.add_theme_font_override("font", kai)
	var reserved := Control.new()
	reserved.name = "BagPropertiesReserved"
	reserved.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(reserved)
	# Draw the rim above the illustration so the image cannot cover its gold edge.
	var rim_layer := Node2D.new()
	sidebar.add_child(rim_layer)
	sidebar_border = Panel.new()
	sidebar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim := _box(Color.TRANSPARENT, Color("c9ac7059"), 18, 0)
	rim.draw_center = false
	sidebar_border.add_theme_stylebox_override("panel", rim)
	rim_layer.add_child(sidebar_border)
	_layout_sidebar_art()

func _layout_sidebar_art() -> void:
	if sidebar_art == null or sidebar_art.texture == null:
		return
	var dimensions := sidebar_art.texture.get_size()
	sidebar_art.size = dimensions * (sidebar.size.x / dimensions.x)
	sidebar_art.position = Vector2(0, sidebar.size.y - sidebar_art.size.y)
	if sidebar_border != null:
		sidebar_border.position = Vector2.ONE
		sidebar_border.size = sidebar.size - Vector2.ONE * 2

func _build_board(parent: Node, board: BoardLayout) -> void:
	board_panel = _panel(parent, "BoardPanel")
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := _column(board_panel, 10)
	var row := HBoxContainer.new()
	column.add_child(row)
	_heading(row, "行囊").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var capacity := _label(row, "%d × %d" % [board.grid_size.y, board.grid_size.x], 21, MUTED)
	capacity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rule(column)
	board_art = TextureRect.new()
	if loadout != null:
		board_art.free()
		loadout_board = MapLoadoutBoard.new()
		loadout_board.configure(loadout)
		board_art = loadout_board
	board_art.name = "BoardArtwork"
	board_art.texture = load(board.texture_path)
	board_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_art.mouse_filter = Control.MOUSE_FILTER_STOP if loadout != null else Control.MOUSE_FILTER_IGNORE
	column.add_child(board_art)

func _build_formations(parent: Node) -> void:
	formation_panel = _panel(parent, "FormationPanel")
	formation_panel.custom_minimum_size.y = 174
	var column := _column(formation_panel, 18)
	_heading(column, "阵型配置")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	for caption: String in config.formation_placeholders + ["＋ 新增阵型"]:
		var button := _button(row, caption)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = true

func _build_storage() -> void:
	storage_panel = _panel(body, "StoragePanel")
	storage_panel.theme = _storage_theme()
	storage_panel.add_theme_stylebox_override("panel", _box(Color("0a1822"), Color("40565d"), 14, 14))
	storage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := _column(storage_panel, 8)
	storage_toolbar = _column(column, 6)
	storage_toolbar.name = "StorageToolbar"
	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 36
	heading.add_theme_constant_override("separation", 10)
	storage_toolbar.add_child(heading)
	var accent := ColorRect.new()
	accent.color = GOLD
	accent.custom_minimum_size = Vector2(3, 23)
	accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(accent)
	var title := _heading(heading, "储物袋")
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search = LineEdit.new()
	search.name = "ItemSearch"
	search.placeholder_text = "搜索物品名称…"
	search.custom_minimum_size = Vector2(250, 30)
	search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search.add_theme_font_size_override("font_size", 14)
	search.clear_button_enabled = true
	heading.add_child(search)
	search.text_changed.connect(func(value: String): catalog.set_filter("search", value))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	storage_toolbar.add_child(tabs)
	for key: String in catalog.collection_names:
		var button := _compact_button(tabs, catalog.collection_names[key], 30)
		button.toggle_mode = true
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var color := Color(0, 0, 0, 0)
			if state == "hover":
				color = Color("1a2d36")
			elif state in ["pressed", "hover_pressed"]:
				color = Color("39413a")
			var style := _box(color, Color.TRANSPARENT, 15, 0)
			style.set_border_width_all(0)
			style.content_margin_left = 14
			style.content_margin_right = 14
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_pressed_color", GOLD)
		button.add_theme_color_override("font_hover_pressed_color", GOLD)
		button.pressed.connect(func(): catalog.set_filter("collection", key))
		_collections[key] = button
	_rule(storage_toolbar)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 5)
	filters.add_theme_constant_override("v_separation", 5)
	storage_toolbar.add_child(filters)
	for key: String in catalog.category_names:
		var button := _compact_button(filters, catalog.category_names[key])
		button.add_theme_font_size_override("font_size", 14)
		button.toggle_mode = true
		button.pressed.connect(func(): catalog.set_filter("category", key))
		_categories[key] = button
	_rule(storage_toolbar)
	var sorting := HBoxContainer.new()
	sorting.add_theme_constant_override("separation", 8)
	storage_toolbar.add_child(sorting)
	quality_picker = OptionButton.new()
	quality_picker.name = "QualityFilter"
	quality_picker.custom_minimum_size = Vector2(104, 30)
	quality_picker.focus_mode = Control.FOCUS_NONE
	sorting.add_child(quality_picker)
	quality_picker.item_selected.connect(func(index: int): catalog.set_filter("quality", "" if index == 0 else _quality_values[index - 1]))
	level_sort = _compact_button(sorting, "等级 ↕", 30)
	level_sort.name = "EnhancementOrder"
	level_sort.custom_minimum_size.x = 104
	level_sort.toggle_mode = true
	level_sort.pressed.connect(func(): catalog.set_level_descending(not catalog.level_descending if catalog.sort_key == "enhancement_level" else catalog.level_descending))
	order_picker = _compact_button(sorting, "获得时间 ↓", 30)
	order_picker.name = "AcquiredOrder"
	order_picker.custom_minimum_size.x = 128
	order_picker.toggle_mode = true
	order_picker.pressed.connect(func(): catalog.set_newest_first(not catalog.newest_first if catalog.sort_key == "acquired_at" else catalog.newest_first))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sorting.add_child(space)
	var reset := _compact_button(sorting, "重置筛选", 30)
	reset.add_theme_font_size_override("font_size", 14)
	reset.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	reset.pressed.connect(catalog.reset_filters)
	var well := PanelContainer.new()
	var well_style := _box(Color("09151e"), Color.TRANSPARENT, 8, 10)
	well_style.set_border_width_all(0)
	well.add_theme_stylebox_override("panel", well_style)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(well)
	var content_stack := Control.new()
	well.add_child(content_stack)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_stack.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	grid.resized.connect(_size_item_cards)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_stack.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty_state = _column(center, 14)
	empty_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_title = _label(empty_state, "储物袋空空如也", 20, Color("b4b39c"))
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_caption = _label(empty_state, "获得的物品会显示在这里", 14, MUTED)
	empty_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_count = _label(column, "", 13, MUTED)
	result_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _refresh() -> void:
	for key in _collections:
		_collections[key].text = "%s %d" % [catalog.collection_names[key], catalog.collection_count(key)]
		_collections[key].set_pressed_no_signal(catalog.collection == key)
	for key in _categories:
		_categories[key].set_pressed_no_signal(catalog.category == key)
	if search.text != catalog.search_text:
		search.text = catalog.search_text
	_quality_values = catalog.qualities()
	quality_picker.clear()
	quality_picker.add_item("品质")
	for value in _quality_values:
		quality_picker.add_item(value)
	quality_picker.select(0 if catalog.quality.is_empty() else _quality_values.find(catalog.quality) + 1)
	level_sort.set_pressed_no_signal(catalog.sort_key == "enhancement_level")
	level_sort.text = "等级 " + (("↓" if catalog.level_descending else "↑") if catalog.sort_key == "enhancement_level" else "↕")
	level_sort.tooltip_text = "按强化等级排序；再次点击切换升降序"
	order_picker.set_pressed_no_signal(catalog.sort_key == "acquired_at")
	order_picker.text = "获得时间 " + (("↓" if catalog.newest_first else "↑") if catalog.sort_key == "acquired_at" else "↕")
	order_picker.tooltip_text = "按获得时间排序；↓ 新到旧，↑ 旧到新"
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var entries := catalog.visible_entries()
	for entry in entries:
		_add_item_card(entry)
	_size_item_cards()
	empty_state.visible = entries.is_empty()
	empty_title.text = "储物袋空空如也" if catalog.total_count() == 0 else "没有符合条件的物品"
	empty_caption.text = "获得的物品会显示在这里" if catalog.total_count() == 0 else "试试其他分类，或重置筛选"
	result_count.text = "显示 %d / %d 项" % [entries.size(), catalog.total_count()]
	_enable_storage_drop(storage_panel)

func _enable_storage_drop(node: Node) -> void:
	if loadout == null:
		return
	if node is Control:
		node.set_drag_forwarding(Callable(), func(_point: Vector2, data: Variant): return loadout.valid_drag(data) and data.source == "board", func(_point: Vector2, data: Variant): loadout.take_back(data))
	for child in node.get_children():
		_enable_storage_drop(child)

func _add_item_card(entry: Dictionary) -> void:
	if not String(entry.get("card_frame", "")).is_empty():
		var framed := MapInventoryItemCard.new()
		framed.configure(entry, catalog.category_names[entry.category])
		if loadout != null:
			framed.bind_loadout(loadout, loadout_board)
		grid.add_child(framed)
		return
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("162c37"), Color("3c5862"), 9, 10))
	card.custom_minimum_size = Vector2(160, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(card)
	var column := _column(card, 8)
	var art := TextureRect.new()
	art.custom_minimum_size.y = 108
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = entry.get("icon", "")
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		art.texture = load(path)
	column.add_child(art)
	var title := _label(column, entry.name, 19, GOLD)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label(column, "%s · %s  ×%d" % [catalog.category_names[entry.category], entry.quality, entry.quantity], 14, MUTED)

func _size_item_cards() -> void:
	if grid == null or grid.size.x <= 0:
		return
	var width := floorf((grid.size.x - 12.0 * (grid.columns - 1)) / grid.columns)
	for card in grid.get_children():
		if card is MapInventoryItemCard:
			card.set_card_width(width)

func _layout() -> void:
	if stage == null or size.x <= 0:
		return
	# Keep every inventory component on one fixed design canvas. The map Head
	# retains its own width-based scaling; fit and center the canvas below it.
	var base_head := MapStatusHeader.height_for_width(1920.0)
	var head_height := MapStatusHeader.height_for_width(size.x)
	background_art.position = Vector2(0, head_height)
	background_art.size = Vector2(size.x, maxf(0, size.y - head_height))
	var factor := minf(size.x / 1920.0, (size.y - head_height) / (1080.0 - base_head))
	stage.scale = Vector2.ONE * factor
	stage.size = Vector2(1920, 1080)
	stage.position = Vector2((size.x - 1920.0 * factor) * 0.5, head_height - base_head * factor + (size.y - head_height - (1080.0 - base_head) * factor) * 0.5)
	body.position = Vector2(24, 146)
	body.size = Vector2(1872, 910)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()

func _can_drop_data(point: Vector2, data: Variant) -> bool:
	return loadout != null and loadout.valid_drag(data) and data.source == "board" and storage_panel.get_global_rect().has_point(get_global_transform() * point)

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		loadout.take_back(data)

func cancel_item_drag() -> void:
	if get_viewport().gui_is_dragging() and loadout != null and loadout.valid_drag(get_viewport().gui_get_drag_data()):
		get_viewport().gui_cancel_drag()
