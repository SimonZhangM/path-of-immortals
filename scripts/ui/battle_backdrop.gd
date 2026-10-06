extends TextureRect

func _ready() -> void:
	if texture == null:
		texture = preload("res://assets/backgroundtest.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus := ShaderMaterial.new()
	focus.shader = preload("res://scripts/ui/battle_focus.gdshader")
	material = focus
	resized.connect(func(): focus.set_shader_parameter("layout_size", size))
	focus.set_shader_parameter("layout_size", size)

func set_board_regions(ally: Rect2, enemy: Rect2) -> void:
	var focus := material as ShaderMaterial
	focus.set_shader_parameter("ally_board", Vector4(ally.position.x, ally.position.y, ally.size.x, ally.size.y))
	focus.set_shader_parameter("enemy_board", Vector4(enemy.position.x, enemy.position.y, enemy.size.x, enemy.size.y))
