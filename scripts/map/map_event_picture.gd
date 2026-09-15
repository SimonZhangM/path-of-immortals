class_name MapEventPicture
extends Control

var frame: TextureRect
var illustration: TextureRect
var window: Control
var _slot := Rect2()

func _init() -> void:
	name = "EventPicture"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	window = Control.new()
	window.name = "ImageWindow"
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window)
	illustration = TextureRect.new()
	illustration.name = "Illustration"
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(illustration)
	frame = TextureRect.new()
	frame.name = "Frame"
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	hide()

func configure(frame_texture: Texture2D, image_texture: Texture2D, image_slot: Array) -> void:
	frame.texture = frame_texture
	illustration.texture = image_texture
	_slot = Rect2(image_slot[0], image_slot[1], image_slot[2], image_slot[3])

func layout_for(view_size: Vector2, dialogue_rect: Rect2) -> void:
	if frame.texture == null:
		return
	var gap := 16.0 * view_size.x / 1920.0
	var top := view_size.y * 0.3
	var available_height := maxf(1.0, dialogue_rect.position.y - gap - top)
	var factor := minf(dialogue_rect.size.x / frame.texture.get_width(), available_height / frame.texture.get_height())
	size = frame.texture.get_size() * factor
	position = Vector2((view_size.x - size.x) * 0.5, top)
	frame.size = size
	window.position = _slot.position * factor
	window.size = _slot.size * factor
	illustration.size = window.size
