class_name MapPlayer
extends AnimatedSprite2D

var _action_scales: Dictionary = {}
var _action_offsets: Dictionary = {}

func configure(definition: Dictionary) -> String:
	var initial_facing: String = definition.get("initial_facing", "right")
	if initial_facing not in ["left", "right"]:
		return "地图角色初始朝向无效：" + initial_facing
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var base_frame_size := Vector2(definition.frame_size[0], definition.frame_size[1])
	_action_scales.clear()
	_action_offsets.clear()
	for action in ["idle", "walk", "run"]:
		var entry: Dictionary = definition.animations[action]
		var dimensions: Array = entry.get("frame_size", definition.frame_size)
		var frame_size := Vector2(dimensions[0], dimensions[1])
		var texture := load(entry.texture) as Texture2D
		var auto_slice: bool = entry.get("auto_slice", false)
		var sheet_frames: int = entry.get("sheet_frames", entry.frames)
		var regions: Array = entry.get("frame_regions", [])
		if int(entry.frames) <= 0 or sheet_frames <= 0:
			return "地图角色精灵表帧数无效：" + action
		if not regions.is_empty():
			if regions.size() != sheet_frames or texture == null:
				return "地图角色切片数量无效：" + action
			for region in regions:
				if not region is Array or region.size() != 4:
					return "地图角色切片区域无效：" + action
				for value in region:
					if not (value is int or value is float) or float(value) != floorf(float(value)):
						return "地图角色切片坐标无效：" + action
				var rect := Rect2(region[0], region[1], region[2], region[3])
				if rect.size.x <= 0 or rect.size.y <= 0 or not Rect2(Vector2.ZERO, texture.get_size()).encloses(rect):
					return "地图角色切片区域越界：" + action
				if rect.size != Vector2(regions[0][2], regions[0][3]):
					return "地图角色切片尺寸须一致：" + action
			frame_size = Vector2(regions[0][2], regions[0][3])
		# Author-facing indices start at 1, following the configured source regions.
		var frame_order: Variant = entry.get("frame_order", range(1, int(entry.frames) + 1))
		if not frame_order is Array or frame_order.size() != int(entry.frames):
			return "地图角色播放顺序长度无效：" + action
		for source_frame in frame_order:
			if not (source_frame is int or source_frame is float):
				return "地图角色播放帧序号无效：" + action
			if float(source_frame) != floorf(float(source_frame)) or source_frame < 1 or source_frame > sheet_frames:
				return "地图角色播放帧序号越界：" + action
		if regions.is_empty() and auto_slice and texture != null:
			frame_size = Vector2(texture.get_width() / float(sheet_frames), texture.get_height())
		if frame_size.x <= 0 or frame_size.y <= 0 or texture == null or (regions.is_empty() and not auto_slice and texture.get_size() != Vector2(frame_size.x * sheet_frames, frame_size.y)):
			return "地图角色精灵表尺寸无效：" + action
		# Different-resolution sheets share a common displayed frame height.
		var display_height: float = entry.get("display_frame_height", base_frame_size.y)
		_action_scales[action] = float(definition.display_scale) * display_height / frame_size.y
		var foot: Array = entry.get("feet_offset", definition.feet_offset)
		_action_offsets[action] = Vector2(foot[0], foot[1])
		frames.add_animation(action)
		frames.set_animation_speed(action, entry.fps)
		frames.set_animation_loop(action, true)
		for source_frame in frame_order:
			var index := int(source_frame) - 1
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(Vector2(index * frame_size.x, 0), frame_size)
			if not regions.is_empty():
				var region: Array = regions[index]
				frame.region = Rect2(region[0], region[1], region[2], region[3])
			elif auto_slice:
				# Slice by source columns even when trailing frames are excluded from playback.
				var left := roundf(index * texture.get_width() / float(sheet_frames))
				var right := roundf((index + 1) * texture.get_width() / float(sheet_frames))
				frame.region = Rect2(left, 0, right - left, texture.get_height())
			frames.add_frame(action, frame)
	sprite_frames = frames
	if not animation_changed.is_connected(_apply_animation_layout):
		animation_changed.connect(_apply_animation_layout)
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flip_h = initial_facing == "left"
	play("idle")
	_apply_animation_layout()
	return ""

func _apply_animation_layout() -> void:
	if _action_scales.has(String(animation)):
		scale = Vector2.ONE * float(_action_scales[String(animation)])
		offset = _action_offsets[String(animation)]

func present(travel: MapTravelState) -> void:
	var movement := travel.map_position - position
	if absf(movement.x) > 0.001:
		flip_h = movement.x < 0
	position = travel.map_position
	if animation != StringName(travel.mode):
		play(travel.mode)
