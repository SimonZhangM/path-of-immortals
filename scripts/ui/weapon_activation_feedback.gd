extends Control
## Presentation seconds only: neither battle speed nor simulation pause changes duration.
const DURATION := 0.8
var elapsed := 0.0
var failed := false
var ghost: TextureRect
var rim: StyleBoxFlat

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost = TextureRect.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(ghost)
	rim = StyleBoxFlat.new()
	rim.draw_center = false
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(5)
	rim.shadow_size = 12
	rim.shadow_offset = Vector2.ZERO
	set_process(false)

func progress() -> float:
	return clampf(elapsed / DURATION, 0.0, 1.0)

func shake_x() -> float:
	# Three short horizontal oscillations, decaying back to the original position.
	return sin(progress() * TAU * 3.0) * 7.0 * (1.0 - progress()) if failed else 0.0

func advance(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func layout_from(art: TextureRect, footprint: Rect2) -> void:
	position = footprint.position
	size = footprint.size
	ghost.visible = not failed
	ghost.texture = art.texture
	ghost.size = art.size
	ghost.position = art.position - position
	ghost.pivot_offset = footprint.get_center() - art.position
	ghost.scale = Vector2.ONE * (1.0 + progress())
	ghost.modulate.a = 0.5 * (1.0 - progress())
	queue_redraw()

func _draw() -> void:
	if not failed: return
	var fade := 1.0 - smoothstep(0.7, 1.0, progress())
	rim.border_color = Color(1.0, 0.16, 0.12, 0.5 * fade)
	rim.shadow_color = Color(1.0, 0.1, 0.08, 0.5 * fade)
	draw_style_box(rim, Rect2(Vector2.ZERO, size).grow(-2))
