class_name MapStatusHeader
extends Control

const BASE_WIDTH := 1920.0
const LEFT_REGION := Rect2(7, 45, 887, 231)
const RIGHT_REGION := Rect2(695, 7, 1171, 689)
const LEFT_TIP := Vector2(803, 173.5)
const RIGHT_TIP := Vector2(14, 674)
const LEFT_SCALE := (887.0 * 0.64 - 5.0) / 887.0
# Preserve source aspect while narrowing by 5px, then move left5/down2.
const LEFT_ORIGIN := Vector2(-35.32, -19.12)
const CONNECTION_Y := LEFT_ORIGIN.y + LEFT_TIP.y * LEFT_SCALE
const RIGHT_TIP_Y := 89.92 + 1.0
const LINE_OVERLAP := 3.0
const LINE_COLOR := Color("d9bb72")
const LINE_WIDTH := 1.2
var state: MapPlayerStatus
var bars: Dictionary = {}
var values: Dictionary = {}
var hero_name: Label
var hero_rank: Label
var hero_age: Label
var identity_container: CenterContainer
var age_container: CenterContainer
var cultivation_caption: Label
var resource_row: HBoxContainer
var spirit_stones: Label
var experience: Label
var spirit_stones_value: Label
var experience_value: Label
var map_title: TextureRect
var content: Control
var left_art: TextureRect
var right_art: TextureRect
var background_art: TextureRect
var connection: Line2D
var fill: Polygon2D
var outline: PackedVector2Array
var settings_button: MapHeaderUtilityButton
var tasks_button: MapHeaderUtilityButton

func configure(status: MapPlayerStatus, config: Dictionary) -> String:
	state = status
	name = "MapStatusHeader"
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	fill = Polygon2D.new()
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_header_fill.gdshader")
	paint.set_shader_parameter("left_join_x", LEFT_ORIGIN.x + LEFT_REGION.size.x * LEFT_SCALE)
	fill.material = paint
	content.add_child(fill)
	var background_texture: Texture2D = load("res://assets/map-head.webp")
	background_art = _image("res://assets/map-head.webp", background_texture.get_image().get_used_rect())
	background_art.name = "HeaderBackgroundArtwork"
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.self_modulate.a = 0.3
	connection = Line2D.new()
	connection.default_color = LINE_COLOR
	connection.width = LINE_WIDTH
	connection.antialiased = true
	connection.gradient = Gradient.new()
	# Keep the hanging cord behind head3; the plaque stays fixed with the header.
	map_title = _image("res://assets/map-title-qshw.webp", Rect2(46, 0, 236, 1031))
	map_title.name = "MapTitle"
	map_title.position = Vector2(18, 128)
	map_title.size = Vector2(236, 1031) * 0.36
	map_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	left_art = _image("res://assets/map-head3.webp", LEFT_REGION)
	right_art = _image("res://assets/map-head2.webp", RIGHT_REGION)
	# Draw the continuous rule above both ornaments so head2 cannot cover its end.
	content.add_child(connection)
	var portrait_path: String = config.get("portrait", "")
	var region: Array = config.get("portrait_region", [])
	if region.size() != 4 or not ResourceLoader.exists(portrait_path, "Texture2D"):
		return "地图状态栏头像配置无效。"
	var portrait := _image(portrait_path, Rect2(region[0], region[1], region[2], region[3]))
	var portrait_group := Control.new()
	portrait_group.name = "PortraitGroup"
	portrait_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Scale the complete image/rim around the preceding rim's outer bottom-right.
	portrait_group.scale = Vector2.ONE * 1.05
	portrait_group.position = Vector2(176.1, 116.1) * (1.0 - 1.05) + Vector2(-4, 0)
	content.add_child(portrait_group)
	portrait.reparent(portrait_group, false)
	portrait.position = Vector2(78, 18)
	portrait.size = Vector2(96, 96)
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/ui/portrait_mask.gdshader")
	mask.set_shader_parameter("portrait_size", portrait.size)
	portrait.material = mask
	# Source ring center is (271, 300), independent of asymmetric source padding.
	# The centered square keeps both control centers aligned; portrait overlaps the rim.
	var rim := _image("res://assets/player-level-1.webp", Rect2(16, 45, 510, 510))
	rim.name = "PortraitFrame"
	rim.reparent(portrait_group, false)
	rim.size = Vector2.ONE * (510.0 * 48.0 / 216.0)
	rim.position = portrait.position + portrait.size * 0.5 - rim.size * 0.5
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Identity follows the supplied 301x91 reference at the 1920px design scale.
	# Name is calligraphic; rank and secondary details use a heavier Song serif.
	identity_container = _center_container("IdentityContainer", Rect2(178, 22, 320, 62))
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 18)
	identity_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_container.add_child(identity_row)
	hero_name = _label(48, Color("f9f6d3"), false)
	hero_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_row.add_child(hero_name)
	var name_font := FontVariation.new()
	name_font.base_font = hero_name.get_theme_font("font")
	name_font.variation_embolden = 0.4
	hero_name.add_theme_font_override("font", name_font)
	hero_rank = _label(25, Color("ece6b5"), false)
	identity_row.add_child(hero_rank)
	_identity_serif(hero_rank, 700)
	age_container = _center_container("AgeLifespanContainer", Rect2(186, 92, 244, 22))
	hero_age = _label(15, Color("d6d7d3"), false)
	age_container.add_child(hero_age)
	hero_age.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_identity_serif(hero_age, 600)
	var row := HBoxContainer.new()
	resource_row = row
	row.position = Vector2(560, (CONNECTION_Y - 45.0) * 0.5)
	row.size = Vector2(1140, 45)
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	var keys := ["hp", "stamina", "spirit", "cultivation"]
	var captions := ["气血", "体力", "灵力", "修为"]
	var colors := [Color("af3549"), Color("8cd259"), Color("5598eb"), Color("cfad66")]
	var icons := ["res://assets/player-status-health.webp", "res://assets/player-status-stamina.webp", "res://assets/player-status-spirit.webp", "res://assets/player-status-level.webp"]
	for i in keys.size():
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i == 3 else Control.SIZE_FILL
		column.custom_minimum_size.x = 232 if i < 3 else 0
		column.add_theme_constant_override("separation", 5)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(column)
		var caption_row := HBoxContainer.new()
		caption_row.custom_minimum_size.y = 27
		caption_row.add_theme_constant_override("separation", 7)
		caption_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption_row)
		if i < icons.size():
			var icon := TextureRect.new()
			var tex: Texture2D = load(icons[i])
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = tex.get_image().get_used_rect()
			icon.texture = atlas
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			icon.custom_minimum_size = Vector2(27, 27)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption_row.add_child(icon)
		var label := _label(22, Color("e4d8b9"), false)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = captions[i]
		if i == 3:
			cultivation_caption = label
		caption_row.add_child(label)
		var value := _label(20, colors[i].lightened(0.2), false)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption_row.add_child(value)
		values[keys[i]] = value
		var bar := ResourceBar.new()
		bar.tint = colors[i]
		bar.custom_minimum_size = Vector2(0, 13)
		column.add_child(bar)
		bars[keys[i]] = bar
	var counter_top := (CONNECTION_Y - 57.0) * 0.5
	spirit_stones = _label(20, Color("ece6b5"))
	spirit_stones.position = Vector2(1767, counter_top)
	spirit_stones.size = Vector2(40, 25)
	spirit_stones.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	experience = _label(20, Color("ece6b5"))
	experience.position = Vector2(1767, counter_top + 32)
	experience.size = Vector2(40, 25)
	experience.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spirit_stones_value = _counter_number(spirit_stones, "灵石  ")
	experience_value = _counter_number(experience, "历练  ")
	_counter_icon("res://assets/player-status-coin.webp", Vector2(1735, counter_top))
	_counter_icon("res://assets/player-status-exp.webp", Vector2(1735, counter_top + 32))
	settings_button = MapHeaderUtilityButton.new()
	settings_button.name = "SettingsButton"
	settings_button.position = Vector2(14, 48)
	settings_button.size = Vector2(36, 36)
	settings_button.configure(MapHeaderUtilityButton.Kind.SETTINGS, "设置（功能将在后续开放）")
	content.add_child(settings_button)
	tasks_button = MapHeaderUtilityButton.new()
	tasks_button.name = "TaskListButton"
	tasks_button.position = Vector2(1872, 12)
	tasks_button.size = Vector2(36, 36)
	tasks_button.configure(MapHeaderUtilityButton.Kind.TASKS, "任务列表（功能将在后续开放）")
	content.add_child(tasks_button)
	state.changed.connect(refresh)
	resized.connect(_layout)
	_layout()
	refresh()
	return ""

func refresh() -> void:
	hero_name.text = state.display_name
	hero_rank.text = state.rank_name
	hero_age.text = "年龄 %d岁  |  寿元 %d年" % [state.age, state.lifespan]
	spirit_stones.text = "灵石"
	experience.text = "历练"
	spirit_stones_value.text = str(state.spirit_stones)
	experience_value.text = str(state.experience)
	cultivation_caption.text = "修为 %d%%" % roundi(100.0 * state.cultivation_progress / state.cultivation_required)
	for key in bars:
		var maximum: int = state.cultivation_required if key == "cultivation" else state.maxima[key]
		var current: int = state.cultivation_progress if key == "cultivation" else state.resources[key]
		# Range treats a collapsed 0..0 interval as full; zero-capacity spirit must be empty.
		bars[key].max_value = maxi(1, maximum)
		bars[key].value = current
		values[key].text = "%d/%d" % [current, maximum]

func _layout() -> void:
	if content == null:
		return
	var zoom := size.x / BASE_WIDTH
	content.scale = Vector2.ONE * zoom
	content.size = Vector2(BASE_WIDTH, 155)
	var left_scale := LEFT_SCALE
	left_art.position = LEFT_ORIGIN
	left_art.size = LEFT_REGION.size * left_scale
	background_art.position = Vector2(left_art.get_rect().end.x, 0)
	background_art.size = Vector2(BASE_WIDTH - background_art.position.x, CONNECTION_Y)
	var start := left_art.position + LEFT_TIP * left_scale
	var right_scale := 43.0 / RIGHT_REGION.size.y
	right_art.size = RIGHT_REGION.size * right_scale
	right_art.position = Vector2(BASE_WIDTH - right_art.size.x + 1.0, RIGHT_TIP_Y - RIGHT_TIP.y * right_scale)
	var end := Vector2(BASE_WIDTH, start.y)
	var line_start := start - Vector2(LINE_OVERLAP, 0)
	# Line2D interpolates vertex colors, so give the short fade its own vertices.
	connection.points = PackedVector2Array([line_start, line_start + Vector2(12, 0), line_start + Vector2(64, 0), end])
	var line_length := end.x - connection.points[0].x
	connection.gradient.offsets = PackedFloat32Array([0.0, 12.0 / line_length, 64.0 / line_length, 1.0])
	# Assign colors after offsets: resizing/sorting Gradient points can reorder colors.
	var transparent_gold := connection.default_color
	transparent_gold.a = 0.0
	connection.gradient.colors = PackedColorArray([transparent_gold, transparent_gold, connection.default_color, connection.default_color])
	# Only source artwork may extend below the gold rule; never add a backing there.
	outline = PackedVector2Array([Vector2.ZERO, Vector2(BASE_WIDTH, 0), end, Vector2(0, start.y)])
	fill.polygon = outline
	var height := height_for_width(size.x)
	custom_minimum_size.y = height
	offset_bottom = height

static func height_for_width(width: float) -> float:
	return CONNECTION_Y * width / BASE_WIDTH

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(size.x, height_for_width(size.x))).has_point(point)

func _center_container(node_name: String, area: Rect2) -> CenterContainer:
	var container := CenterContainer.new()
	container.name = node_name
	container.position = area.position
	container.size = area.size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(container)
	return container

func _image(path: String, region: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = region
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rect)
	return rect

func _counter_number(caption: Label, previous_prefix: String) -> Label:
	var number := _label(20, Color("ece6b5"))
	var prefix_width := caption.get_theme_font("font").get_string_size(previous_prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	number.position = caption.position + Vector2(prefix_width + 15, 0)
	number.size = Vector2(40, 25)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return number

func _counter_icon(path: String, origin: Vector2) -> void:
	var texture: Texture2D = load(path)
	var icon := _image(path, texture.get_image().get_used_rect())
	icon.position = origin
	icon.size = Vector2(25, 25)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _identity_serif(label: Label, weight: int) -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Serif SC", "Source Han Serif SC", "SimSun", "宋体", "serif"])
	font.font_weight = weight
	label.add_theme_font_override("font", font)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _label(font_size: int, color: Color, attach: bool = true) -> Label:
	var label := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if attach:
		content.add_child(label)
	return label
