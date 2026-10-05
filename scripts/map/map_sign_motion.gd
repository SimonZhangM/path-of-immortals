class_name MapSignMotion
extends Node

# Presentation only: fixed route points, event state and hit testing stay elsewhere.
var signs: Dictionary = {}
var elapsed := 0.0
var suspended := false
var fade_seconds := 0.3
var _viewport: Control
var _last_tick_usec := 0
var _split_textures: Dictionary = {}

func _init() -> void:
	set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(points: Node, viewport: Control, config_path: String) -> String:
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not config is Dictionary or not config.get("frames") is Dictionary or not config.get("profiles") is Dictionary:
		return "路标动效配置无效。"
	if not _positive(config.get("fade_seconds")):
		return "路标淡出时长无效。"
	for profile: Variant in config.profiles.values():
		if not profile is Dictionary or not profile.get("icon") is String or profile.get("mode") not in ["breathe", "float", "scale", "sway", "frame_breathe"] or not _positive(profile.get("period")):
			return "路标待机参数无效。"
		if profile.mode == "float":
			if not _positive(profile.get("screen_pixels")):
				return "路标浮动幅度无效。"
		elif profile.mode == "scale":
			if not _positive(profile.get("maximum_scale")) or profile.maximum_scale < 1.0:
				return "战斗路标缩放幅度无效。"
		elif profile.mode == "sway":
			if not _positive(profile.get("sway_seconds")) or profile.sway_seconds > profile.period or not _positive(profile.get("degrees")) or not _positive(profile.get("split_source_y")):
				return "剧情路标摇摆参数无效。"
			if not profile.get("pivot_source") is Array or profile.pivot_source.size() != 2 or not _positive(profile.pivot_source[0]) or not _positive(profile.pivot_source[1]):
				return "剧情路标圆点中心无效。"
		else:
			if not _positive(profile.get("minimum")) or profile.minimum > 1.0:
				return "路标明暗倍率无效。"
	var checked := {}
	for point: MapRoutePoint in points.get_children():
		var sign := point.get_node_or_null("Sign") as Sprite2D
		if sign == null:
			continue
		var source: Texture2D = sign.texture.atlas if sign.texture is AtlasTexture else sign.texture
		var category: String = config.frames.get(source.resource_path, "")
		if not config.profiles.has(category):
			return "路标底框缺少动效类别：" + point.point_id
		var profile: Dictionary = config.profiles[category]
		var icon := sign.get_node_or_null(NodePath(profile.icon)) as Sprite2D
		if icon == null:
			return "路标缺少内部图标：" + point.point_id
		if profile.mode == "sway":
			var region := _source_region(icon.texture)
			if profile.split_source_y <= region.position.y or profile.split_source_y >= region.end.y or not region.has_point(Vector2(profile.pivot_source[0], profile.pivot_source[1])):
				return "剧情路标分区超出贴图：" + point.point_id
		var phase_rng := RandomNumberGenerator.new()
		phase_rng.seed = point.point_id.hash()
		checked[point.point_id] = {
			"sign": sign, "icon": icon, "profile": profile, "category": category,
			"position": sign.position, "tint": icon.self_modulate, "modulate": sign.modulate,
			"scale": sign.scale, "frame_tint": sign.self_modulate,
			"phase": phase_rng.randf() * float(profile.period),
			"finished": false, "fading": false, "fade_elapsed": 0.0
		}
	signs = checked
	for entry: Dictionary in signs.values():
		# Mipmaps prefilter minified artwork so subpixel motion does not shimmer.
		entry.sign.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if entry.profile.mode == "sway":
			entry.symbol = _split_story_icon(entry.icon, entry.profile)
	fade_seconds = config.fade_seconds
	_viewport = viewport
	_last_tick_usec = Time.get_ticks_usec()
	set_process(true)
	advance_visuals(0.0)
	return ""

static func _source_region(texture: Texture2D) -> Rect2:
	return texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO, texture.get_size())

func _split_story_icon(icon: Sprite2D, profile: Dictionary) -> Sprite2D:
	# Crop once in memory: separate mip chains prevent the still dot bleeding into
	# the rotating symbol. The source image and authored icon transform stay intact.
	var source: Texture2D = icon.texture.atlas if icon.texture is AtlasTexture else icon.texture
	var region := _source_region(icon.texture)
	var cut := float(profile.split_source_y)
	var upper_rect := Rect2(region.position, Vector2(region.size.x, cut - region.position.y))
	var lower_rect := Rect2(Vector2(region.position.x, cut), Vector2(region.size.x, region.end.y - cut))
	var key := "%s:%s:%s" % [source.resource_path, region, cut]
	if not _split_textures.has(key):
		var pieces: Array[Texture2D] = []
		var original := source.get_image()
		for rect: Rect2 in [upper_rect, lower_rect]:
			var piece := original.get_region(Rect2i(rect))
			piece.generate_mipmaps()
			pieces.append(ImageTexture.create_from_image(piece))
		_split_textures[key] = pieces
	var pivot := Vector2(profile.pivot_source[0], profile.pivot_source[1])
	var symbol := Sprite2D.new()
	symbol.name = "SwaySymbol"
	symbol.texture = _split_textures[key][0]
	symbol.position = pivot - region.get_center()
	symbol.offset = upper_rect.get_center() - pivot
	icon.add_child(symbol)
	icon.texture = _split_textures[key][1]
	icon.offset = lower_rect.get_center() - region.get_center()
	return symbol

static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0

func set_suspended(value: bool) -> void:
	suspended = value
	_last_tick_usec = Time.get_ticks_usec()
	if value:
		for entry: Dictionary in signs.values():
			if entry.fading:
				_hide_finished(entry)

func complete(point_id: String, animate: bool) -> void:
	if not signs.has(point_id):
		return
	var entry: Dictionary = signs[point_id]
	if entry.finished:
		return
	entry.finished = true
	if not animate or suspended or not _on_screen(entry.sign):
		_hide_finished(entry)
	else:
		# Freeze the current idle pose. Only group alpha changes during retirement.
		entry.fading = true
		entry.fade_elapsed = 0.0

func _hide_finished(entry: Dictionary) -> void:
	entry.fading = false
	entry.sign.hide()
	entry.sign.modulate = entry.modulate

func restore(point_id: String) -> void:
	if not signs.has(point_id):
		return
	var entry: Dictionary = signs[point_id]
	entry.finished = false
	entry.fading = false
	entry.fade_elapsed = 0.0
	entry.sign.modulate = entry.modulate
	entry.sign.show()
	advance_visuals(0.0)

func _on_screen(sign: Sprite2D) -> bool:
	return sign.is_visible_in_tree() and (sign.get_global_transform_with_canvas() * sign.get_rect()).grow(4).intersects(_viewport.get_global_rect())

func _process(_delta: float) -> void:
	# UI wall time is deliberately separate from simulation speed and Engine.time_scale.
	var now := Time.get_ticks_usec()
	var seconds := minf(float(now - _last_tick_usec) / 1000000.0, 0.1)
	_last_tick_usec = now
	advance_visuals(seconds)

func advance_visuals(seconds: float) -> void:
	if suspended or not is_instance_valid(_viewport) or not _viewport.is_visible_in_tree():
		return
	elapsed += maxf(seconds, 0.0)
	for entry: Dictionary in signs.values():
		var sign: Sprite2D = entry.sign
		if entry.fading:
			entry.fade_elapsed += maxf(seconds, 0.0)
			var progress := clampf(entry.fade_elapsed / fade_seconds, 0.0, 1.0)
			var tint: Color = entry.modulate
			tint.a *= 1.0 - smoothstep(0.0, 1.0, progress)
			sign.modulate = tint
			if progress >= 1.0:
				_hide_finished(entry)
			continue
		if entry.finished or not _on_screen(sign):
			continue
		var profile: Dictionary = entry.profile
		var phase := fposmod(elapsed + entry.phase, profile.period)
		var wave := 0.5 - 0.5 * cos(TAU * phase / profile.period)
		if profile.mode == "float":
			var screen_offset := Vector2(0, sin(TAU * phase / profile.period) * float(profile.screen_pixels))
			# Parent inverse includes map zoom, route-point scale and viewport stretching.
			sign.position = entry.position + sign.get_parent().get_screen_transform().affine_inverse().basis_xform(screen_offset)
		elif profile.mode == "scale":
			sign.scale = entry.scale * lerpf(1.0, profile.maximum_scale, wave)
		elif profile.mode == "sway":
			var active := phase - (float(profile.period) - float(profile.sway_seconds))
			var progress := maxf(active / float(profile.sway_seconds), 0.0)
			# One left/right gesture, with zero angular velocity at both endpoints.
			var swing := sin(TAU * progress) * sin(PI * progress) / 0.76980036
			entry.symbol.rotation = deg_to_rad(profile.degrees) * swing
		else:
			var multiplier := lerpf(profile.minimum, 1.0, wave)
			var tint: Color = entry.frame_tint if profile.mode == "frame_breathe" else entry.tint
			var target: Sprite2D = sign if profile.mode == "frame_breathe" else entry.icon
			target.self_modulate = Color(tint.r * multiplier, tint.g * multiplier, tint.b * multiplier, tint.a)
