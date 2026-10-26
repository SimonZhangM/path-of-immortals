extends RefCounted

# Share CPU image inspection across catalog validation, cards and board art.
# Retain textures (not CPU images) for the session; resource changes invalidate
# their metrics so a reimport/update cannot leave stale bounds or mipmap status.
static var _metrics: Dictionary = {}
static var _mipmap_status: Dictionary = {}
static var _alignment_overrides: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/item_art_alignment.json"))

static func alignment_center(texture: Texture2D) -> Vector2:
	var center := Rect2(inspect(texture).visible_rect).get_center()
	var authored: Dictionary = _alignment_overrides.get(texture.resource_path, {})
	if authored.get("optical_centroid", false):
		var metrics := inspect(texture)
		if not metrics.has("optical_center"):
			var source := texture.get_image()
			var weighted := Vector2.ZERO
			var weight := 0.0
			for y in range(0, source.get_height(), 2):
				for x in range(0, source.get_width(), 2):
					var alpha := source.get_pixel(x,y).a
					if alpha <= 0.02: continue
					weighted += Vector2(x + 0.5,y + 0.5) * alpha
					weight += alpha
			metrics.optical_center = weighted / weight if weight > 0 else center
		center = metrics.optical_center
	if authored.has("horizontal_center"):
		center.x = float(authored.horizontal_center) * texture.get_width()
	return center

static func inspect(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {"has_mipmaps": false, "used_rect": Rect2i()}
	if not _metrics.has(texture):
		var image := texture.get_image()
		_metrics[texture] = {
			"has_mipmaps": image != null and image.has_mipmaps(),
			"used_rect": image.get_used_rect() if image != null else Rect2i(),
		}
		_metrics[texture].visible_rect = _visible_rect(image, _metrics[texture].used_rect)
		var invalidate := _invalidate.bind(texture)
		if not texture.changed.is_connected(invalidate):
			texture.changed.connect(invalidate)
	return _metrics[texture]

static func has_mipmaps(texture: Texture2D) -> bool:
	# Catalog validation does not need to scan transparent bounds on every icon.
	# Keep the original pixel-accurate inspection for the UI that actually uses it.
	if texture == null: return false
	if _metrics.has(texture): return _metrics[texture].has_mipmaps
	if not _mipmap_status.has(texture):
		var image := texture.get_image()
		_mipmap_status[texture] = image != null and image.has_mipmaps()
		var invalidate := _invalidate.bind(texture)
		if not texture.changed.is_connected(invalidate): texture.changed.connect(invalidate)
	return _mipmap_status[texture]

static func _invalidate(texture: Texture2D) -> void:
	_metrics.erase(texture)
	_mipmap_status.erase(texture)

static func solid_rect(texture: Texture2D) -> Rect2:
	var metrics := inspect(texture)
	if not metrics.has("solid_rect"):
		metrics.solid_rect = _visible_rect(texture.get_image(),metrics.used_rect,0.5)
	return Rect2(metrics.solid_rect)

# Ignore near-transparent export specks for alignment, without cropping artwork.
# Scan only outer strips; cache the result with the existing texture metrics.
static func _visible_rect(image: Image, used: Rect2i, alpha_threshold: float = 0.02) -> Rect2i:
	if image == null or not used.has_area():
		return used
	var left := used.position.x
	var right := used.end.x - 1
	var top := used.position.y
	var bottom := used.end.y - 1
	while left <= right and not _opaque_strip(image, left, top, bottom, true, alpha_threshold):
		left += 1
	if left > right:
		return used
	while right > left and not _opaque_strip(image, right, top, bottom, true, alpha_threshold):
		right -= 1
	while top <= bottom and not _opaque_strip(image, top, left, right, false, alpha_threshold):
		top += 1
	while bottom > top and not _opaque_strip(image, bottom, left, right, false, alpha_threshold):
		bottom -= 1
	return Rect2i(left, top, right - left + 1, bottom - top + 1)

static func _opaque_strip(image: Image, fixed: int, first: int, last: int, vertical: bool, alpha_threshold: float = 0.02) -> bool:
	for offset in range(first, last + 1):
		var color := image.get_pixel(fixed, offset) if vertical else image.get_pixel(offset, fixed)
		if color.a > alpha_threshold:
			return true
	return false
