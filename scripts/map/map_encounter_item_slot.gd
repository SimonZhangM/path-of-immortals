class_name MapEncounterItemSlot
extends Panel

var item: ItemData

func _init() -> void:
	# Match inventory/battle tooltips: the custom item panel draws its own frame.
	# Otherwise Godot adds a second TooltipPanel with a drop shadow behind it.
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())

func show_item(definition: ItemData) -> void:
	item = definition
	for child in get_children(): child.queue_free()
	tooltip_text = definition.display_name if definition != null else ""
	if definition == null: return
	var art := TextureRect.new()
	art.texture = load(definition.icon_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	art.offset_left = 4
	art.offset_top = 4
	art.offset_right = -4
	art.offset_bottom = -4

func _make_custom_tooltip(_text: String) -> Object:
	if item == null: return null
	var popup := ItemTooltip.new()
	popup.configure(item)
	return popup
