extends RefCounted
## The same cropped artwork and existing independent rim for all small item tiles.
static func cover_region(texture_size: Vector2, panel_size: Vector2) -> Vector4:
	var region := Rect2(Vector2.ZERO,texture_size)
	var ratio := panel_size.x / maxf(panel_size.y,1)
	if texture_size.x / texture_size.y < ratio:
		region.size.y = texture_size.x / maxf(ratio,0.001)
	else:
		region.size.x = texture_size.y * ratio
	region.position = (texture_size-region.size)*0.5
	return Vector4(region.position.x/texture_size.x,region.position.y/texture_size.y,region.size.x/texture_size.x,region.size.y/texture_size.y)

static func create(parent: Control, record: Dictionary, border: Color, radius := 4.0, line_width := 1.0) -> TextureRect:
	# Keep the background out of Container sizing and behind item art/counts.
	var layer := Node2D.new()
	parent.add_child(layer)
	var backing := TextureRect.new()
	backing.name = "QualityBackground"
	backing.texture = load(MapItemQuality.small_background_path(record))
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_item_card_background.gdshader")
	paint.set_shader_parameter("corner_radius",radius)
	paint.set_shader_parameter("line_width",line_width)
	paint.set_shader_parameter("line_color",border)
	backing.material = paint
	layer.add_child(backing)
	var parent_ref: WeakRef = weakref(parent)
	var backing_ref: WeakRef = weakref(backing)
	var layout := func():
		var panel: Control = parent_ref.get_ref()
		var target: TextureRect = backing_ref.get_ref()
		if panel==null or target==null: return
		target.size = panel.size
		paint.set_shader_parameter("panel_size",panel.size)
		paint.set_shader_parameter("source_region",cover_region(target.texture.get_size(),panel.size))
	parent.resized.connect(layout)
	layout.call_deferred()
	return backing
