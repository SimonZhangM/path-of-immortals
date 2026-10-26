class_name MapGatheringAnimation
extends Control

signal finished

var sprite := AnimatedSprite2D.new()
var frame_count := 0
var character_rect := Rect2()
var _reference_player: MapPlayer
var _height_ratio := 1.0
var _source_faces_left := false
var _unflipped_offset := Vector2.ZERO
var _playing := false

func _init() -> void:
	name = "MapGatheringAnimation"
	z_index = 43
	mouse_filter = MOUSE_FILTER_STOP
	set_process(false)
	hide()
	# The transparent full-screen control blocks input without dimming the map.
	sprite.name = "GatheringActor"
	sprite.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	sprite.animation_finished.connect(_on_finished)
	resized.connect(func(): _layout.call_deferred())

func prepare(options: MapGatheringOptions, method_id: String, reference_player: MapPlayer) -> String:
	var config := options.gathering_animation
	if config.is_empty(): return "采集动画尚未配置。"
	if config.get("source_facing") not in ["left", "right"]: return "采集动画原图朝向无效。"
	var method: Dictionary = {}
	for entry: Dictionary in options.methods:
		if entry.id == method_id: method = entry
	if method.is_empty() or not ContentRegistry._positive_integer(method.get("animation_frames")):
		return "采集动画帧数无效。"
	for key in ["columns", "rows", "walk_visible_height"]:
		if not ContentRegistry._positive_integer(config.get(key)): return "采集动画尺寸无效。"
	var dimensions: Variant = config.get("frame_size")
	if not dimensions is Array or dimensions.size() != 2: return "采集动画单帧尺寸无效。"
	for value: Variant in dimensions:
		if not ContentRegistry._positive_integer(value): return "采集动画单帧尺寸无效。"
	var frame_size := Vector2(dimensions[0], dimensions[1])
	var bounds: Variant = config.get("character_rect")
	if not bounds is Array or bounds.size() != 4: return "采集人物可视区域无效。"
	for value: Variant in bounds:
		if not ContentRegistry._nonnegative_integer(value): return "采集人物可视区域无效。"
	var rect := Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
	if not rect.has_area() or not Rect2(Vector2.ZERO, frame_size).encloses(rect): return "采集人物可视区域越界。"
	var fps: Variant = config.get("fps")
	if not (fps is int or fps is float) or not is_finite(float(fps)) or float(fps) <= 0: return "采集动画帧率无效。"
	var texture_path: Variant = config.get("texture")
	if not texture_path is String or not ResourceLoader.exists(texture_path, "Texture2D"): return "采集动画图片缺失。"
	var texture := load(texture_path) as Texture2D
	if texture == null or texture.get_size() != frame_size * Vector2(config.columns, config.rows): return "采集精灵图尺寸不符。"
	if method.animation_frames > config.columns * config.rows or not is_instance_valid(reference_player): return "采集动画帧数或人物参照无效。"
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"gathering")
	frames.set_animation_speed(&"gathering", float(fps))
	frames.set_animation_loop(&"gathering", false)
	frame_count = int(method.animation_frames)
	for index in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(Vector2(index % int(config.columns), index / int(config.columns)) * frame_size, frame_size)
		frame.filter_clip = true
		frames.add_frame(&"gathering", frame)
	sprite.stop()
	sprite.sprite_frames = frames
	sprite.animation = &"gathering"
	# The fixed foot reference sits on the event node, just like the map player.
	_unflipped_offset = frame_size * 0.5 - Vector2(rect.get_center().x, rect.end.y)
	_source_faces_left = config.source_facing == "left"
	character_rect = rect
	_height_ratio = float(config.walk_visible_height) / rect.size.y
	_reference_player = reference_player
	return ""

func play_prepared() -> void:
	# MapPlayer's unflipped artwork faces right. Sample its standing direction
	# after arrival sync, and mirror around the fixed feet rather than the canvas.
	sprite.flip_h = _reference_player.flip_h != _source_faces_left
	sprite.offset = _unflipped_offset
	if sprite.flip_h: sprite.offset.x = -sprite.offset.x
	_playing = true
	set_process(true)
	show()
	_layout()
	sprite.play(&"gathering")
	sprite.set_frame_and_progress(0, 0.0)

func dismiss() -> void:
	_playing = false
	set_process(false)
	sprite.stop()
	hide()

func _layout() -> void:
	if not is_instance_valid(_reference_player): return
	# Player origin is the current path node's ground position. Convert through
	# the map camera into this overlay without moving the map or the player.
	sprite.position = get_global_transform_with_canvas().affine_inverse() * _reference_player.get_global_transform_with_canvas().origin
	sprite.scale = _reference_player.action_scale_in_canvas("walk") / get_global_transform_with_canvas().get_scale() * _height_ratio

func _process(_delta: float) -> void:
	# Keep the world anchor attached through viewport/camera transform changes.
	_layout()

func _on_finished() -> void:
	if not _playing: return
	_playing = false
	set_process(false)
	hide()
	finished.emit()
