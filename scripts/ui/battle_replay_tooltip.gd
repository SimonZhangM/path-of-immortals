extends ItemTooltip

const Format = preload("res://scripts/presentation/battle_replay_format.gd")
const Details = preload("res://scripts/presentation/battle_replay_details.gd")
const PANEL_SIZE := Vector2(610, 610)
const PANEL_ART := "res://assets/UI-battle-item-info.webp"
const TextureMetrics = preload("res://scripts/map/map_texture_metrics.gd")
const HeadingDiamond = preload("res://scripts/ui/task_heading_diamond.gd")
const HEADING_COLOR := Color("f4dfa3")
# The artwork's thin inner rim, scaled from its 877px source to the 610px card.
const INNER_MARGINS := {"left": 27, "right": 27, "top": 31, "bottom": 28}
var scroll: ScrollContainer
var share_data: Dictionary
var share_entries: Array[Dictionary]
var statistic_rows: Array[Dictionary]
var _background: Texture2D
var _portrait_slot: Control
var _statistics_columns: Control

class StatisticIcon extends Control:
	var texture: Texture2D
	var solid_bounds := Rect2()
	func _init(path: String) -> void:
		name = "MetricIcon"
		custom_minimum_size = Vector2(26, 26)
		size_flags_vertical = SIZE_SHRINK_CENTER
		clip_contents = true
		if not path.is_empty() and ResourceLoader.exists(path):
			texture = load(path)
			solid_bounds = TextureMetrics.solid_rect(texture)
		else:
			set_meta("reserved_icon", path)
		resized.connect(queue_redraw)
	func _draw() -> void:
		if texture == null or not solid_bounds.has_area(): return
		# Normalize the visible symbol, rather than its transparent canvas or glow.
		var factor := 22.0 / maxf(solid_bounds.size.x, solid_bounds.size.y)
		var origin := size * 0.5 - solid_bounds.get_center() * factor
		draw_texture_rect(texture, Rect2(origin, texture.get_size() * factor), false)

class ContributionRing extends Control:
	var ratio := 0.0
	var tint := Color("e77b61")
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 11
		draw_arc(center, radius, -PI * 0.5, PI * 1.5, 96, Color("354c5d"), 16, true)
		if ratio > 0:
			draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0, 1), 96, tint, 16, true)

func configure_stats(item: ItemData, row: Dictionary, registry: ContentRegistry, snapshot: Dictionary, _screen: Vector2, context: Dictionary = {}) -> void:
	_ensure_fonts()
	theme = Theme.new()
	theme.default_font = _body_font
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	name = "BattleReplayTooltip"
	set_meta("replay", true)
	if context.has("replay_center"): set_meta("replay_center", context.replay_center)
	_background = load(PANEL_ART)
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	var margins := MarginContainer.new()
	for side: String in INNER_MARGINS:
		margins.add_theme_constant_override("margin_" + side, INNER_MARGINS[side])
	add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margins.add_child(column)
	_build_header(column, item, context)
	share_entries = Details.shares(item, row, snapshot)
	share_data = share_entries[0]
	statistic_rows = Details.rows(item, row, registry, snapshot)
	var lower := HBoxContainer.new()
	lower.name = "BattleStatisticsColumns"
	_statistics_columns = lower
	lower.item_rect_changed.connect(queue_redraw)
	lower.size_flags_vertical = SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 10)
	column.add_child(lower)

	var table := PanelContainer.new()
	table.name = "BattleStatisticsTable"
	table.size_flags_horizontal = SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", _box(Color("071c26", 0.5), Color("334d59"), 6, 10))
	lower.add_child(table)
	var table_column := VBoxContainer.new()
	table_column.add_theme_constant_override("separation", 7)
	table.add_child(table_column)
	table_column.add_child(_section_heading("本场战斗数据"))
	scroll = ScrollContainer.new()
	scroll.name = "BattleStatisticsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	table_column.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "BattleStatistics"
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	scroll.add_child(body)
	for entry: Dictionary in statistic_rows:
		_add_row(body, entry)
	_build_share(lower, item, row)
	_ignore(self)
	queue_redraw()

func _build_header(parent: VBoxContainer, item: ItemData, context: Dictionary) -> void:
	# Build within this card's rim; reuse identity styling, not the tooltip panel.
	var inset := MarginContainer.new()
	inset.name = "SummaryPanel"
	for edge in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + edge, 10)
	parent.add_child(inset)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	inset.add_child(header)
	var slot := PanelContainer.new()
	slot.name = "ItemPortrait"
	_portrait_slot = slot
	slot.item_rect_changed.connect(queue_redraw)
	slot.custom_minimum_size = Vector2(112, 112)
	slot.size_flags_vertical = SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	header.add_child(slot)
	var record := MapItemArtwork.item_record(item)
	record.art_outline_px = 1
	preload("res://scripts/map/map_item_small_background.gd").create(slot, record, Color("4b5260"), 10)
	var canvas := Control.new()
	slot.add_child(canvas)
	var art := MapItemArtwork.new()
	art.name = "PortraitArtwork"
	art.configure(record, true)
	canvas.add_child(art)
	art.size = Vector2(86, 86)
	art.apply_inventory_pose({"category": item.category, "footprint_columns": item.grid_size.x, "footprint_rows": item.grid_size.y})
	art.pivot_offset = art.size * 0.5
	var center_portrait := func(): art.center_visible_at(canvas.size * 0.5, "tooltip")
	canvas.resized.connect(center_portrait)
	center_portrait.call()
	var glow := art.get_node("ItemGlow") as ColorRect
	art.remove_child(glow)
	canvas.add_child(glow)
	canvas.move_child(glow, 0)
	glow.show_behind_parent = false
	glow.set_anchors_and_offsets_preset(PRESET_CENTER)
	glow.offset_left = -50
	glow.offset_top = -50
	glow.offset_right = 50
	glow.offset_bottom = 50
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	identity.size_flags_vertical = SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 12)
	header.add_child(identity)
	var title_row := HBoxContainer.new()
	title_row.name = "ItemTitleRow"
	title_row.add_theme_constant_override("separation", 9)
	identity.add_child(title_row)
	var quality := MapItemQuality.level(item.quality)
	if quality > 0:
		var badge := TextureRect.new()
		badge.name = "QualityBadge"
		badge.texture = BattleActionButton.trimmed_art("res://assets/levelbq-%d.webp" % quality)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.custom_minimum_size = Vector2(40 * badge.texture.get_width() / badge.texture.get_height(), 40)
		badge.size_flags_vertical = SIZE_SHRINK_CENTER
		title_row.add_child(badge)
	var title := _label(summary_name(item.display_name, item.category), 40)
	title.name = "ItemTitle"
	style_item_title(title, 40)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title_row.add_child(title)
	var chips := HFlowContainer.new()
	chips.name = "CategoryTags"
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	identity.add_child(chips)
	for tag: String in classification_tags(item, false, context.get("enemy_armor_type", "")):
		var label := chip(tag, CLASSIFICATION_COLOR, UI_SCALE)
		label.add_theme_font_size_override("font_size", 20)
		chips.add_child(label)

func _section_heading(caption: String) -> HBoxContainer:
	var heading := HBoxContainer.new()
	heading.name = "SectionHeading"
	heading.add_theme_constant_override("separation", 6)
	var diamond := HeadingDiamond.new(Vector2(16, 28), HEADING_COLOR)
	heading.add_child(diamond)
	var label := _label(caption, 21)
	label.name = "HeadingLabel"
	label.add_theme_color_override("font_color", HEADING_COLOR)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(label)
	return heading

func _draw() -> void:
	if _background != null:
		draw_texture_rect(_background, Rect2(Vector2.ZERO, size), false)
	if is_instance_valid(_portrait_slot) and is_instance_valid(_statistics_columns):
		var inverse := get_global_transform().affine_inverse()
		var portrait_bounds: Rect2 = inverse * _portrait_slot.get_global_rect()
		var table_bounds: Rect2 = inverse * _statistics_columns.get_global_rect()
		var divider_y := (portrait_bounds.end.y + table_bounds.position.y) * 0.5
		draw_line(Vector2(INNER_MARGINS.left, divider_y), Vector2(size.x - INNER_MARGINS.right, divider_y), Color("303846"), 1.0)

func _label(text: String, font_size := 19) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _body_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e3e8ea"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _add_row(parent: Node, entry: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "Row_" + str(entry.key).replace("/", "_")
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("35444e", 0.7)
	style.border_width_bottom = 1
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 7)
	panel.add_child(line)
	line.add_child(StatisticIcon.new(entry.icon))
	var caption := _label(entry.label)
	caption.custom_minimum_size.x = 100
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(caption)
	var value := _label(entry.value, 22 if entry.primary else 19)
	value.name = "MetricValue"
	value.size_flags_horizontal = SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if entry.primary:
		value.add_theme_font_override("font", _bold_term_font)
		value.add_theme_color_override("font_color", Color("fff1c2"))
	line.add_child(value)

func _build_share(parent: Node, item: ItemData, row: Dictionary) -> void:
	var stack := Control.new()
	stack.name = "ContributionStack"
	stack.custom_minimum_size = Vector2(174, 390)
	parent.add_child(stack)
	for index in 2:
		if index < share_entries.size():
			_build_share_card(stack, item, row, share_entries[index], index)
		else:
			var space := Control.new()
			space.name = "SecondContributionSpace"
			space.custom_minimum_size.y = 190
			stack.add_child(space)
			_position_share_slot(space, index)

func _position_share_slot(slot: Control, index: int) -> void:
	# Anchors preserve equal half-pixel heights instead of VBox rounding one card up.
	slot.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if index == 0:
		slot.anchor_bottom = 0.5
		slot.offset_bottom = -5
	else:
		slot.anchor_top = 0.5
		slot.offset_top = 5

func _build_share_card(parent: Node, item: ItemData, row: Dictionary, data: Dictionary, index: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "ContributionPanel" if index == 0 else "SecondaryContributionPanel"
	panel.custom_minimum_size = Vector2(174, 190)
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("071c26", 0.5), Color("334d59"), 6, 10))
	parent.add_child(panel)
	_position_share_slot(panel, index)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_section_heading(data.caption + "占比"))
	var center := Control.new()
	center.name = "ContributionChartArea"
	center.custom_minimum_size = Vector2(128, 128)
	center.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(center)
	var ring := ContributionRing.new()
	ring.name = "ContributionRing"
	ring.custom_minimum_size = Vector2(128, 128)
	ring.ratio = data.ratio
	var kind := Format.profile(item)
	var colors := {"recovery": Color("7edc8a"), "debuff": Color("aa7bd9"), "shield": Color("72b8d8"), "armor": Color("72b8d8"), "buff": Color("72b8d8")}
	ring.tint = colors.get(kind, Color("e77b61"))
	center.add_child(ring)
	ring.set_anchors_and_offsets_preset(PRESET_CENTER)
	ring.offset_left = -64
	ring.offset_top = -64
	ring.offset_right = 64
	ring.offset_bottom = 64
	var ring_content := VBoxContainer.new()
	ring_content.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_content.add_theme_constant_override("separation", 3)
	ring.add_child(ring_content)
	ring_content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var percent := _label(data.percent, 25)
	percent.name = "ContributionPercent"
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_content.add_child(percent)
	if data.total <= 0:
		var status := "本场无此类效果" if data.total == 0 else "占比数据未记录"
		if not Format.rotates(item) and row.get("metrics", {}).is_empty(): status = "常驻效果"
		var note := _label(status, 12)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ring_content.add_child(note)

func scroll_by(amount: int) -> void:
	if scroll != null: scroll.scroll_vertical += amount
