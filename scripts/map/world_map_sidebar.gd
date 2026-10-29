extends Control

# All coordinates match the supplied frame; the parent scales it as one panel.
const GOLD := Color("ecd086")
const INK := Color("e2dac6")
var location_name: Label
var location_title: TextureRect
var phrase: Label
var picture: TextureRect
var description: Label
var region_name: Label
var connections: Label
var region_description: Label
var progress: ProgressBar
var percentage: Label
var _pictures: Dictionary = {}
var _titles: Dictionary = {}

func _init() -> void:
	name = "LocationDetails"
	mouse_filter = MOUSE_FILTER_IGNORE
	position = Vector2(1908,116)
	size = Vector2(442,1250)
	var song := SystemFont.new()
	song.font_names = PackedStringArray(["SimSun","宋体","Noto Serif CJK SC","serif"])
	var regular: Font = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
	location_name = _label("LocationName",Rect2(22,17,398,72),song,48,GOLD)
	location_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_title = TextureRect.new()
	location_title.name = "LocationTitleArt"
	location_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	location_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	location_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(location_title)
	phrase = _label("LocationPhrase",Rect2(14,95,414,36),regular,22,INK)
	phrase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picture = TextureRect.new()
	picture.name = "LocationPicture"
	picture.position = Vector2(4,132)
	picture.size = Vector2(434,245)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	var fade := ShaderMaterial.new()
	fade.shader = preload("res://scripts/map/world_map_scene_fade.gdshader")
	fade.set_shader_parameter("edge_fraction",0.1)
	picture.material = fade
	add_child(picture)
	description = _label("LocationDescription",Rect2(22,387,398,91),regular,22,INK,true)
	description.add_theme_constant_override("line_spacing",3)
	var heading_font := FontVariation.new()
	heading_font.base_font = song
	heading_font.variation_embolden = 0.6
	_label("RegionHeading",Rect2(26,529,390,52),heading_font,34,GOLD).text = "区域信息"
	var labels := ["当前区域","相连区域","探索进度","区域简介"]
	var line_height := regular.get_height(22)
	var first_line_y := 589.0+(50.0-line_height)*0.5
	for index in labels.size():
		var label := _label("RegionLabel%d" % index,Rect2(74,first_line_y+index*62,99,line_height),regular,22,INK)
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.text = labels[index]
	region_name = _label("RegionName",Rect2(196,first_line_y,222,line_height),regular,22,INK)
	region_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	connections = _label("ConnectedRegions",Rect2(196,first_line_y+62,222,line_height),regular,22,INK,true)
	connections.add_theme_constant_override("line_spacing",0)
	connections.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var progress_row := HBoxContainer.new()
	progress_row.position = Vector2(196,first_line_y+124)
	progress_row.size = Vector2(222,line_height)
	progress_row.add_theme_constant_override("separation",8)
	progress_row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(progress_row)
	progress = ProgressBar.new()
	progress.name = "ExplorationProgress"
	progress.show_percentage = false
	progress.step = 0.0
	progress.max_value = 1.0
	progress.custom_minimum_size = Vector2(0,14)
	progress.size_flags_horizontal = SIZE_EXPAND_FILL
	progress.size_flags_vertical = SIZE_SHRINK_CENTER
	progress.mouse_filter = MOUSE_FILTER_IGNORE
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color("111d23")
	trough.border_color = Color("967d45")
	trough.set_border_width_all(1)
	trough.set_corner_radius_all(7)
	progress.add_theme_stylebox_override("background",trough)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("46b5bd")
	fill.border_color = Color("8ed0c8")
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(7)
	progress.add_theme_stylebox_override("fill",fill)
	progress_row.add_child(progress)
	percentage = _label("ExplorationPercent",Rect2(),regular,22,INK)
	remove_child(percentage)
	progress_row.add_child(percentage)
	percentage.custom_minimum_size.x = 66
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percentage.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	region_description = _label("RegionDescription",Rect2(196,first_line_y+186,222,130),regular,22,INK,true)
	region_description.add_theme_constant_override("line_spacing",0)
	_build_legend(heading_font,regular)

func _build_legend(heading_font: Font, regular: Font) -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/world_map_legend.json"))
	_label("LegendHeading",_frame_rect(layout.heading_rect),heading_font,34,GOLD).text = layout.heading
	for entry: Dictionary in layout.entries:
		if entry.has("icon_backdrop_region"):
			# Cover the baked icon using adjacent empty frame art without editing the source.
			var region: Array = entry.icon_backdrop_region
			var backdrop_texture := AtlasTexture.new()
			backdrop_texture.atlas = preload("res://assets/map-worldmap-frame.webp")
			backdrop_texture.region = Rect2(region[0],region[1],region[2],region[3])
			var backdrop := TextureRect.new()
			backdrop.name = "LegendBackdrop_"+entry.id
			backdrop.texture = backdrop_texture
			backdrop.mouse_filter = MOUSE_FILTER_IGNORE
			backdrop.size = backdrop_texture.region.size
			backdrop.position = Vector2(entry.icon_center[0],entry.icon_center[1])-position-backdrop.size*0.5
			add_child(backdrop)
		var texture := AtlasTexture.new()
		texture.atlas = load(entry.icon_texture)
		texture.region = texture.atlas.get_image().get_used_rect()
		var icon := TextureRect.new()
		icon.name = "LegendIcon_"+entry.id
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		icon.size = texture.region.size*(float(entry.icon_width)/texture.region.size.x)
		icon.position = Vector2(entry.icon_center[0],entry.icon_center[1])-position-icon.size*0.5
		add_child(icon)
		var label := _label("Legend_"+entry.id,_frame_rect(entry.label_rect),regular,22,INK)
		label.text = entry.name
		var ink := preload("res://scripts/ui/cooldown_ring.gd").ink_vertical_bounds(regular,entry.name,22)
		label.position.y += regular.get_height(22)*0.5-regular.get_ascent(22)-(ink.x+ink.y)*0.5

func _frame_rect(values: Array) -> Rect2:
	return Rect2(Vector2(values[0],values[1])-position,Vector2(values[2],values[3]))

func _label(node_name: String, rect: Rect2, font: Font, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func display(location: Dictionary, region: Dictionary, counts: Dictionary) -> void:
	location_name.text = location.name
	_display_title(location.get("title_image",""))
	phrase.text = location.phrase
	description.text = location.description
	var path: String = location.picture
	if not _pictures.has(path): _pictures[path] = load(path)
	picture.texture = _pictures[path]
	region_name.text = region.name
	connections.text = "、".join(region.connected_regions)
	region_description.text = region.get("compact_description",region.description)
	progress.value = counts.ratio
	percentage.text = "%.1f%%" % (counts.ratio*100.0) if counts.total > 0 else "—"

func _display_title(path: String) -> void:
	location_name.visible = path.is_empty()
	location_title.visible = not path.is_empty()
	if path.is_empty():
		location_title.texture = null
		return
	if not _titles.has(path):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(path)
		atlas.region = atlas.atlas.get_image().get_used_rect()
		_titles[path] = atlas
	var texture: AtlasTexture = _titles[path]
	location_title.texture = texture
	var factor := minf(64.0/texture.region.size.y,330.0/texture.region.size.x)
	location_title.size = texture.region.size*factor
	location_title.position = location_name.get_rect().get_center()-location_title.size*0.5
