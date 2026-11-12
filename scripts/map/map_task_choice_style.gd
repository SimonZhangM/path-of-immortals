extends RefCounted
## Shared artwork and placement for task choices.
const ART = preload("res://assets/UI-button-choice.webp")
const FONT = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
const DEFAULT_SIZE := Vector2(240, 240.0 * 131.0 / 297.0)
const PICTURE_WIDTH_RATIO := 0.238
const PICTURE_GAP_RATIO := 0.06
const ART_BOTTOM_TIP := 116.0 / 131.0

static func apply(button: Button) -> void:
	button.custom_minimum_size = DEFAULT_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = ART
		if style_name == "hover":
			style.modulate_color = Color(1.15, 1.15, 1.15)
		elif style_name == "pressed":
			style.modulate_color = Color(0.85, 0.85, 0.85)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 0
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(style_name, style)

static func layout(row: HBoxContainer, map: Control) -> void:
	var factor := minf(map.size.x / 1920.0, map.size.y / 1080.0)
	var picture: MapEventPicture = map.dialogue.picture
	var on_picture: bool = picture.requested_visible and map.event_state.phase != "reward"
	var button_size := DEFAULT_SIZE
	var gap := 60.0
	if on_picture:
		button_size.x = picture.size.x * PICTURE_WIDTH_RATIO / factor
		button_size.y = button_size.x * ART.get_height() / ART.get_width()
		gap = picture.size.x * PICTURE_GAP_RATIO / factor
	for button: Button in row.get_children():
		button.custom_minimum_size = button_size
	row.add_theme_constant_override("separation", roundi(gap))
	row.scale = Vector2.ONE * factor
	row.size = row.get_combined_minimum_size()
	var top: float = map.dialogue.background.position.y - (row.size.y + 20) * factor
	if on_picture:
		# Align each lower gold tip with the picture frame's lower edge.
		top = picture.position.y + picture.size.y - row.size.y * factor * ART_BOTTOM_TIP
	elif map.event_state.phase == "reward":
		top = map.size.y * 0.73
	row.position = Vector2((map.size.x - row.size.x * factor) * 0.5, maxf(100 * factor, top))

static func apply_confirmation(dialog: Control) -> void:
	for button: TextureButton in [dialog.confirm_button, dialog.cancel_button]:
		button.texture_normal = ART
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var width := button.custom_minimum_size.x
		button.custom_minimum_size = Vector2(width, width * ART.get_height() / ART.get_width())
		var caption: Label = button.get_node("Caption")
		caption.add_theme_font_override("font", FONT)
		caption.offset_top = -5
		caption.offset_bottom = -5
