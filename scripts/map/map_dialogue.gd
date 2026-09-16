class_name MapDialogue
extends Control

signal advance_requested

var background: TextureRect
var portrait: TextureRect
var text_label: Label
var picture: MapEventPicture
var _art: Dictionary = {}
var _textures: Dictionary = {}
var _pressed := false
var _press_position := Vector2.ZERO
var _dragged := false

func _init() -> void:
	name = "MapDialogue"
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	picture = MapEventPicture.new()
	add_child(picture)
	portrait = _image("SpeakerPortrait")
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var portrait_mask := ShaderMaterial.new()
	portrait_mask.shader = preload("res://scripts/ui/portrait_mask.gdshader")
	portrait.material = portrait_mask
	# The portrait overlaps the aperture slightly; draw the rim on top.
	background = _image("DialogueBackground")
	text_label = Label.new()
	text_label.name = "DialogueText"
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_color_override("font_color", Color("f0dfba"))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "Kaiti SC", "serif"])
	text_label.add_theme_font_override("font", font)
	add_child(text_label)
	resized.connect(_layout)

func _image(node_name: String) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(image)
	return image

func prepare(registry: MapEventRegistry) -> String:
	for event: Dictionary in registry.events.values():
		var textures: Dictionary = {}
		for key in ["background", "portrait"]:
			var texture := load(event.presentation[key]) as Texture2D
			var values: Array = event.presentation[key + "_region"]
			var region := Rect2(values[0], values[1], values[2], values[3])
			if texture == null or not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
				return "地图对话图片或裁切区域无效：" + key
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			textures[key] = atlas
		textures.speakers = {event.speaker_id: textures.portrait}
		for speaker_id in event.get("speakers", {}):
			var speaker: Dictionary = event.speakers[speaker_id]
			var texture := load(speaker.portrait) as Texture2D
			var values: Array = speaker.portrait_region
			var region := Rect2(values[0], values[1], values[2], values[3])
			if texture == null or not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
				return "地图说话者头像裁切区域无效：" + speaker_id
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			textures.speakers[speaker_id] = atlas
		if event.presentation.has("illustration"):
			var art: Dictionary = event.presentation.illustration
			var frame_texture := load(art.frame) as Texture2D
			var image_texture := load(art.image) as Texture2D
			var slot: Array = art.image_slot
			if frame_texture == null or image_texture == null or not Rect2(Vector2.ZERO, frame_texture.get_size()).encloses(Rect2(slot[0], slot[1], slot[2], slot[3])):
				return "地图事件插画窗口超出框架或图片无效。"
			textures.illustration_frame = frame_texture
			textures.illustration_image = image_texture
		_textures[event.id] = textures
	return ""

func present(event: Dictionary, line: String, speaker_id: String = "", phase: String = "dialogue") -> void:
	_art = event.presentation
	background.texture = _textures[event.id].background
	portrait.texture = _textures[event.id].speakers.get(speaker_id, _textures[event.id].portrait)
	text_label.text = line
	background.visible = phase == "dialogue"
	portrait.visible = phase == "dialogue"
	text_label.visible = phase == "dialogue"
	picture.visible = _art.has("illustration")
	if picture.visible:
		picture.configure(_textures[event.id].illustration_frame, _textures[event.id].illustration_image, _art.illustration.image_slot)
	show()
	_layout()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_dragged = false
			_press_position = event.position
		else:
			var clicked: bool = _pressed and not _dragged and event.position.distance_to(_press_position) <= 6.0
			_pressed = false
			if clicked:
				advance_requested.emit()
	elif event is InputEventMouseMotion and _pressed:
		_dragged = _dragged or event.position.distance_to(_press_position) > 6.0
	accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_pressed = false
		_dragged = false

func _layout() -> void:
	if _art.is_empty() or size.x <= 0 or size.y <= 0:
		return
	var source_size := background.texture.get_size()
	# Artwork shrinks to two thirds; text uses its own responsive size.
	var text_factor := minf(size.x * 0.88 / 1930.0, size.y * 0.34 / 371.0)
	var factor := minf(size.x * 0.88 / source_size.x, size.y * 0.34 / source_size.y) * 2.0 / 3.0
	background.size = source_size * factor
	background.position = Vector2(size.x * 0.5, size.y * 0.75) - background.size * 0.5
	if picture.visible:
		picture.layout_for(size, background.get_rect())
	var slot: Array = _art.portrait_slot
	var center := Vector2(slot[0] + slot[2] * 0.5, slot[1] + slot[3] * 0.5)
	var portrait_size := portrait.texture.get_size()
	portrait_size *= float(_art.portrait_max_size) / maxf(portrait_size.x, portrait_size.y)
	portrait.size = portrait_size * factor
	portrait.position = background.position + center * factor - portrait.size * 0.5
	portrait.material.set_shader_parameter("portrait_size", portrait.size)
	var text_rect: Array = _art.text_rect
	text_label.position = background.position + Vector2(text_rect[0], text_rect[1]) * factor
	text_label.add_theme_font_size_override("font_size", maxi(15, roundi(36.0 * text_factor) - 1))
	var text_size := Vector2(text_rect[2], text_rect[3]) * factor
	text_label.size = text_size
	# Label updates its wrapped minimum height after the new width/font is shaped.
	text_label.set_deferred("size", text_size)
