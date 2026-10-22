extends RefCounted

# Shared normalized artwork geometry. The existing portrait rect is authoritative;
# only the independent overlay grows, so a frame never resizes the monster itself.
static var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/enemy_portrait_geometry.json"))

static func canvas_scale() -> float:
	var portrait_radius_uv: float = geometry.portrait_radius / geometry.portrait_canvas_size
	var covered_radius_uv: float = (geometry.frame_inner_radius + geometry.frame_inner_overlap) / geometry.frame_canvas_size
	return portrait_radius_uv / covered_radius_uv

static func create_overlay(portrait: TextureRect) -> TextureRect:
	var frame := TextureRect.new()
	frame.name = "EnemyPortraitFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.add_child(frame)
	portrait.resized.connect(_layout.bind(portrait, frame))
	_layout(portrait, frame)
	frame.hide()
	return frame

static func show_definition(frame: TextureRect, definition: Dictionary) -> void:
	var path: String = definition.get("portrait_frame", "")
	frame.texture = load(path) as Texture2D if not path.is_empty() else null
	frame.visible = frame.texture != null

static func _layout(portrait: TextureRect, frame: TextureRect) -> void:
	frame.size = Vector2.ONE * minf(portrait.size.x, portrait.size.y) * canvas_scale()
	frame.position = (portrait.size - frame.size) * 0.5
