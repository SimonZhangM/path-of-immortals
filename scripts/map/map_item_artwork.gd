class_name MapItemArtwork
extends TextureRect

const TextureMetrics = preload("res://scripts/map/map_texture_metrics.gd")

const GLOW_SHADER = preload("res://scripts/map/map_item_glow.gdshader")
# Presentation palette keyed by quality, independent of enhancement level.
# Only 下品 is currently authored; unknown qualities use the neutral fallback.
const QUALITY_GLOW_COLORS := {"下品": Color("b4c6dc")}
const OUTLINE_COLOR := Color("151515")
const OUTLINE_SCREEN_WIDTH := 0.5
var _outline_layers: Array[TextureRect] = []
var _outline_basis := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

func _ready() -> void:
	set_notify_transform(true)
	get_viewport().size_changed.connect(_update_outline_offsets)
	_update_outline_offsets()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_outline_offsets()

func _update_outline_offsets() -> void:
	if _outline_layers.is_empty() or not is_inside_tree():
		return
	var screen := get_screen_transform()
	# Translation changes during dragging do not change the outline radius.
	if screen.x == _outline_basis.x and screen.y == _outline_basis.y:
		return
	if is_zero_approx(screen.determinant()):
		return
	_outline_basis = screen
	var inverse := screen.affine_inverse()
	for step in _outline_layers.size():
		var offset := inverse.basis_xform(Vector2.from_angle(TAU * step / 16.0) * OUTLINE_SCREEN_WIDTH)
		var layer := _outline_layers[step]
		layer.offset_left = offset.x
		layer.offset_right = offset.x
		layer.offset_top = offset.y
		layer.offset_bottom = offset.y

static func battle_record(game: GameManager, item: ItemData) -> Dictionary:
	if game._durable_loadout != null and game._durable_loadout.records.has(item.id):
		return game._durable_loadout.records[item.id]
	return {"icon": item.icon_path, "name": item.display_name, "quality": item.quality, "art_outline_px": int(item.combat.get("art_outline_px", 0))}

func place_on_board(footprint: Rect2, enlargement: float = 1.0) -> void:
	var rect := ItemDragPreview.artwork_rect(footprint)
	size = rect.size * enlargement
	position = rect.get_center() - size * 0.5
	center_visible_at(rect.get_center())

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
		trimmed.region = TextureMetrics.inspect(source).used_rect
		texture = trimmed
		outline_source = trimmed
	else:
		var caption := Label.new()
		caption.name = "ItemNameWithoutImage"
		caption.text = record.get("name", "")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", 22)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# Positive legacy widths opt in; presentation now uses one screen-space
	# half-pixel ring, independent of card/board scale and artwork rotation.
	for step in 16:
		var layer := TextureRect.new()
		layer.texture = source
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer.self_modulate = OUTLINE_COLOR
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_outline_layers.append(layer)
	_outline_basis = Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_update_outline_offsets()

func apply_inventory_pose(record: Dictionary) -> void:
	if texture == null:
		return
	var center := position + size * 0.5
	var source_size := texture.get_size()
	var one_cell := int(record.get("footprint_columns", 1)) == 1 and int(record.get("footprint_rows", 1)) == 1
	var horizontal_weapon: bool = record.category == "weapon" and not one_cell and source_size.x > source_size.y
	if horizontal_weapon:
		size = Vector2(size.y, size.x)
		rotation = PI * 0.5
	pivot_offset = size * 0.5
	position = center - size * 0.5
	var fitted := source_size * minf(size.x / source_size.x, size.y / source_size.y)
	var visible_height := fitted.x if horizontal_weapon else fitted.y
	var columns := int(record.get("footprint_columns", 1))
	var rows := int(record.get("footprint_rows", 1))
	var enlargement := 1.0
	if mini(columns, rows) == 1:
		match maxi(columns, rows):
			2: enlargement = 1.1
			3: enlargement = 1.2
	# Keep the visible artwork's bottom fixed while growing around its center.
	scale = Vector2.ONE * enlargement
	position.y -= visible_height * (enlargement - 1.0) * 0.5

func center_visible_horizontally(center_x: float) -> void:
	position.x += center_x - (get_transform() * _visible_local_center()).x

func center_visible_at(center: Vector2) -> void:
	position += center - get_transform() * _visible_local_center(true)

func _visible_local_center(optical: bool = false) -> Vector2:
	var local_center := size * 0.5
	if texture is AtlasTexture:
		var metrics := TextureMetrics.inspect(texture.atlas)
		var visible := Rect2(metrics.visible_rect)
		var source_center := TextureMetrics.alignment_center(texture.atlas) if optical else visible.get_center()
		var fitted_scale := minf(size.x / texture.get_width(), size.y / texture.get_height())
		local_center += (source_center - texture.region.get_center()) * fitted_scale
	return local_center
