class_name MapDialogue
extends Control

signal advance_requested

const PLAYER_FRAMES = preload("res://scripts/presentation/player_portrait_frames.gd")
const Settings = preload("res://scripts/settings/game_settings.gd")
const Illustration = preload("res://scripts/dialogue/dialogue_illustration.gd")
const Playback = preload("res://scripts/dialogue/dialogue_playback.gd")
var player_status: MapPlayerStatus
var playback := Playback.new()
var _phase := ""

var background: TextureRect
var portrait: TextureRect
var portrait_rim: TextureRect
var _player_rim := false
var _body_mask: ShaderMaterial
var text_label: RichTextLabel
var speaker_name: Label
var next_marker: TextureRect
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
	picture.layout_changed.connect(_layout)
	picture.dismissed.connect(func():
		if _phase.is_empty(): hide())
	portrait = _image("SpeakerPortrait")
	portrait.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var portrait_mask := ShaderMaterial.new()
	portrait_mask.shader = preload("res://scripts/ui/portrait_mask.gdshader")
	portrait.material = portrait_mask
	# The portrait overlaps the aperture slightly; draw the rim on top.
	background = _image("DialogueBackground")
	_body_mask = ShaderMaterial.new()
	_body_mask.shader = preload("res://scripts/ui/dialogue_body_mask.gdshader")
	portrait_rim = _image("SpeakerPortraitFrame")
	text_label = RichTextLabel.new()
	text_label.name = "DialogueText"
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.scroll_active = false
	text_label.add_theme_color_override("default_color", Color.WHITE)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "Kaiti SC", "serif"])
	text_label.add_theme_font_override("normal_font", font)
	var bold_font := SystemFont.new()
	bold_font.font_names = font.font_names
	bold_font.font_weight = 700
	text_label.add_theme_font_override("bold_font", bold_font)
	add_child(text_label)
	speaker_name = Label.new()
	speaker_name.name = "SpeakerName"
	speaker_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_name.add_theme_font_override("font", font)
	speaker_name.add_theme_color_override("font_color", Color.WHITE)
	add_child(speaker_name)
	next_marker = _image("NextMarker")
	resized.connect(_layout)

func _image(node_name: String) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(image)
	return image

func prepare(registry: MapEventRegistry) -> String:
	for event: Dictionary in registry.events.values():
		if event.type != "dialogue":
			continue
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
		if event.presentation.has("next_image"):
			textures.next_marker = load(event.presentation.next_image)
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
		var art := Illustration.art_for(event)
		if not art.is_empty():
			var sequence_error := Illustration.sequence_error(art,event.lines.size())
			if not sequence_error.is_empty(): return sequence_error
			var frame_texture := load(art.frame) as Texture2D
			if art.has("frame_region"):
				var crop: Array = art.frame_region
				var frame_atlas := AtlasTexture.new()
				frame_atlas.atlas = frame_texture
				frame_atlas.region = Rect2(crop[0], crop[1], crop[2], crop[3])
				frame_texture = frame_atlas
			var images: Array = []
			for page: Dictionary in art.get("pages",[{"image":art.get("image","")}]):
				var image_texture := load(page.image) as Texture2D
				if image_texture == null: return "剧情场景图片无效。"
				images.append(image_texture)
			var slot: Array = art.image_slot
			if frame_texture == null or not Rect2(Vector2.ZERO, frame_texture.get_size()).encloses(Rect2(slot[0], slot[1], slot[2], slot[3])):
				return "地图事件插画窗口超出框架或图片无效。"
			textures.illustration_frame = frame_texture
			textures.illustration_images = images
		_textures[event.id] = textures
	return ""

func present(event: Dictionary, line: String, speaker_id: String = "", phase: String = "dialogue", line_index: int = 0) -> void:
	_phase = phase
	mouse_filter = Control.MOUSE_FILTER_STOP
	var art := Illustration.art_for(event)
	var page := Illustration.page_at(art,line_index)
	var page_text: String = art.get("page_text", "")
	var page_dialogue := phase=="illustration" and page>=0 and not page_text.is_empty()
	var show_dialogue := phase in ["dialogue","dialogue_paused"] or page_dialogue
	_art = event.presentation
	portrait_rim.texture = null
	_player_rim = false
	background.texture = _textures[event.id].background
	portrait.texture = _textures[event.id].speakers.get(speaker_id, _textures[event.id].portrait)
	var resolved_speaker: String = event.speaker_id if speaker_id.is_empty() else speaker_id
	if player_status != null and resolved_speaker == "base.map_player.chen_yu":
		portrait.texture = PLAYER_FRAMES.portrait_for(player_status.cultivation_rank_id)
		speaker_name.text = player_status.display_name
		if _art.get("speaker_rims",false):
			portrait_rim.texture = load(PLAYER_FRAMES.path_for(player_status.cultivation_rank_id))
			_player_rim = true
	else:
		var speaker: Dictionary = event.get("speakers", {}).get(resolved_speaker, {})
		speaker_name.text = speaker.get("name", event.get("speaker_name", ""))
		if _art.get("speaker_rims",false) and speaker.has("portrait_frame"):
			portrait_rim.texture = load(speaker.portrait_frame)
	background.material = _body_mask if portrait_rim.texture!=null else null
	portrait_rim.visible = show_dialogue and portrait_rim.texture!=null
	next_marker.texture = _textures[event.id].get("next_marker")
	# A gallery caption is fully visible and never starts ordinary auto playback.
	set_line_text(page_text if page_dialogue else line,phase=="dialogue")
	background.visible = show_dialogue
	portrait.visible = show_dialogue
	text_label.visible = show_dialogue
	speaker_name.visible = show_dialogue and _art.has("name_rect")
	next_marker.visible = phase == "dialogue" and next_marker.texture != null
	var show_picture: bool = not art.is_empty() and (page>=0 if art.has("pages") else line_index>=int(art.get("start_line",0)))
	if show_picture:
		picture.configure(_textures[event.id].illustration_frame, _textures[event.id].illustration_images[maxi(0,page)], art.image_slot)
	else:
		picture.dismiss()
	show()
	_layout()

func dismiss() -> void:
	_phase = ""
	playback.suspend()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for view in [background,portrait,portrait_rim,text_label,speaker_name,next_marker]: view.hide()
	picture.dismiss()
	if not picture.visible: hide()

func set_line_text(line: String, animate := true) -> void:
	preload("res://scripts/dialogue/map_dialogue_text.gd").apply(text_label,line)
	playback.begin([text_label],str(Settings.value("dialogue_speed","medium")),animate)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _phase!="dialogue" or get_tree().paused:
		playback.suspend()
		return
	if playback.advance(delta,str(Settings.value("dialogue_speed","medium")),bool(Settings.value("dialogue_auto",false))):
		advance_requested.emit()

func request_advance() -> void:
	if not is_visible_in_tree() or _phase.is_empty(): return
	if _phase=="dialogue" and playback.finish_reveal(): return
	playback.suspend()
	advance_requested.emit()

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
				request_advance()
	elif event is InputEventMouseMotion and _pressed:
		_dragged = _dragged or event.position.distance_to(_press_position) > 6.0
	accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_pressed = false
		_dragged = false
		playback.suspend()

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
	var shift := float(_art.get("offset_y", 0.0)) * minf(size.x / 1920.0, size.y / 1080.0)
	background.position.y += shift
	if picture.visible:
		picture.position.y += shift
	var slot: Array = _art.portrait_slot
	var center := Vector2(slot[0] + slot[2] * 0.5, slot[1] + slot[3] * 0.5)
	var portrait_size := portrait.texture.get_size()
	portrait_size *= float(_art.portrait_max_size) / maxf(portrait_size.x, portrait_size.y)
	portrait.size = portrait_size * factor
	if _art.get("portrait_fills_slot", false):
		portrait.size = Vector2(slot[2], slot[3]) * factor
	portrait.position = background.position + center * factor - portrait.size * 0.5
	if portrait_rim.visible:
		var diameter := minf(float(slot[2]),float(slot[3]))*factor
		var anchor := background.position+center*factor
		portrait.size = Vector2.ONE*diameter
		if _player_rim:
			# Enlarge the player's portrait and rim together around the same anchor.
			var rim_scale := diameter/432.0*1.05
			portrait.size = Vector2.ONE*PLAYER_FRAMES.PORTRAIT_SOURCE_SIZE*rim_scale
			portrait_rim.position = anchor-PLAYER_FRAMES.SOURCE_CENTER*rim_scale
			portrait_rim.size = PLAYER_FRAMES.SOURCE_SIZE*rim_scale
		else:
			# This source's painted rim occupies only 568 of its 627 pixels.
			# Cover the original 446px oval mask with the painted rim, not its
			# transparent texture bounds, so no crescent-shaped gap is exposed.
			var rim_scale := 446.0/568.0*factor
			portrait.size = Vector2.ONE*540.0*rim_scale
			portrait_rim.position = anchor-Vector2(318,313)*rim_scale
			portrait_rim.size = Vector2.ONE*627*rim_scale
		portrait.position = anchor-portrait.size*0.5
	portrait.material.set_shader_parameter("portrait_size", portrait.size)
	var text_rect: Array = _art.text_rect
	text_label.position = background.position + Vector2(text_rect[0], text_rect[1]) * factor
	var text_font_size := maxi(15, roundi(36.0 * text_factor) - 1)
	text_label.add_theme_font_size_override("normal_font_size", text_font_size)
	text_label.add_theme_font_size_override("bold_font_size", text_font_size)
	var text_size := Vector2(text_rect[2], text_rect[3]) * factor
	text_label.size = text_size
	# Keep the authored text window after responsive font shaping.
	text_label.set_deferred("size", text_size)
	if speaker_name.visible:
		var name_rect: Array = _art.name_rect
		speaker_name.position = background.position + Vector2(name_rect[0], name_rect[1]) * factor
		speaker_name.size = Vector2(name_rect[2], name_rect[3]) * factor
		var name_size := maxi(15, roundi(28.0 * text_factor))
		var name_font := speaker_name.get_theme_font("font")
		while name_size > 12 and name_font.get_string_size(speaker_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > speaker_name.size.x - 12 * factor:
			name_size -= 1
		speaker_name.add_theme_font_size_override("font_size", name_size)
	if next_marker.visible:
		var next_rect: Array = _art.next_rect
		next_marker.position = background.position + Vector2(next_rect[0], next_rect[1]) * factor
		next_marker.size = Vector2(next_rect[2], next_rect[3]) * factor
