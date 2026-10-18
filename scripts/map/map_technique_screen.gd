class_name MapTechniqueScreen
extends Control

signal close_requested
signal category_changed(element_id: String)
signal book_selected(book_id: String)

# Technique workspace, aligned to the existing inventory design canvas.
const Inventory := preload("res://scripts/map/map_inventory_screen.gd")
const LEFT_WIDTH := Inventory.BODY_HEIGHT / 3.0 - 50.0
const RIGHT_WIDTH := Inventory.BODY_HEIGHT * 5.0 / 12.0
const PROGRESS_TITLE_WIDTH := 240.0
const PROGRESS_TITLE_LEFT_GAP := 16.0
const PROGRESS_HEADING_OFFSET_Y := 30.0
const PROGRESS_TITLE_LINE_OVERLAP := 4.0
var stage: Control
var body: Control
var left_panel: PanelContainer
var middle_panel: PanelContainer
var right_panel: PanelContainer
var background_art: TextureRect
var return_button: BattleActionButton
var return_slot: Control
var title_art: TextureRect
var progress_title: TextureRect
var progress_divider: ColorRect
var progress_art: TextureRect
var progress_shade: ColorRect
var overview: Control
var category_row: HBoxContainer
var category_buttons: Array[Button] = []
var selected_element_id := "base.element.metal"
var book_list: VBoxContainer
var book_cards: Array[Button] = []
var selected_book_id := ""

func _init() -> void:
	name = "MapTechniqueScreen"
	z_index = 25
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var backing := ColorRect.new()
	backing.color = Color("08121c")
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art = TextureRect.new()
	background_art.name = "TechniqueBackground"
	background_art.texture = load("res://assets/inv-background.webp")
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.self_modulate.a = 0.5
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_art)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(body)
	left_panel = _panel(body, "TechniqueLeftPanel", 18.0, "left")
	middle_panel = _panel(body, "TechniqueMiddlePanel", Inventory.BOARD_PANEL_RADIUS, "middle")
	right_panel = _panel(body, "TechniqueRightPanel", Inventory.BOARD_PANEL_RADIUS, "right")
	for panel in [left_panel, middle_panel, right_panel]:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_panel.anchor_right = 0.0
	right_panel.anchor_left = 1.0
	_build_sidebar()
	_build_progress_heading()
	resized.connect(_layout)
	visibility_changed.connect(_reveal_selected_book)

func _build_progress_heading() -> void:
	# Keep these decorative controls out of PanelContainer's sizing pass.
	var layer := Node2D.new()
	layer.name = "ProgressHeadingLayer"
	layer.z_index = 2
	middle_panel.add_child(layer)
	overview = preload("res://scripts/map/map_technique_overview.gd").new()
	layer.add_child(overview)
	progress_shade = ColorRect.new()
	progress_shade.name = "ProgressShade"
	progress_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	shade_material.shader = preload("res://scripts/map/map_technique_progress_shade.gdshader")
	progress_shade.material = shade_material
	layer.add_child(progress_shade)
	progress_divider = ColorRect.new()
	progress_divider.name = "ProgressDivider"
	progress_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_technique_progress_divider.gdshader")
	paint.set_shader_parameter("corner_radius", Inventory.BOARD_PANEL_RADIUS)
	paint.set_shader_parameter("line_width", Inventory.BOARD_PANEL_BORDER_WIDTH)
	paint.set_shader_parameter("line_color", Inventory.MAIN_PANEL_BORDER_COLOR)
	progress_divider.material = paint
	layer.add_child(progress_divider)
	progress_title = TextureRect.new()
	progress_title.name = "CultivationProgressTitle"
	var source: Texture2D = load("res://assets/UI-gongfa-mid-xiuxingjindu.webp")
	var trimmed := AtlasTexture.new()
	trimmed.atlas = source
	trimmed.region = preload("res://scripts/map/map_texture_metrics.gd").solid_rect(source)
	progress_title.texture = trimmed
	progress_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	progress_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	progress_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	progress_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(progress_title)
	progress_art = preload("res://scripts/map/map_technique_progress_art.gd").new()
	layer.add_child(progress_art)
	progress_art.layout_changed.connect(_layout_progress_heading)
	middle_panel.resized.connect(_layout_progress_heading)
	_layout_progress_heading()

func _layout_progress_heading() -> void:
	var divider_y := middle_panel.size.y * 0.5 + PROGRESS_HEADING_OFFSET_Y
	overview.book_center_y = divider_y * 0.5
	overview.size = Vector2(middle_panel.size.x, divider_y - 8)
	progress_shade.position = Vector2(2, divider_y + 1)
	progress_shade.size = Vector2(maxf(0, middle_panel.size.x - 4), maxf(0, middle_panel.size.y - divider_y - 3))
	var art_size := progress_title.texture.get_size()
	progress_title.size = art_size * (PROGRESS_TITLE_WIDTH / art_size.x)
	progress_title.position = Vector2(PROGRESS_TITLE_LEFT_GAP, divider_y - progress_title.size.y * 0.5)
	# Draw only the rounded top edge of the lower half. The existing panel owns
	# both vertical edges, so there is no doubled border or extra shaded fill.
	progress_divider.position = Vector2(-2.0, divider_y - 2.0)
	progress_divider.size = Vector2(middle_panel.size.x + 4.0, Inventory.BOARD_PANEL_RADIUS + 4.0)
	var paint := progress_divider.material as ShaderMaterial
	paint.set_shader_parameter("panel_size", Vector2(middle_panel.size.x, middle_panel.size.y - divider_y))
	# Extend under the opaque gold tips, not just the rectangular texture bounds.
	# This closes the visible seams without drawing a line through the title.
	paint.set_shader_parameter("title_gap", Vector2(progress_title.position.x + PROGRESS_TITLE_LINE_OVERLAP, progress_title.get_rect().end.x - PROGRESS_TITLE_LINE_OVERLAP))
	var available := Vector2(maxf(0, middle_panel.size.x - 32), maxf(0, middle_panel.size.y - divider_y - 80))
	# Keep the original scale reference; all progress frames can center their
	# complete cropped artwork in the lower bordered panel.
	var crop: Array = progress_art.reference.display_crop
	var placement: Array = progress_art.reference.get("placement_crop", crop)
	var source := Vector2(placement[2], placement[3])
	var factor := minf(available.x / source.x, available.y / source.y)
	progress_art.size = Vector2(crop[2], crop[3]) * factor
	progress_art.position = Vector2(16, divider_y + 52) + (available - source * factor) * 0.5 + Vector2(crop[0] - placement[0], crop[1] - placement[1]) * factor
	if progress_art.reference.get("center_in_lower_panel", false):
		progress_art.position = Vector2(middle_panel.size.x * 0.5, (divider_y + middle_panel.size.y) * 0.5) - progress_art.size * 0.5

func _build_sidebar() -> void:
	# Match the inventory's original 208px sidebar, including its 22px inset.
	return_slot = Control.new()
	return_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_slot.size = Vector2(164, 56)
	body.add_child(return_slot)
	return_button = BattleActionButton.new()
	return_button.name = "ReturnToMap"
	return_button.configure("res://assets/button-return.webp", Vector2(0, 56))
	return_slot.add_child(return_button)
	return_button.anchor_left = -0.22
	return_button.anchor_right = 1.22
	return_button.anchor_top = -0.1
	return_button.anchor_bottom = 1.1
	return_button.offset_top = -10.0
	return_button.offset_bottom = -10.0
	return_button.pressed.connect(func(): close_requested.emit())
	var reference := BattleActionButton.trimmed_art("res://assets/UI-title-shuxingjiacheng.webp")
	title_art = TextureRect.new()
	title_art.name = "TechniqueLibraryTitle"
	title_art.texture = BattleActionButton.trimmed_art("res://assets/UI-gongfa-left-title.webp")
	title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Enlarge the previous attributes-title display bounds by one third.
	title_art.size = reference.get_size() * (50.0 / reference.get_height()) * (4.0 / 3.0)
	body.add_child(title_art)
	_build_categories()
	book_list = VBoxContainer.new()
	book_list.name = "TechniqueBooks"
	book_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_list.add_theme_constant_override("separation", 10)
	body.add_child(book_list)

func configure(library: CultivationLibrary) -> void:
	var book_art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_book_art.json"))
	for card in book_cards:
		book_list.remove_child(card)
		card.queue_free()
	book_cards.clear()
	if not library.books.has(selected_book_id): selected_book_id = ""
	var ids := library.books.keys()
	ids.sort()
	# Category filtering never changes the single globally selected book.
	var group := ButtonGroup.new()
	for category: Button in category_buttons:
		var element_id := String(category.get_meta("element_id"))
		for id: String in ids:
			var book: Dictionary = library.books[id]
			if "base.element." + String(book.element) != element_id: continue
			var card := preload("res://scripts/map/map_technique_book_card.gd").new()
			card.configure(book, category.get_theme_color("font_color"), group)
			if book_art.has(id): card.set_preview_texture(BattleActionButton.trimmed_art(book_art[id]))
			book_list.add_child(card)
			book_cards.append(card)
			if selected_book_id.is_empty(): selected_book_id = id
			if selected_book_id == id:
				card.set_pressed_no_signal(true)
			card.toggled.connect(func(pressed: bool):
				if pressed and selected_book_id != id:
					selected_book_id = id
					progress_art.show_book(id)
					overview.show_book(id)
					book_selected.emit(id))
	_show_category()
	progress_art.show_book(selected_book_id)
	overview.show_book(selected_book_id)

func _show_category() -> void:
	for card in book_cards:
		card.visible = card.element_id == selected_element_id

func _reveal_selected_book() -> void:
	if not visible: return
	for card in book_cards:
		if card.book_id != selected_book_id: continue
		selected_element_id = card.element_id
		for button in category_buttons:
			button.set_pressed_no_signal(button.get_meta("element_id") == selected_element_id)
		_show_category()
		return

func _build_categories() -> void:
	category_row = HBoxContainer.new()
	category_row.name = "ElementCategories"
	category_row.add_theme_constant_override("separation", 4)
	category_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(category_row)
	var group := ButtonGroup.new()
	var category_font := SystemFont.new()
	category_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	var categories: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_categories.json"))
	for category: Dictionary in categories:
		var button := Button.new()
		var color := Color(String(category.color))
		var element_id := String(category.element_id)
		button.name = "Category_" + element_id.get_slice(".", 2)
		button.text = category.label
		button.custom_minimum_size = Vector2(31, 31)
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", category_font)
		button.add_theme_font_size_override("font_size", 19)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, color)
		button.add_theme_stylebox_override("normal", _category_style(color, false))
		button.add_theme_stylebox_override("hover", _category_style(color, false, true))
		button.add_theme_stylebox_override("pressed", _category_style(color, true))
		button.add_theme_stylebox_override("hover_pressed", _category_style(color, true, true))
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color(color, 0.65)
		focus.set_border_width_all(1)
		focus.set_corner_radius_all(5)
		focus.set_expand_margin_all(2)
		button.add_theme_stylebox_override("focus", focus)
		button.set_meta("element_id", element_id)
		button.set_pressed_no_signal(element_id == selected_element_id)
		button.toggled.connect(func(pressed: bool):
			if pressed and selected_element_id != element_id:
				selected_element_id = element_id
				_show_category()
				category_changed.emit(element_id))
		category_row.add_child(button)
		category_buttons.append(button)

func _category_style(color: Color, selected: bool, hovered := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102632ed") if not selected else Color("102632").lerp(color, 0.13)
	style.border_color = color if selected else Color("456271")
	if hovered and not selected: style.border_color = Color(color, 0.7)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(0)
	style.corner_detail = 8
	if selected:
		style.shadow_color = Color(color, 0.28)
		style.shadow_size = 4
	return style

func _panel(parent: Node, node_name: String, radius: float, background_key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("0d1c26")
	fill.set_corner_radius_all(int(radius))
	fill.corner_detail = 16
	fill.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", fill)
	parent.add_child(panel)
	# Keep artwork outside container sizing, below the independently drawn rim.
	var backdrop_layer := Node2D.new()
	backdrop_layer.name = "BackdropLayer"
	panel.add_child(backdrop_layer)
	var art := TextureRect.new()
	art.name = "ColumnBackground"
	art.texture = load("res://assets/UI-gongfa-%s-bg.webp" % background_key)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/map/map_inventory_panel_art.gdshader")
	art.material = mask
	backdrop_layer.add_child(art)
	panel.resized.connect(_layout_column_art.bind(panel, art, radius))
	var layer := Node2D.new()
	layer.z_index = 1
	panel.add_child(layer)
	var rim := ColorRect.new()
	rim.name = "Border"
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_panel_border.gdshader")
	paint.set_shader_parameter("corner_radius", radius)
	paint.set_shader_parameter("line_width", Inventory.BOARD_PANEL_BORDER_WIDTH)
	paint.set_shader_parameter("line_color", Inventory.MAIN_PANEL_BORDER_COLOR)
	rim.material = paint
	layer.add_child(rim)
	panel.resized.connect(func():
		rim.position = -Vector2.ONE * 2.0
		rim.size = panel.size + Vector2.ONE * 4.0
		paint.set_shader_parameter("panel_size", panel.size))
	return panel

func _layout_column_art(panel: Control, art: TextureRect, radius: float) -> void:
	# Cover without distortion, preserving the source and panel centers.
	var source_size := art.texture.get_size()
	var factor := maxf(panel.size.x / source_size.x, panel.size.y / source_size.y)
	if panel == middle_panel and panel.size.x > 50.0:
		# Follow the cumulative fifty-pixel extension with centered enlargement.
		factor *= panel.size.x / (panel.size.x - 50.0)
	art.size = source_size * factor
	art.position = (panel.size - art.size) * 0.5
	var mask := art.material as ShaderMaterial
	mask.set_shader_parameter("panel_size", panel.size)
	mask.set_shader_parameter("art_size", art.size)
	mask.set_shader_parameter("art_position", art.position)
	mask.set_shader_parameter("corner_radius", radius)

func _layout() -> void:
	if size.x <= 0 or size.y <= 0: return
	var base_head := MapStatusHeader.height_for_width(1920.0)
	var head_height := MapStatusHeader.height_for_width(size.x)
	background_art.position = Vector2(0, head_height)
	background_art.size = Vector2(size.x, maxf(0, size.y - head_height))
	var factor := minf(size.x / 1920.0, (size.y - head_height) / (1080.0 - base_head))
	if factor <= 0: return
	stage.scale = Vector2.ONE * factor
	stage.size = Vector2(1920, 1080)
	stage.position = Vector2((size.x - 1920.0 * factor) * 0.5, head_height - base_head * factor + (size.y - head_height - (1080.0 - base_head) * factor) * 0.5)
	var extra_width := maxf(0, size.x / factor - 1920.0)
	# Anchors retain fractional ratios without HBox rounding each column upward.
	# The middle absorbs spare width, preserving the inventory's outer edges/gaps.
	left_panel.offset_right = LEFT_WIDTH
	middle_panel.offset_left = LEFT_WIDTH + Inventory.BODY_COLUMN_GAP + extra_width * 0.5
	middle_panel.offset_right = -RIGHT_WIDTH - Inventory.BODY_COLUMN_GAP
	right_panel.offset_left = -RIGHT_WIDTH
	body.position = Vector2(Inventory.BODY_SIDE_MARGIN - extra_width * 0.5, 146)
	body.size = Vector2(Inventory.BODY_WIDTH + extra_width, Inventory.BODY_HEIGHT)
	return_slot.position = Vector2(22, 22)
	# Reference red box maps to y68..156 between return artwork and categories.
	title_art.position = Vector2((LEFT_WIDTH - title_art.size.x) * 0.5, 112.0 - title_art.size.y * 0.5)
	# Fit the narrower sidebar while retaining balanced insets.
	category_row.position = Vector2((LEFT_WIDTH - 241.0) * 0.5, 158.0)
	category_row.size = Vector2(241, 31)
	book_list.position = Vector2(category_row.position.x, 204.0)
	book_list.size = Vector2(241, 0)
