class_name MapItemArtwork
extends TextureRect

const GLOW_SHADER = preload("res://scripts/map/map_item_glow.gdshader")
# Presentation palette keyed by quality, independent of enhancement level.
# Only 下品 is currently authored; unknown qualities use the neutral fallback.
const QUALITY_GLOW_COLORS := {"下品": Color("b4c6dc")}
const OUTLINE_COLOR := Color("151515")

func configure(record: Dictionary, storage_quality_glow: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var outline_source: Texture2D
	var path: String = record.get("icon", "")
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		var source: Texture2D = load(path)
		var trimmed := AtlasTexture.new()
		trimmed.atlas = source
		trimmed.region = source.get_image().get_used_rect()
		texture = trimmed
		outline_source = trimmed
	var glow := ColorRect.new()
	glow.name = "ItemGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	var shader_material := ShaderMaterial.new()
	shader_material.shader = GLOW_SHADER
	glow.material = shader_material
	add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if storage_quality_glow:
		var tint: Color = QUALITY_GLOW_COLORS.get(record.get("quality", ""), Color("b4c6dc"))
		tint.a = 0.24
		shader_material.set_shader_parameter("glow_color", tint)
		shader_material.set_shader_parameter("inner_radius", 0.18)
		shader_material.set_shader_parameter("falloff_power", 1.4)
		# A square behind the icon yields a true circular wash. The whole
		# outer rim reaches zero alpha before it can touch the card text/frame.
		glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		glow.offset_left = -68
		glow.offset_top = -68
		glow.offset_right = 68
		glow.offset_bottom = 68
	if outline_source != null:
		_add_outline(outline_source, int(record.get("art_outline_px", 0)))

func _add_outline(source: Texture2D, width: int) -> void:
	if width <= 0:
		return
	var outline := Control.new()
	outline.name = "ItemOutline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.show_behind_parent = true
	add_child(outline)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Two concentric rings with fractional directions form a smooth rounded
	# silhouette while keeping the requested width in design pixels.
	for radius in range(1, width + 1):
		for step in 16:
			var offset := Vector2.from_angle(TAU * step / 16.0) * radius
			var layer := TextureRect.new()
			layer.texture = source
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			layer.self_modulate = OUTLINE_COLOR
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			outline.add_child(layer)
			layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			layer.offset_left += offset.x
			layer.offset_right += offset.x
			layer.offset_top += offset.y
			layer.offset_bottom += offset.y
