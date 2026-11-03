class_name MapEventPicture
extends Control

signal dismissed
signal layout_changed
const FADE_IN_SECONDS := 0.25
const FADE_OUT_SECONDS := 0.18
const CROSSFADE_SECONDS := 0.12
var frame: TextureRect
var illustration: TextureRect
var previous_illustration: TextureRect
var window: Control
var _slot := Rect2()
var requested_visible := false
var _requested_frame: Texture2D
var _requested_image: Texture2D
var _requested_slot := Rect2()
var _group_tween: Tween
var _image_tween: Tween
var _fading_out := false
var _revision := 0

func _init() -> void:
	name = "EventPicture"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	window = Control.new()
	window.name = "ImageWindow"
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window)
	previous_illustration = TextureRect.new()
	previous_illustration.name = "PreviousIllustration"
	previous_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	previous_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	previous_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	previous_illustration.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	window.add_child(previous_illustration)
	previous_illustration.hide()
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
	frame.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	illustration.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(frame)
	hide()

func configure(frame_texture: Texture2D, image_texture: Texture2D, image_slot: Array) -> void:
	var slot := Rect2(image_slot[0], image_slot[1], image_slot[2], image_slot[3])
	if requested_visible and _same_texture(_requested_frame,frame_texture) and _same_texture(_requested_image,image_texture) and _requested_slot==slot:
		return
	requested_visible = true
	_requested_frame = frame_texture
	_requested_image = image_texture
	_requested_slot = slot
	_revision += 1
	var revision := _revision
	var entering := not visible
	var was_fading_out := _fading_out
	_fading_out = false
	_cancel_group_tween()
	if not entering and not _same_texture(frame.texture,frame_texture):
		# A changed frame ends one complete picture before introducing the next.
		_fading_out = true
		_fade_group(0,FADE_OUT_SECONDS,func():
			if revision!=_revision: return
			_fading_out = false
			_install(frame_texture,image_texture,slot,false)
			_fade_group(1,FADE_IN_SECONDS))
		return
	_install(frame_texture,image_texture,slot,not entering)
	if entering:
		modulate.a = 0
		show()
		_fade_group(1,FADE_IN_SECONDS)
	elif was_fading_out:
		# Same-frame continuations cancel an outgoing fade without replaying it.
		_fade_group(1,FADE_IN_SECONDS*(1-modulate.a))
	elif modulate.a<1:
		_fade_group(1,FADE_IN_SECONDS*(1-modulate.a))

func dismiss() -> void:
	if not requested_visible: return
	requested_visible = false
	_revision += 1
	var revision := _revision
	_cancel_group_tween()
	_fading_out = true
	_fade_group(0,FADE_OUT_SECONDS,func():
		if revision!=_revision: return
		_fading_out = false
		_cancel_image_tween()
		previous_illustration.hide()
		previous_illustration.texture = null
		hide()
		dismissed.emit())

func _install(frame_texture: Texture2D, image_texture: Texture2D, slot: Rect2, crossfade: bool) -> void:
	frame.texture = frame_texture
	_slot = slot
	if not _same_texture(illustration.texture,image_texture):
		_cancel_image_tween()
		previous_illustration.texture = illustration.texture
		illustration.texture = image_texture
		if crossfade and previous_illustration.texture!=null:
			# An opaque old image under the incoming image avoids a transparent dip.
			previous_illustration.show()
			illustration.modulate.a = 0
			_image_tween = create_tween().set_ignore_time_scale(true)
			_image_tween.tween_property(illustration,"modulate:a",1.0,CROSSFADE_SECONDS)
			_image_tween.finished.connect(func():
				_image_tween = null
				previous_illustration.hide()
				previous_illustration.texture = null)
		else:
			previous_illustration.hide()
			previous_illustration.texture = null
			illustration.modulate.a = 1
	layout_changed.emit()

func _fade_group(alpha: float, seconds: float, finished := Callable()) -> void:
	if seconds<=0 or is_equal_approx(modulate.a,alpha):
		modulate.a = alpha
		if finished.is_valid(): finished.call()
		return
	_group_tween = create_tween().set_ignore_time_scale(true)
	_group_tween.tween_property(self,"modulate:a",alpha,seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_group_tween.finished.connect(func():
		_group_tween = null
		if finished.is_valid(): finished.call())

func _cancel_group_tween() -> void:
	if _group_tween!=null: _group_tween.kill()
	_group_tween = null

func _cancel_image_tween() -> void:
	if _image_tween!=null: _image_tween.kill()
	_image_tween = null

func _same_texture(first: Texture2D, second: Texture2D) -> bool:
	if first==second: return true
	if first is AtlasTexture and second is AtlasTexture:
		return first.atlas==second.atlas and first.region==second.region and first.margin==second.margin
	return false

func layout_for(view_size: Vector2, dialogue_rect: Rect2) -> void:
	if frame.texture == null:
		return
	var gap := 16.0 * view_size.x / 1920.0
	var top := view_size.y * 0.3
	var available_height := maxf(1.0, dialogue_rect.position.y - gap - top)
	var factor := minf(dialogue_rect.size.x / frame.texture.get_width(), available_height / frame.texture.get_height())
	var previous_height := frame.texture.get_height() * factor
	# Enlarge around the previous bottom center, preserving the dialogue gap.
	factor *= (4.0 / 3.0) * 1.25
	size = frame.texture.get_size() * factor
	position = Vector2((view_size.x - size.x) * 0.5, top + previous_height - size.y)
	frame.size = size
	window.position = _slot.position * factor
	window.size = _slot.size * factor
	illustration.size = window.size
	previous_illustration.size = window.size
