class_name MapInventoryScreen
extends Control

signal close_requested

const GOLD := Color("dec995")
const MUTED := Color("85989f")
const SECTION_TITLE_COLOR := Color("f9f8c8")
const BODY_HEIGHT := 910.0
const BODY_WIDTH := 1874.0
const BODY_SIDE_MARGIN := 23.0
const BODY_COLUMN_GAP := 19
const FORMATION_HEIGHT := 174.0
const FORMATION_CARD_SIZE := Vector2(92, 138)
const FORMATION_ICON_SIZE := Vector2(78, 78)
const FORMATION_DIALOG_WIDTH := 460.0
const FORMATION_BACKGROUND_REGION := Rect2(40, 99, 2052, 515)
const FORMATION_BACKGROUND_CONTENT_SCALE := 1.01
const FORMATION_BACKGROUND_HORIZONTAL_SCALE := 714.0 / 718.0
const FORMATION_BACKGROUND_LEFT_EXTENSION := 1.0
const STORAGE_BACKGROUND_REGION := Rect2(33, 32, 1192, 1196)
const STORAGE_BACKGROUND_SCALE := 1.0404
const STORAGE_BACKGROUND_X_SHIFT := 2.0
const STORAGE_BACKGROUND_Y_SHIFT := 2.0
const STORAGE_SEARCH_WIDTH := 200.0
const STORAGE_CONTENT_INSET := 22
const STORAGE_TITLE_ICON_X_OFFSET := -42.0 / 300.0 * 26.0
const MIDDLE_GAP := 18.0
const MIDDLE_WIDTH := BODY_HEIGHT - FORMATION_HEIGHT - MIDDLE_GAP
const BOARD_PANEL_RADIUS := 13.0
const BOARD_BACKGROUND_BORDER_INSET := 72.0
const BOARD_BACKGROUND_TOP_REFERENCE_SCALE := 0.9801
const BOARD_BACKGROUND_CONTENT_SCALE := 0.970299
const BOARD_BACKGROUND_LEFT_EXTENSION := 1.0
const BOARD_BACKGROUND_X_SHIFT := -1.0
const BOARD_BACKGROUND_HORIZONTAL_EXTENSION := 5.0
const BOARD_BACKGROUND_BOTTOM_EXTENSION := 5.0
const STORAGE_CARD_GAP := 15
const STORAGE_CARD_ROW_GAP := 6
const STORAGE_CARD_INSET := STORAGE_CONTENT_INSET
const STORAGE_BORDER_COLOR := Color("806d48")
const BOARD_HEALTH_ICON_SCALE := 1.1
const COLLECTION_SELECTED_FILL := Color("313126")
const COLLECTION_SELECTED_BORDER := Color("d6b85f")
const CATEGORY_SELECTED_FILL := Color("163b68")
const CATEGORY_SELECTED_BORDER := Color("78aef0")
var catalog: MapInventoryCatalog
var loadout: MapLoadoutState
var loadout_board: MapLoadoutBoard
var config: Dictionary
var stage: Control
var background_art: TextureRect
var body: HBoxContainer
var sidebar_spacer: Control
var sidebar: PanelContainer
var sidebar_art: TextureRect
var faction_slot: Control
var bag_caption: Label
var board_bonus_values: Dictionary = {}
var cultivation_bonus_value: Label
var buff_bonus_values: Dictionary = {}
const ATTRIBUTE_TEXT_COLOR := Color("fbf4bf")
const AttributeLabel := preload("res://scripts/map/map_attribute_label.gd")
const RESOURCE_MEANINGS := {
	"hp": "角色的生命值，降为0时无法继续战斗。",
	"stamina": "发动部分武器和道具时消耗，体力不足时无法发动。",
	"spirit": "施展法术时消耗的资源。",
}
const BuffBonuses := preload("res://scripts/map/map_buff_bonuses.gd")
var _bonus_board: BoardLayout
var _bonus_player: MapPlayerStatus
var board_panel: PanelContainer
var board_capacity_caption: Label
var board_capacity: Label
var _board_total_cells := 0
var formation_panel: PanelContainer
var formation_scroll: ScrollContainer
var formation_cards: HBoxContainer
var custom_formation_card: Button
var formation_dialog: Control
var formation_icon_buttons: Array[Button] = []
var formation_name_input: LineEdit
var formation_create_button: Button
var formation_cancel_button: Button
var formation_replace_layout: CheckBox
var formation_message: Label
var formation_save_callback: Callable
var _editing_formation_id := ""
var _selected_formation_icon := 0
var storage_panel: PanelContainer
var board_art: TextureRect
var return_button: Button
var search: LineEdit
var quality_picker: OptionButton
var order_picker: Button
var level_sort: Button
var storage_toolbar: VBoxContainer
var empty_state: VBoxContainer
var empty_title: Label
var empty_caption: Label
const InventoryGrid := preload("res://scripts/map/map_inventory_grid.gd")
var grid: InventoryGrid
var _collections: Dictionary = {}
var _categories: Dictionary = {}
var _category_filters: HFlowContainer
var _category_rule: Control
var _quality_values: Array[String] = []

func configure(model: MapInventoryCatalog, ui_config: Dictionary, board: BoardLayout, equipment: MapLoadoutState = null, player_status: MapPlayerStatus = null) -> void:
	catalog = model
	loadout = equipment
	_bonus_board = board
	_bonus_player = player_status
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
	body.add_theme_constant_override("separation", BODY_COLUMN_GAP)
	stage.add_child(body)
	_build_sidebar(board)
	_refresh_buff_bonuses()
	if player_status != null:
		player_status.changed.connect(_refresh_buff_bonuses)
	sidebar_spacer = Control.new()
	sidebar_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.get_parent().add_child(sidebar_spacer)
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = MIDDLE_WIDTH
	middle.add_theme_constant_override("separation", int(MIDDLE_GAP))
	body.add_child(middle)
	_build_board(middle, board)
	_build_formations(middle)
	_build_storage()
	_build_formation_dialog()
	catalog.changed.connect(_refresh)
	resized.connect(_layout)
	_refresh()
	_layout()
	if loadout != null:
		loadout.formations_changed.connect(_refresh_formations)
		loadout.changed.connect(func(): catalog.replace_entries(loadout.storage_records()))
		loadout.changed.connect(_refresh_board_capacity)
		loadout.changed.connect(_refresh_buff_bonuses)
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
	result.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
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

func _checkbox_icon(show_check: bool) -> Texture2D:
	var check_path := ""
	if show_check:
		check_path = "<path d='M4.5 9.5 L8 13 L15 5.5' fill='none' stroke='#17242b' stroke-width='2.4' stroke-linecap='round' stroke-linejoin='round'/>"
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='20' height='20' viewBox='0 0 20 20'><rect x='1.5' y='1.5' width='17' height='17' rx='3' fill='#dce5e6' stroke='#9aabad' stroke-width='1.5'/>%s</svg>" % check_path
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _tab_box(color: Color, border: Color, radius: int, horizontal_padding: int, border_width: int = 1, shadow_color: Color = Color.TRANSPARENT, shadow_size: int = 0) -> StyleBoxFlat:
	var style := _box(color, border, radius, 0)
	style.set_border_width_all(border_width)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	return style

func _style_collection_tab(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _tab_box(Color(0, 0, 0, 0), Color("34485080"), 16, 12, 1))
	button.add_theme_stylebox_override("hover", _tab_box(Color("202b2b"), Color("8f8359"), 16, 12, 1, Color("bfa75c45"), 2))
	var selected := _tab_box(COLLECTION_SELECTED_FILL, COLLECTION_SELECTED_BORDER, 16, 12, 2, Color("e1c36f80"), 5)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected.duplicate())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("aab9bd"))
	button.add_theme_color_override("font_hover_color", Color("f0dfaf"))
	button.add_theme_color_override("font_pressed_color", Color("ffe49a"))
	button.add_theme_color_override("font_hover_pressed_color", Color("fff0bd"))

func _style_category_tab(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _tab_box(Color("0b1923"), Color("29424f"), 6, 9, 1))
	button.add_theme_stylebox_override("hover", _tab_box(Color("142c3d"), Color("507895"), 6, 9, 1, Color("4889be45"), 2))
	var selected := _tab_box(CATEGORY_SELECTED_FILL, CATEGORY_SELECTED_BORDER, 6, 9, 2, Color("4d91ed99"), 5)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected.duplicate())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("aab9bd"))
	button.add_theme_color_override("font_hover_color", Color("e5eef2"))
	button.add_theme_color_override("font_pressed_color", Color("eff8ff"))
	button.add_theme_color_override("font_hover_pressed_color", Color("ffffff"))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color("071521c0"))

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

func _section_heading(parent: Node, caption: String, icon_path: String = "", icon_x_offset: float = 0.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SectionHeading"
	row.custom_minimum_size.y = 36
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	if icon_path.is_empty():
		var accent := ColorRect.new()
		accent.color = Color("fff0bd")
		accent.custom_minimum_size = Vector2(3, 23)
		accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(accent)
	else:
		var icon_parent: Node = row
		var uses_icon_slot := false
		if not is_zero_approx(icon_x_offset):
			var icon_slot := Control.new()
			icon_slot.name = "SectionTitleIconSlot"
			icon_slot.custom_minimum_size = Vector2(26, 26)
			icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon_slot)
			icon_parent = icon_slot
			uses_icon_slot = true
		var icon := TextureRect.new()
		icon.name = "SectionTitleIcon"
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_parent.add_child(icon)
		if uses_icon_slot:
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = icon_x_offset
			icon.offset_right = icon_x_offset
	var title := _heading(row, caption)
	title.name = "SectionTitle"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", SECTION_TITLE_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row

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
	var left_column := HBoxContainer.new()
	left_column.add_theme_constant_override("separation", 0)
	body.add_child(left_column)
	sidebar = _panel(left_column, "InformationPanel")
	sidebar.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, Color.TRANSPARENT, 18, 22))
	sidebar.custom_minimum_size.x = 208
	# A non-Control holder keeps the background out of PanelContainer layout.
	var art_layer := Node2D.new()
	art_layer.name = "SidebarBackground"
	sidebar.add_child(art_layer)
	sidebar_art = TextureRect.new()
	sidebar_art.texture = load("res://assets/inventory-sidepic.webp")
	sidebar_art.self_modulate.a = 0.25
	var sidebar_fade := ShaderMaterial.new()
	sidebar_fade.shader = preload("res://scripts/map/map_inventory_panel_art.gdshader")
	sidebar_art.material = sidebar_fade
	sidebar_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sidebar_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sidebar_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_layer.add_child(sidebar_art)
	sidebar.resized.connect(_layout_sidebar_art)
	var column := _column(sidebar, 18)
	var image_button := BattleActionButton.new()
	image_button.configure("res://assets/button-return.webp", Vector2(0, 56))
	return_button = image_button
	var return_slot := Control.new()
	return_slot.custom_minimum_size.y = 56
	column.add_child(return_slot)
	return_slot.add_child(return_button)
	# A second 20% enlargement: 1.2 * 1.2 = 1.44 of the original width.
	# Grow both axes around the same center to preserve the artwork's aspect.
	return_button.anchor_left = -0.22
	return_button.anchor_right = 1.22
	return_button.anchor_top = -0.1
	return_button.anchor_bottom = 1.1
	# Align its center with the bag heading:22px panel inset +18px half-row.
	return_button.offset_top = -10.0
	return_button.offset_bottom = -10.0
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
	faction.add_theme_color_override("font_color", Color("fff0bd"))
	faction.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Center the whole attribute block in the panel, independently of the return button.
	var attribute_center := CenterContainer.new()
	attribute_center.name = "AttributeContentCenter"
	attribute_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.add_child(attribute_center)
	var attributes := _column(attribute_center, 9)
	attributes.name = "AttributeContentGroup"
	attributes.custom_minimum_size.x = 164
	var bag_heading := _section_heading(attributes, config.bag_caption, "res://assets/title-zpsxjc.webp")
	bag_caption = bag_heading.get_node("SectionTitle") as Label
	var motto_group := _column(attributes, 9)
	motto_group.name = "SidebarMotto"
	var motto := _label(motto_group, config.motto, 17, Color("fff0bd"))
	_rule(motto_group)
	var kai := SystemFont.new()
	kai.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	motto.add_theme_font_override("font", kai)
	var properties := VBoxContainer.new()
	properties.name = "BoardResourceBonuses"
	properties.add_theme_constant_override("separation", 9)
	attributes.add_child(properties)
	var keys := ["hp", "stamina", "spirit"]
	var captions := ["气血", "体力", "灵力"]
	var icons := ["health", "stamina", "spirit"]
	for index in keys.size():
		var source: Texture2D = load("res://assets/player-status-%s.webp" % icons[index])
		var icon_texture: Texture2D = source
		if keys[index] == "hp":
			var health_region_size := source.get_size() / BOARD_HEALTH_ICON_SCALE
			var health_atlas := AtlasTexture.new()
			health_atlas.atlas = source
			health_atlas.region = Rect2((source.get_size() - health_region_size) * 0.5, health_region_size)
			icon_texture = health_atlas
		board_bonus_values[keys[index]] = _attribute_row(properties, keys[index], captions[index], icon_texture, RESOURCE_MEANINGS[keys[index]], "+%d" % board.resource_bonus(keys[index]), kai, true)
	cultivation_bonus_value = _attribute_row(properties, "cultivation", "修为", load("res://assets/player-status-level.webp"), "修炼速度的额外加成，可由阵盘提供。", "+0%", kai, true)
	var buffs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_buffs.json"))
	for buff: Dictionary in buffs:
		if buff.id == "counter":
			_rule(properties)
		buff_bonus_values[buff.id] = _attribute_row(properties, buff.id, buff.name, load("res://assets/buff-%s.webp" % buff.icon), buff.description, "+0", kai)
	_add_panel_border(sidebar, 18.0)
	_layout_sidebar_art()

func _attribute_row(parent: Control, key: String, caption_text: String, texture: Texture2D, meaning: String, amount: String, font: Font, is_resource := false) -> Label:
	var row := HBoxContainer.new()
	row.name = ("ResourceBonus_" if is_resource else "BuffBonus_") + key
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	# Keep the original column widths; move their contents without changing layout.
	var label_slot := Control.new()
	label_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label_slot)
	var label_group := AttributeLabel.new()
	label_group.name = "AttributeLabel_" + key
	label_group.attribute_name = caption_text
	label_group.meaning = meaning
	label_group.tooltip_text = meaning
	label_slot.add_child(label_group)
	label_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_group.offset_left = 5
	label_group.offset_right = 5
	var icon := TextureRect.new()
	icon.name = ("BoardBonusIcon_" if is_resource else "BuffIcon_") + key
	icon.texture = texture
	icon.custom_minimum_size = Vector2(27, 27)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_group.add_child(icon)
	var caption := _label(label_group, caption_text, 22, ATTRIBUTE_TEXT_COLOR)
	caption.name = "AttributeCaption"
	caption.add_theme_font_override("font", font)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_slot := Control.new()
	value_slot.custom_minimum_size.x = 44
	value_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_slot)
	var value := _label(value_slot, amount, 22, ATTRIBUTE_TEXT_COLOR)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value.offset_left = -10
	value.offset_right = -10
	# Original rows resolve to33px with the inherited value font after tree entry.
	row.custom_minimum_size.y = maxf(33, maxf(caption.get_combined_minimum_size().y, value.get_combined_minimum_size().y))
	return value

func _refresh_buff_bonuses() -> void:
	var rank := {}
	var equipped: Array = []
	var board := loadout.board if loadout != null else _bonus_board
	if loadout != null:
		if _bonus_player != null:
			rank = loadout.registry.get_cultivation(_bonus_player.cultivation_rank_id)
		for entry: Dictionary in loadout.inventory.get_instances():
			equipped.append(loadout.records[entry.item_id])
	var totals := BuffBonuses.sum_sources(rank, board.buff_bonuses if board != null else {}, equipped)
	for key in buff_bonus_values:
		buff_bonus_values[key].text = "+" + EffectSystem.number_text(totals[key])

func _layout_sidebar_art() -> void:
	if sidebar_art == null or sidebar_art.texture == null:
		return
	var dimensions := sidebar_art.texture.get_size()
	sidebar_art.size = dimensions * (sidebar.size.x / dimensions.x)
	sidebar_art.position = Vector2(0, sidebar.size.y - sidebar_art.size.y)
	(sidebar_art.material as ShaderMaterial).set_shader_parameter("top_fade_fraction", minf(1.0, 64.0 / maxf(1.0, sidebar_art.size.y)))
	_layout_panel_art(sidebar_art, sidebar, 18.0)

func _layout_panel_art(art: TextureRect, panel: Control, radius: float) -> void:
	var material := art.material as ShaderMaterial
	material.set_shader_parameter("panel_size", panel.size)
	material.set_shader_parameter("art_size", art.size)
	material.set_shader_parameter("art_position", art.position)
	material.set_shader_parameter("corner_radius", radius)
	if art.texture is AtlasTexture:
		var atlas := art.texture as AtlasTexture
		material.set_shader_parameter("uv_origin", atlas.region.position / atlas.atlas.get_size())
		material.set_shader_parameter("uv_size", atlas.region.size / atlas.atlas.get_size())

func _build_board(parent: Node, board: BoardLayout) -> void:
	board_panel = _panel(parent, "BoardPanel")
	var panel_source: Texture2D = load("res://assets/inv-bg-2.webp")
	var inset := Vector2.ONE * BOARD_BACKGROUND_BORDER_INSET
	var base_region_size := panel_source.get_size() - inset * 2.0
	var top_reference_region_size := base_region_size / BOARD_BACKGROUND_TOP_REFERENCE_SCALE
	var scaled_region_size := base_region_size / BOARD_BACKGROUND_CONTENT_SCALE
	var scaled_region_position := Vector2(
		(panel_source.get_size().x - scaled_region_size.x) * 0.5,
		(panel_source.get_size().y - top_reference_region_size.y) * 0.5
	)
	var panel_texture := AtlasTexture.new()
	panel_texture.atlas = panel_source
	# The authored image includes its own gold picture frame. Crop to the inner
	# artwork. Keep the established top sample fixed while enlarging the current
	# background by1%, horizontally centered and without exposing a dark border.
	panel_texture.region = Rect2(scaled_region_position, scaled_region_size)
	var panel_style := _box(Color.TRANSPARENT, Color.TRANSPARENT, int(BOARD_PANEL_RADIUS), 22)
	panel_style.set_border_width_all(0)
	board_panel.add_theme_stylebox_override("panel", panel_style)
	# Keep the backing as a separate layer below the heading and interactive bag.
	var backdrop_layer := Node2D.new()
	backdrop_layer.name = "BoardBackdropLayer"
	board_panel.add_child(backdrop_layer)
	var backdrop := TextureRect.new()
	backdrop.name = "BoardPanelBackground"
	backdrop.texture = panel_texture
	backdrop.self_modulate.a = 0.5
	var backdrop_mask := ShaderMaterial.new()
	backdrop_mask.shader = preload("res://scripts/map/map_inventory_panel_art.gdshader")
	backdrop.material = backdrop_mask
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_layer.add_child(backdrop)
	board_panel.resized.connect(func():
		backdrop.position = Vector2(
			-BOARD_BACKGROUND_LEFT_EXTENSION + BOARD_BACKGROUND_X_SHIFT - BOARD_BACKGROUND_HORIZONTAL_EXTENSION,
			0
		)
		backdrop.size = board_panel.size + Vector2(
			BOARD_BACKGROUND_LEFT_EXTENSION + BOARD_BACKGROUND_HORIZONTAL_EXTENSION * 2.0,
			BOARD_BACKGROUND_BOTTOM_EXTENSION
		)
		_layout_panel_art(backdrop, board_panel, BOARD_PANEL_RADIUS)
	)
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := _column(board_panel, 10)
	var row := _section_heading(column, "阵盘", "res://assets/title-zhenpan.webp")
	var capacity_row := HBoxContainer.new()
	capacity_row.name = "BoardCapacity"
	capacity_row.add_theme_constant_override("separation", 8)
	capacity_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(capacity_row)
	board_capacity_caption = _label(capacity_row, "容量", 16, Color("c5d0d2"))
	board_capacity = _label(capacity_row, "", 17, Color("fff0bd"))
	var numbers := SystemFont.new()
	numbers.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	board_capacity_caption.add_theme_font_override("font", numbers)
	board_capacity.add_theme_font_override("font", numbers)
	_board_total_cells = board.grid_size.x * board.grid_size.y
	_refresh_board_capacity()
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

func _add_panel_border(panel: PanelContainer, radius: float, line_color: Color = MapStatusHeader.LINE_COLOR) -> void:
	var fill := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	fill.set_border_width_all(0)
	fill.corner_detail = 16
	fill.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", fill)
	# Analytic coverage avoids segmented Line2D joins along subpixel-width curves.
	# A Node2D keeps this overlay out of PanelContainer's content layout.
	var rim_layer := Node2D.new()
	rim_layer.z_index = 1
	panel.add_child(rim_layer)
	var rim := ColorRect.new()
	rim.name = str(panel.name) + "Border"
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_panel_border.gdshader")
	paint.set_shader_parameter("corner_radius", radius)
	paint.set_shader_parameter("line_width", MapStatusHeader.LINE_WIDTH)
	paint.set_shader_parameter("line_color", line_color)
	rim.material = paint
	rim_layer.add_child(rim)
	panel.resized.connect(_layout_panel_border.bind(panel, rim))
	_layout_panel_border(panel, rim)

func _layout_panel_border(panel: Control, rim: ColorRect) -> void:
	rim.position = -Vector2.ONE * 2.0
	rim.size = panel.size + Vector2.ONE * 4.0
	(rim.material as ShaderMaterial).set_shader_parameter("panel_size", panel.size)

func _refresh_board_capacity() -> void:
	var occupied := loadout.inventory.occupied_cells() if loadout != null else 0
	board_capacity.text = "%d/%d" % [occupied, _board_total_cells]

func _build_formations(parent: Node) -> void:
	formation_panel = _panel(parent, "FormationPanel")
	formation_panel.custom_minimum_size.y = FORMATION_HEIGHT
	var formation_style := _box(Color.TRANSPARENT, Color.TRANSPARENT, int(BOARD_PANEL_RADIUS), 14)
	formation_style.set_border_width_all(0)
	formation_panel.add_theme_stylebox_override("panel", formation_style)
	var background_source: Texture2D = load("res://assets/inv-bg-1.webp")
	var background_texture := AtlasTexture.new()
	background_texture.atlas = background_source
	# Start from the painted frame without its faint outer shadow, then enlarge
	# that picture1% about its center while the panel bounds remain unchanged.
	var formation_region_size := FORMATION_BACKGROUND_REGION.size / FORMATION_BACKGROUND_CONTENT_SCALE
	formation_region_size.x /= FORMATION_BACKGROUND_HORIZONTAL_SCALE
	background_texture.region = Rect2(
		FORMATION_BACKGROUND_REGION.get_center() - formation_region_size * 0.5,
		formation_region_size
	)
	var background_layer := Node2D.new()
	background_layer.name = "FormationBackgroundLayer"
	formation_panel.add_child(background_layer)
	var background := TextureRect.new()
	background.name = "FormationPanelBackground"
	background.texture = background_texture
	background.self_modulate.a = 0.5
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_mask := ShaderMaterial.new()
	background_mask.shader = preload("res://scripts/map/map_inventory_panel_art.gdshader")
	background.material = background_mask
	background_layer.add_child(background)
	formation_panel.resized.connect(func():
		background.position = Vector2(-FORMATION_BACKGROUND_LEFT_EXTENSION, 0)
		background.size = formation_panel.size + Vector2(FORMATION_BACKGROUND_LEFT_EXTENSION, 0)
		_layout_panel_art(background, formation_panel, BOARD_PANEL_RADIUS)
	)
	formation_scroll = ScrollContainer.new()
	formation_scroll.name = "FormationScroll"
	formation_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	formation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	formation_panel.add_child(formation_scroll)
	formation_scroll.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			formation_scroll.scroll_horizontal += -106 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 106
			formation_scroll.accept_event()
	)
	var card_center := CenterContainer.new()
	card_center.name = "FormationCardCenter"
	card_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formation_scroll.add_child(card_center)
	formation_cards = HBoxContainer.new()
	formation_cards.name = "FormationCards"
	formation_cards.add_theme_constant_override("separation", 14)
	formation_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	formation_cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_center.add_child(formation_cards)
	_refresh_formations()

func _refresh_formations() -> void:
	for child in formation_cards.get_children():
		formation_cards.remove_child(child)
		child.queue_free()
	if loadout != null:
		for entry: Dictionary in loadout.formations:
			var card := _formation_card(formation_cards, entry.name, entry.icon)
			card.name = "Formation_" + entry.id
			card.set_meta("formation_id", entry.id)
			card.tooltip_text = "点击恢复已保存的道具布局；悬停3秒可修改。阵型较多时可用滚轮浏览。"
			card.pressed.connect(_apply_formation.bind(entry.id))
			card.enable_edit()
			card.edit_requested.connect(_open_formation_dialog.bind(entry.id))
	custom_formation_card = _formation_card(formation_cards, "阵型记录", "", true)
	custom_formation_card.name = "AddFormation"
	custom_formation_card.disabled = loadout == null
	custom_formation_card.tooltip_text = "将当前行囊中的道具和格位保存为新阵型。"
	custom_formation_card.pressed.connect(_open_formation_dialog)

func _formation_card(parent: Node, caption: String, icon_path: String, add_card: bool = false) -> Button:
	var card := preload("res://scripts/map/map_formation_card.gd").new()
	card.custom_minimum_size = FORMATION_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(style_name, empty_style)
	parent.add_child(card)
	_populate_formation_card(card, caption, icon_path, add_card)
	return card

func _populate_formation_card(card: Button, caption: String, icon_path: String, add_card: bool = false) -> void:
	for child in card.get_children():
		child.free()
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	card.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 7
	content.offset_top = 7
	content.offset_right = -7
	content.offset_bottom = -3
	var icon_slot := CenterContainer.new()
	icon_slot.name = "FormationIconSlot"
	icon_slot.custom_minimum_size = FORMATION_ICON_SIZE
	icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_slot)
	if add_card:
		var record_icon := TextureRect.new()
		record_icon.name = "FormationRecordIcon"
		record_icon.texture = load("res://assets/title-zhenxing.webp")
		record_icon.custom_minimum_size = FORMATION_ICON_SIZE
		record_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		record_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		record_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		record_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_child(record_icon)
	elif not icon_path.is_empty() and ResourceLoader.exists(icon_path, "Texture2D"):
		var icon := TextureRect.new()
		icon.name = "FormationIcon"
		icon.texture = load(icon_path)
		icon.custom_minimum_size = FORMATION_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_child(icon)
	if add_card:
		var record_caption := VBoxContainer.new()
		record_caption.name = "FormationRecordCaption"
		record_caption.custom_minimum_size.y = 50
		record_caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
		record_caption.alignment = BoxContainer.ALIGNMENT_CENTER
		record_caption.add_theme_constant_override("separation", -5)
		record_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(record_caption)
		var plus := Label.new()
		plus.name = "FormationAddMark"
		plus.text = "+"
		plus.custom_minimum_size.y = 25
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.add_theme_font_size_override("font_size", 22)
		plus.add_theme_color_override("font_color", SECTION_TITLE_COLOR)
		var plus_base := SystemFont.new()
		plus_base.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
		var plus_font := FontVariation.new()
		plus_font.base_font = plus_base
		plus_font.variation_embolden = 1.5
		plus.add_theme_font_override("font", plus_font)
		record_caption.add_child(plus)
		var record_name := _formation_name_label(record_caption, caption, SECTION_TITLE_COLOR)
		record_name.custom_minimum_size.y = 25
	else:
		var formation_name := _formation_name_label(content, caption, Color("e7dcc0"))
		formation_name.custom_minimum_size.y = 50

func _formation_name_label(parent: Node, caption: String, color: Color) -> Label:
	var name_label := Label.new()
	name_label.name = "FormationName"
	name_label.text = caption
	name_label.custom_minimum_size.y = 54
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name_label.max_lines_visible = 2
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_constant_override("line_spacing", -6)
	name_label.add_theme_color_override("font_color", color)
	parent.add_child(name_label)
	return name_label

func _build_formation_dialog() -> void:
	formation_dialog = Control.new()
	formation_dialog.name = "FormationCreateDialog"
	formation_dialog.z_index = 100
	formation_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	formation_dialog.visible = false
	stage.add_child(formation_dialog)
	formation_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color("02070bb8")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	formation_dialog.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	# PASS keeps the centered panel and its buttons interactive while the dim
	# layer still blocks clicks outside the dialog.
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	formation_dialog.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "FormationDialogPanel"
	# Let the content determine height so the creation view does not retain an
	# empty footer sized for the taller edit view.
	panel.custom_minimum_size = Vector2(FORMATION_DIALOG_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _box(Color("11181ee8"), Color("8e7950"), 18, 22))
	center.add_child(panel)
	var column := _column(panel, 12)
	var chooser_title := _label(column, "选择阵型图标", 18, Color("cfc2a0"))
	chooser_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var choices := VBoxContainer.new()
	choices.name = "FormationIconChoices"
	choices.add_theme_constant_override("separation", 12)
	column.add_child(choices)
	var choice_group := ButtonGroup.new()
	formation_icon_buttons.clear()
	var choice_row: HBoxContainer
	for index in config.get("formation_icons", []).size():
		if index % 3 == 0:
			choice_row = HBoxContainer.new()
			choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
			choice_row.add_theme_constant_override("separation", 12)
			choices.add_child(choice_row)
		var option: Dictionary = config.formation_icons[index]
		var choice := _formation_icon_choice(choice_row, option.get("name", "阵型"), option.get("icon", ""))
		choice.button_group = choice_group
		choice.pressed.connect(_select_formation_icon.bind(index))
		formation_icon_buttons.append(choice)
	var name_caption := _label(column, "阵型名称", 18, Color("cfc2a0"))
	name_caption.name = "FormationNameCaption"
	formation_name_input = LineEdit.new()
	formation_name_input.name = "FormationNameInput"
	formation_name_input.placeholder_text = "请输入阵型名称"
	formation_name_input.max_length = 12
	formation_name_input.custom_minimum_size.y = 48
	formation_name_input.add_theme_font_size_override("font_size", 17)
	formation_name_input.text_changed.connect(func(_value: String): _update_formation_create_enabled())
	column.add_child(formation_name_input)
	formation_replace_layout = CheckBox.new()
	formation_replace_layout.name = "FormationLayoutChoice"
	formation_replace_layout.text = "按当前阵盘的道具和格位保存"
	formation_replace_layout.add_theme_font_size_override("font_size", 17)
	# CheckBox hover_pressed otherwise falls back to a borderless style with
	# different padding. Keep every toggle/hover state visually identical.
	var layout_choice_style := _box(Color("10222d"), Color("334c58"), 7, 12)
	for state_name in ["normal", "hover", "pressed", "hover_pressed"]:
		formation_replace_layout.add_theme_stylebox_override(state_name, layout_choice_style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		formation_replace_layout.add_theme_color_override(color_name, Color("b5c7cb"))
	var unchecked_icon := _checkbox_icon(false)
	var checked_icon := _checkbox_icon(true)
	formation_replace_layout.add_theme_icon_override("unchecked", unchecked_icon)
	formation_replace_layout.add_theme_icon_override("unchecked_disabled", unchecked_icon)
	formation_replace_layout.add_theme_icon_override("checked", checked_icon)
	formation_replace_layout.add_theme_icon_override("checked_disabled", checked_icon)
	formation_replace_layout.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	column.add_child(formation_replace_layout)
	formation_message = _label(column, "", 16, Color("cfc2a0"))
	formation_message.name = "FormationMessage"
	formation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	formation_message.visible = false
	var actions := HBoxContainer.new()
	actions.name = "FormationDialogActions"
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	formation_create_button = _button(actions, "新建")
	formation_create_button.name = "FormationCreate"
	formation_create_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	formation_create_button.custom_minimum_size = Vector2(0, 48)
	formation_create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation_create_button.pressed.connect(_create_custom_formation)
	formation_cancel_button = _button(actions, "取消")
	formation_cancel_button.name = "FormationCancel"
	formation_cancel_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	formation_cancel_button.custom_minimum_size = Vector2(0, 48)
	formation_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation_cancel_button.pressed.connect(_close_formation_dialog)
	_select_formation_icon(0)
	_update_formation_create_enabled()

func _formation_icon_choice(parent: Node, caption: String, icon_path: String) -> Button:
	var choice := Button.new()
	choice.toggle_mode = true
	choice.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	choice.focus_mode = Control.FOCUS_NONE
	choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	choice.custom_minimum_size = Vector2(124, 130)
	var normal := _box(Color("0c1217d9"), Color("3c484d"), 12, 0)
	var hover := _box(Color("152229ed"), Color("7c8370"), 12, 0)
	var pressed := _box(Color("33211ced"), Color("c47d5f"), 12, 0)
	choice.add_theme_stylebox_override("normal", normal)
	choice.add_theme_stylebox_override("hover", hover)
	choice.add_theme_stylebox_override("pressed", pressed)
	choice.add_theme_stylebox_override("hover_pressed", pressed)
	choice.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(choice)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	choice.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_top = 8
	content.offset_right = -8
	content.offset_bottom = -8
	var icon_slot := CenterContainer.new()
	icon_slot.name = "FormationChoiceIconSlot"
	icon_slot.custom_minimum_size = Vector2(82, 82)
	icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_slot)
	var icon := TextureRect.new()
	icon.name = "FormationChoiceIcon"
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(82, 82)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.add_child(icon)
	var label := Label.new()
	label.text = caption
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("e1d5b8"))
	content.add_child(label)
	return choice

func _select_formation_icon(index: int) -> void:
	if formation_icon_buttons.is_empty():
		_selected_formation_icon = -1
		return
	_selected_formation_icon = clampi(index, 0, formation_icon_buttons.size() - 1)
	for button_index in formation_icon_buttons.size():
		formation_icon_buttons[button_index].set_pressed_no_signal(button_index == _selected_formation_icon)
	_update_formation_create_enabled()

func _open_formation_dialog(id: String = "") -> void:
	if loadout == null:
		return
	cancel_item_drag()
	for card in formation_cards.get_children():
		if card.has_method("_reset_edit_hover"):
			card._reset_edit_hover()
	_editing_formation_id = id
	formation_name_input.text = ""
	formation_replace_layout.visible = true
	formation_replace_layout.text = "按当前阵盘的道具和格位保存" if id.is_empty() else "用当前阵盘布局更新已保存的道具记录"
	formation_replace_layout.button_pressed = id.is_empty()
	formation_create_button.text = "新建" if id.is_empty() else "保存修改"
	formation_message.text = ""
	formation_message.visible = false
	_select_formation_icon(0)
	if not id.is_empty():
		var entry := loadout.find_formation(id)
		if entry.is_empty():
			return
		formation_name_input.text = entry.name
		for index in config.formation_icons.size():
			if config.formation_icons[index].icon == entry.icon:
				_select_formation_icon(index)
	formation_dialog.visible = true
	formation_name_input.grab_focus()
	_update_formation_create_enabled()

func _close_formation_dialog() -> void:
	formation_name_input.release_focus()
	formation_dialog.visible = false

func _update_formation_create_enabled() -> void:
	if formation_create_button != null:
		formation_create_button.disabled = _selected_formation_icon < 0 or formation_name_input == null or formation_name_input.text.strip_edges().is_empty()

func _create_custom_formation() -> void:
	if formation_create_button.disabled:
		return
	var option: Dictionary = config.formation_icons[_selected_formation_icon]
	var before := loadout.snapshot()
	var error := loadout.save_formation(
		formation_name_input.text.strip_edges(),
		option.icon,
		_editing_formation_id,
		formation_replace_layout.button_pressed,
		formation_replace_layout.button_pressed
	)
	if error.is_empty():
		error = _persist_formation_change(before)
	if not error.is_empty():
		formation_message.text = error
		formation_message.visible = true
		return
	_close_formation_dialog()

func _persist_formation_change(before: Dictionary) -> String:
	if not formation_save_callback.is_valid():
		return ""
	var error: String = formation_save_callback.call()
	if not error.is_empty():
		loadout.restore(before)
	return error

func _apply_formation(id: String) -> void:
	cancel_item_drag()
	var before := loadout.snapshot()
	var error := loadout.apply_formation(id)
	if error.is_empty():
		error = _persist_formation_change(before)
	if not error.is_empty():
		_open_formation_dialog(id)
		formation_message.text = "无法恢复阵型：" + error
		formation_message.visible = true

func is_formation_dialog_open() -> bool:
	return formation_dialog != null and formation_dialog.visible

func close_formation_dialog() -> bool:
	if not is_formation_dialog_open():
		return false
	_close_formation_dialog()
	return true

func _build_storage() -> void:
	storage_panel = _panel(body, "StoragePanel")
	storage_panel.theme = _storage_theme()
	var storage_style := _box(Color.TRANSPARENT, Color.TRANSPARENT, int(BOARD_PANEL_RADIUS), 14)
	storage_style.set_border_width_all(0)
	storage_style.content_margin_top = 22
	storage_style.content_margin_left = 0
	storage_style.content_margin_right = 0
	storage_panel.add_theme_stylebox_override("panel", storage_style)
	_add_panel_border(storage_panel, BOARD_PANEL_RADIUS, STORAGE_BORDER_COLOR)
	storage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background_source: Texture2D = load("res://assets/inv-bg-3.webp")
	var background_texture := AtlasTexture.new()
	background_texture.atlas = background_source
	background_texture.region = STORAGE_BACKGROUND_REGION
	var background_layer := Node2D.new()
	background_layer.name = "StorageBackgroundLayer"
	storage_panel.add_child(background_layer)
	var background := TextureRect.new()
	background.name = "StoragePanelBackground"
	background.texture = background_texture
	background.self_modulate.a = 0.5
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_mask := ShaderMaterial.new()
	background_mask.shader = preload("res://scripts/map/map_inventory_panel_art.gdshader")
	background.material = background_mask
	background_layer.add_child(background)
	storage_panel.resized.connect(func():
		background.size = storage_panel.size * STORAGE_BACKGROUND_SCALE
		background.position = (storage_panel.size - background.size) * 0.5 + Vector2(STORAGE_BACKGROUND_X_SHIFT, STORAGE_BACKGROUND_Y_SHIFT)
		_layout_panel_art(background, storage_panel, BOARD_PANEL_RADIUS)
	)
	var column := _column(storage_panel, 8)
	var toolbar_margin := MarginContainer.new()
	toolbar_margin.name = "StorageToolbarMargin"
	toolbar_margin.add_theme_constant_override("margin_left", STORAGE_CONTENT_INSET)
	toolbar_margin.add_theme_constant_override("margin_right", STORAGE_CONTENT_INSET)
	column.add_child(toolbar_margin)
	storage_toolbar = _column(toolbar_margin, 6)
	storage_toolbar.name = "StorageToolbar"
	var heading := _section_heading(storage_toolbar, "储物袋", "res://assets/title-chuwudai.webp", STORAGE_TITLE_ICON_X_OFFSET)
	search = LineEdit.new()
	search.name = "ItemSearch"
	search.placeholder_text = "搜索物品名称…"
	search.custom_minimum_size = Vector2(STORAGE_SEARCH_WIDTH, 30)
	search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search.add_theme_font_size_override("font_size", 14)
	search.clear_button_enabled = true
	heading.add_child(search)
	search.text_changed.connect(func(value: String): catalog.set_filter("search", value))
	var tabs := HBoxContainer.new()
	tabs.name = "CollectionTabs"
	tabs.add_theme_constant_override("separation", 8)
	storage_toolbar.add_child(tabs)
	for key: String in catalog.collection_names:
		var button := _compact_button(tabs, catalog.collection_names[key], 32)
		button.name = "CollectionTab_" + key
		button.add_theme_font_size_override("font_size", 16)
		button.toggle_mode = true
		_style_collection_tab(button)
		button.pressed.connect(func(): catalog.set_filter("collection", key))
		_collections[key] = button
	_rule(storage_toolbar)
	var filters := HFlowContainer.new()
	_category_filters = filters
	filters.name = "CategoryFilters"
	filters.add_theme_constant_override("h_separation", 5)
	filters.add_theme_constant_override("v_separation", 5)
	storage_toolbar.add_child(filters)
	for key: String in catalog.category_names:
		if key in ["all", "key", "misc"]:
			continue
		var button := _compact_button(filters, catalog.category_names[key], 30)
		button.name = "CategoryTab_" + key
		button.add_theme_font_size_override("font_size", 14)
		button.toggle_mode = true
		_style_category_tab(button)
		button.pressed.connect(func(): catalog.set_filter("category", "all" if catalog.category == key else key))
		_categories[key] = button
	_rule(storage_toolbar)
	_category_rule = storage_toolbar.get_child(-1)
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
	well.name = "StorageItemWell"
	var well_style := _box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 10)
	well_style.content_margin_left = STORAGE_CARD_INSET
	well_style.content_margin_right = STORAGE_CARD_INSET
	well_style.set_border_width_all(0)
	well.add_theme_stylebox_override("panel", well_style)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(well)
	var content_stack := Control.new()
	well.add_child(content_stack)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Wheel scrolling must not add/remove a scrollbar-width slice from the cards.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content_stack.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid = InventoryGrid.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", STORAGE_CARD_GAP)
	grid.add_theme_constant_override("v_separation", STORAGE_CARD_ROW_GAP)
	scroll.add_child(grid)
	grid.resized.connect(_size_item_cards)
	scroll.resized.connect(_size_item_cards)
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
func _refresh() -> void:
	for key in _collections:
		_collections[key].text = "%s %d" % [catalog.collection_names[key], catalog.collection_count(key)]
		_collections[key].set_pressed_no_signal(catalog.collection == key)
	for key in _categories:
		_categories[key].visible = key in catalog.subcategories()
		_categories[key].set_pressed_no_signal(catalog.category == key)
	_category_filters.visible = not catalog.subcategories().is_empty()
	_category_rule.visible = _category_filters.visible
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
	var entries := catalog.visible_entries()
	# Transfers change only one or two records. Keep unchanged cards alive:
	# rebuilding their fonts/artwork synchronously stalls the drop frame.
	var reusable := {}
	for child in grid.get_children():
		if child is MapInventoryItemCard:
			reusable[child.entry.id] = child
		else:
			grid.remove_child(child)
			child.queue_free()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var card: MapInventoryItemCard = reusable.get(entry.id)
		if card != null and card.entry != entry:
			grid.remove_child(card)
			card.queue_free()
			card = null
		reusable.erase(entry.id)
		if card == null:
			_add_item_card(entry)
			grid.move_child(grid.get_child(-1), index)
		else:
			grid.move_child(card, index)
	for child in reusable.values():
		grid.remove_child(child)
		child.queue_free()
	_size_item_cards()
	empty_state.visible = entries.is_empty()
	empty_title.text = "储物袋空空如也" if catalog.total_count() == 0 else "没有符合条件的物品"
	empty_caption.text = "获得的物品会显示在这里" if catalog.total_count() == 0 else "试试其他分类，或重置筛选"
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
	if grid == null:
		return
	# Measure the visible viewport, not the grid's content minimum, which can
	# retain the previous wider cards and push the last column offscreen.
	var scroll := grid.get_parent() as ScrollContainer
	var available := (scroll.get_parent() as Control).size.x
	if available <= 0:
		return
	var width := (available - grid.get_theme_constant("h_separation") * (grid.columns - 1)) / grid.columns
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
	# At16:9 the left/right margins are23px and both column gaps are19px.
	# On wider windows, use the
	# spare sides for the sidebar and storage while keeping the middle in place.
	var extra_width := maxf(0, size.x / factor - 1920.0)
	sidebar_spacer.visible = extra_width > 0
	sidebar_spacer.custom_minimum_size.x = extra_width * 0.5
	body.position = Vector2(BODY_SIDE_MARGIN - extra_width * 0.5, 146)
	body.size = Vector2(BODY_WIDTH + extra_width, BODY_HEIGHT)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if is_formation_dialog_open():
		for index in formation_icon_buttons.size():
			if formation_icon_buttons[index].get_global_rect().has_point(event.position):
				_select_formation_icon(index)
				get_viewport().set_input_as_handled()
				return
		if formation_cancel_button.get_global_rect().has_point(event.position):
			_close_formation_dialog()
			get_viewport().set_input_as_handled()
			return
		if formation_create_button.get_global_rect().has_point(event.position) and not formation_create_button.disabled:
			_create_custom_formation()
			get_viewport().set_input_as_handled()
		return
	# Route the small edit target before the enclosing card, matching the modal
	# buttons above. Limit hit testing to the visible scroll area.
	if not formation_scroll.get_global_rect().has_point(event.position):
		return
	for card in formation_cards.get_children():
		if not card.has_meta("formation_id") or not card.get_global_rect().has_point(event.position):
			continue
		if card.edit_button.visible and card.edit_button.get_global_rect().has_point(event.position):
			_open_formation_dialog(card.get_meta("formation_id"))
		else:
			_apply_formation(card.get_meta("formation_id"))
		get_viewport().set_input_as_handled()
		return
	if custom_formation_card != null and not custom_formation_card.disabled and custom_formation_card.get_global_rect().has_point(event.position):
		_open_formation_dialog()
		get_viewport().set_input_as_handled()

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
