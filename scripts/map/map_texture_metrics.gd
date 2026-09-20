extends RefCounted

# Share CPU image inspection across catalog validation, cards and board art.
# Retain textures (not CPU images) for the session; resource changes invalidate
# their metrics so a reimport/update cannot leave stale bounds or mipmap status.
static var _metrics: Dictionary = {}

static func inspect(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {"has_mipmaps": false, "used_rect": Rect2i()}
	if not _metrics.has(texture):
		var image := texture.get_image()
		_metrics[texture] = {
			"has_mipmaps": image != null and image.has_mipmaps(),
			"used_rect": image.get_used_rect() if image != null else Rect2i(),
		}
		var invalidate := _invalidate.bind(texture)
		if not texture.changed.is_connected(invalidate):
			texture.changed.connect(invalidate)
	return _metrics[texture]

static func _invalidate(texture: Texture2D) -> void:
	_metrics.erase(texture)
