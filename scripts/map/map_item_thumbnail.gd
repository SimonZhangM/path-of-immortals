class_name MapItemThumbnail
extends RefCounted

static func create(parent: Node, record: Dictionary, edge: float, height: float = -1, artwork_scale: float = 1.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(edge,height if height > 0 else edge)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := StyleBoxEmpty.new()
	inset.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel",inset)
	parent.add_child(panel)
	# Use the card's authored quality texture and rounded-border shader, not a flat substitute.
	var layer := Node2D.new()
	panel.add_child(layer)
	var backing := TextureRect.new()
	backing.name = "QualityBackground"
	backing.texture = load(MapItemQuality.background_path(record.get("quality","下品")))
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_item_card_background.gdshader")
	paint.set_shader_parameter("corner_radius",4.0)
	paint.set_shader_parameter("line_width",1.0)
	paint.set_shader_parameter("line_color",Color.from_string(record.get("card_border_color",""),MapItemQuality.color(record.get("quality","下品"))))
	backing.material = paint
	layer.add_child(backing)
	var layout_backing := func():
		backing.size = panel.size
		var region := MapInventoryItemCard.BACKGROUND_INTERIOR
		var aspect := panel.size.x / maxf(panel.size.y,1)
		var covered := Vector2(region.size.x,minf(region.size.y,region.size.x / aspect))
		covered.x = covered.y * aspect
		region.position += (region.size-covered)*0.5
		region.size = covered
		paint.set_shader_parameter("panel_size",panel.size)
		paint.set_shader_parameter("source_region",Vector4(region.position.x/backing.texture.get_width(),region.position.y/backing.texture.get_height(),region.size.x/backing.texture.get_width(),region.size.y/backing.texture.get_height()))
	panel.resized.connect(layout_backing)
	layout_backing.call_deferred()
	var art := MapItemArtwork.new()
	art.configure(record)
	if is_equal_approx(artwork_scale,1.0):
		panel.add_child(art)
	else:
		# Inset only the item body; the quality backing and its border stay fixed.
		var area := Control.new()
		area.name = "ItemBodyArea"
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(area)
		area.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var inset_ratio := (1.0-artwork_scale)*0.5
		art.anchor_left = inset_ratio
		art.anchor_top = inset_ratio
		art.anchor_right = 1.0-inset_ratio
		art.anchor_bottom = 1.0-inset_ratio
	return panel
