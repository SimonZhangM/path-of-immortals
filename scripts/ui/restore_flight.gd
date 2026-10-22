extends TextureRect

# Presentation seconds, independent of the deterministic battle clock.
const DURATION := 1.5
var elapsed := 0.0
var origin := Vector2.ZERO
var destination: Control

func configure(image: Texture2D, start: Vector2, target: Control) -> void:
	texture = image
	origin = start
	destination = target
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 50
	size = Vector2(36, 36)
	pivot_offset = size * 0.5
	advance(0)

func advance(delta: float) -> void:
	elapsed = minf(DURATION, elapsed + delta)
	if not is_instance_valid(destination) or not destination.is_visible_in_tree():
		elapsed = DURATION
		hide()
		return
	var parent := get_parent() as Control
	var end := parent.get_global_transform_with_canvas().affine_inverse() * (destination.get_global_transform_with_canvas() * (destination.size * 0.5))
	var t := elapsed / DURATION
	# A short upward pop, then a smooth arc into the actual bar center.
	var travel := smoothstep(0.12, 1.0, t)
	var center := origin.lerp(end, travel) + Vector2(0, -42 * sin(PI * t))
	position = center - size * 0.5
	scale = Vector2.ONE * lerpf(0.65, 1.0, smoothstep(0, 0.15, t))
	modulate.a = 1.0 - smoothstep(0.88, 1.0, t)
