class_name MapItemArtwork
extends TextureRect

const GLOW_SHADER = preload("res://scripts/map/map_item_glow.gdshader")

func configure(record: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = record.get("icon", "")
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		var source: Texture2D = load(path)
		var trimmed := AtlasTexture.new()
		trimmed.atlas = source
		trimmed.region = source.get_image().get_used_rect()
		texture = trimmed
	var glow := ColorRect.new()
	glow.name = "ItemGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	var shader_material := ShaderMaterial.new()
	shader_material.shader = GLOW_SHADER
	glow.material = shader_material
	add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
