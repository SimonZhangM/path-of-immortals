extends Control
## Read-only task presentation. Stage changes are supplied by the caller, never inferred from inventory.
const Tag = preload("res://scripts/map/map_task_category_tag.gd")
const HARMONY = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
const ART_SHADER = preload("res://scripts/map/map_task_detail_art.gdshader")
var artwork: TextureRect
var content: MarginContainer
var icon: TextureRect
var title_label: Label
var introduction: Label
var tag_slot: VBoxContainer
var category_tag: Control
var task_id := ""
var stage_id := ""

func _init() -> void:
	name = "TaskDetailHeader"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork = TextureRect.new()
	artwork.name = "TaskDetailArtwork"
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = ART_SHADER
	artwork.material = mask
	add_child(artwork)
	content = MarginContainer.new()
	content.name = "TaskDetailText"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: content.add_theme_constant_override("margin_" + edge, 36)
	for edge in ["top", "bottom"]: content.add_theme_constant_override("margin_" + edge, 32)
	add_child(content)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 24)
	content.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 18)
	column.add_child(heading)
	icon = TextureRect.new()
	icon.name = "TaskCategoryIcon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(icon)
	tag_slot = VBoxContainer.new()
	tag_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_slot.add_theme_constant_override("separation", 10)
	heading.add_child(tag_slot)
	title_label = _label("TaskDetailName", 32, Color("f0e6ce"))
	tag_slot.add_child(title_label)
	introduction = _label("TaskIntroduction", 22, Color("d8d4c7"))
	introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	introduction.add_theme_constant_override("line_spacing", 8)
	column.add_child(introduction)
	resized.connect(_layout)
	hide()

func show_entry(entry: Dictionary, category_texture: Texture2D, tags: Dictionary) -> void:
	if entry.is_empty() or str(entry.get("detail_image", "")).is_empty():
		clear_entry()
		return
	task_id = str(entry.id)
	stage_id = str(entry.get("stage_id", ""))
	var introductions: Dictionary = entry.get("introductions", {})
	introduction.text = str(introductions.get(stage_id, ""))
	title_label.text = str(entry.title)
	artwork.texture = load(str(entry.detail_image))
	icon.texture = category_texture
	if is_instance_valid(category_tag):
		tag_slot.remove_child(category_tag)
		category_tag.queue_free()
	var tag_style: Dictionary = tags.get(entry.category, {}).duplicate(true)
	tag_style.label = str(tag_style.get("label", "")) + "任务"
	category_tag = Tag.new(tag_style)
	category_tag.name = "TaskDetailCategory"
	category_tag.custom_minimum_size = Vector2(100, 30)
	category_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag_slot.add_child(category_tag)
	show()
	_layout()

func clear_entry() -> void:
	task_id = ""
	stage_id = ""
	introduction.text = ""
	hide()

func _layout() -> void:
	if size.x <= 0 or artwork.texture == null: return
	artwork.position = Vector2.ZERO
	artwork.size = Vector2(size.x, size.x / artwork.texture.get_size().aspect())
	var mask := artwork.material as ShaderMaterial
	mask.set_shader_parameter("panel_size", size)
	mask.set_shader_parameter("art_size", artwork.size)
	content.size = Vector2(size.x * 0.69, 0)

func _label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", HARMONY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
