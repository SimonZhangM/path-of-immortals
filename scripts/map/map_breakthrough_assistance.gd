extends VBoxContainer
## Story assistance is display content; it does not grant items or numeric bonuses.
const FONT = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
const METRICS = preload("res://scripts/map/map_texture_metrics.gd")
var artwork_layer: Node2D
var rows: Array[HBoxContainer] = []
var icons: Array[TextureRect] = []
var categories: Array[Label] = []
var names: Array[Label] = []
var descriptions: Array[Label] = []

func _init() -> void:
	name = "AssistanceCards"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Separate artwork from row layout so every visible icon matches its frame.
	artwork_layer = Node2D.new()
	artwork_layer.name = "CenteredArtwork"
	add_child(artwork_layer)

func configure(config: Dictionary, registry: ContentRegistry) -> void:
	if not rows.is_empty(): return
	position = Vector2(config.rect[0],config.rect[1])
	size = Vector2(config.rect[2],config.rect[3])
	add_theme_constant_override("separation",int(config.row_gap))
	for entry: Dictionary in config.entries:
		var row := HBoxContainer.new()
		row.name = entry.id.get_slice(".",2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size = Vector2(size.x,config.row_height)
		row.add_theme_constant_override("separation",int(config.icon_text_gap))
		add_child(row)
		rows.append(row)
		var well := MarginContainer.new()
		well.custom_minimum_size = Vector2(config.icon_side,config.icon_side)
		well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for edge in ["left","right","top","bottom"]:
			well.add_theme_constant_override("margin_"+edge,4)
		row.add_child(well)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var icon_path := String(entry.get("icon",""))
		if entry.has("item_id"):
			var item := registry.get_item(entry.item_id)
			if item!=null: icon_path = item.icon_path
		var source: Texture2D = load(icon_path)
		var bounds := Rect2(METRICS.inspect(source).visible_rect)
		var trimmed := AtlasTexture.new()
		trimmed.atlas = source
		trimmed.region = bounds
		icon.texture = trimmed
		var factor: float = minf(float(config.icon_side-8)/source.get_width(),float(config.icon_side-8)/source.get_height())
		icon.size = bounds.size*factor
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if entry.has("frame_fill_size"):
			icon.size = Vector2(entry.frame_fill_size[0],entry.frame_fill_size[1])
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			var paint := ShaderMaterial.new()
			paint.shader = preload("res://scripts/map/map_breakthrough_portrait.gdshader")
			paint.set_shader_parameter("frame_size",icon.size)
			paint.set_shader_parameter("image_size",bounds.size)
			paint.set_shader_parameter("uv_origin",bounds.position/source.get_size())
			paint.set_shader_parameter("uv_size",bounds.size/source.get_size())
			paint.set_shader_parameter("image_zoom",float(entry.image_zoom))
			paint.set_shader_parameter("corner_cut",float(entry.corner_cut))
			icon.material = paint
		var center: Array = config.icon_centers[rows.size()-1]
		icon.position = Vector2(center[0],center[1])-position-icon.size*0.5
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork_layer.add_child(icon)
		icons.append(icon)
		var text := Control.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		categories.append(_label(text,"Category",entry.category,28,38,Color("e8ca79")))
		var title := _label(text,"Name",entry.name,28,40,Color("e8e1d0"))
		var description := _label(text,"Description",entry.description,22,38,Color("c7d4dc"))
		var divider: float = config.divider_ys[rows.size()-1]-position.y-(rows.size()-1)*(config.row_height+config.row_gap)
		var gap: float = config.divider_text_gap
		# Place glyph ink, rather than differently sized Label boxes, around the
		# existing blue line. All three rows use the same upper/lower distance.
		title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		title.position.y = divider-gap-_ink_bounds(entry.name,28).y
		description.position.y = divider+gap-_ink_bounds(entry.description,22).x+float(config.description_baseline_correction)
		names.append(title)
		descriptions.append(description)

func _ink_bounds(value: String, font_size: int) -> Vector2:
	FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var server := TextServerManager.get_primary_interface()
	var font_rid: RID = FONT.get_rids()[0]
	var raster_size := Vector2i(font_size,0)
	var atlases := {}
	var top := INF
	var bottom := -INF
	for index in value.length():
		var glyph := server.font_get_glyph_index(font_rid,font_size,value.unicode_at(index),0)
		var offset := server.font_get_glyph_offset(font_rid,raster_size,glyph)
		var uv := server.font_get_glyph_uv_rect(font_rid,raster_size,glyph)
		if not uv.has_area(): continue
		var texture_index := server.font_get_glyph_texture_idx(font_rid,raster_size,glyph)
		if not atlases.has(texture_index):
			atlases[texture_index] = server.font_get_texture_image(font_rid,raster_size,texture_index)
		var image: Image = atlases[texture_index].get_region(Rect2i(uv))
		var ink := METRICS._visible_rect(image,image.get_used_rect(),0.5)
		# Font atlas padding is transparent and must not count as text spacing.
		top = minf(top,offset.y+ink.position.y)
		bottom = maxf(bottom,offset.y+ink.end.y)
	return Vector2(top,bottom)+Vector2.ONE*FONT.get_ascent(font_size) if is_finite(top) else Vector2.ZERO

func _label(parent: Control, node_name: String, value: String, font_size: int, height: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.custom_minimum_size.y = height
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	label.anchor_right = 1.0
	return label
