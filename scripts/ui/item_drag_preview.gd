class_name ItemDragPreview
extends Control

var manager: GameManager
var item: ItemData
var entry: Dictionary
var texture: Texture2D

func configure(game: GameManager, definition: ItemData, instance: Dictionary, footprint: Vector2) -> void:
	manager = game
	item = definition
	entry = instance.duplicate(true)
	texture = load(item.icon_path)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_footprint(footprint)

func set_footprint(footprint: Vector2) -> void:
	size = footprint
	position = -size * 0.5
	queue_redraw()

static func fitted_icon_rect(texture_value: Texture2D, footprint: Rect2) -> Rect2:
	var interior := footprint.grow(-9)
	var dimensions := texture_value.get_size() * minf(interior.size.x / texture_value.get_width(), interior.size.y / texture_value.get_height())
	return Rect2(interior.get_center() - dimensions * 0.5, dimensions)

func _draw() -> void:
	if texture == null:
		return
	draw_texture_rect(texture, fitted_icon_rect(texture, Rect2(Vector2.ZERO, size)), false)
	var rect := Rect2(Vector2.ZERO, size).grow(-4)
	var id: String = entry.get("instance_id", "")
	var remaining := manager.simulation.cooling_remaining_usec(id)
	if remaining > 0:
		draw_rect(rect, Color(0.25, 0.27, 0.29, 0.42))
		draw_string(get_theme_default_font(), Vector2(rect.position.x, rect.get_center().y + 10), "%ds" % ceili(remaining / 1_000_000.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, Color.WHITE)
	elif item.cooldown_usec > 0:
		var seconds := item.cooldown_usec / 1_000_000.0
		var progress := manager.simulation.activation_progress(id) if manager.simulation.state.item_runtime.has(id) else 0.0
		var left := seconds if manager.simulation.state.phase == GameState.Phase.PREPARATION else seconds * (1.0 - progress)
		var center := Vector2(rect.position.x + 24 if item.is_consumable() else rect.end.x - 24, rect.end.y - 24)
		CooldownRing.paint(self, center, 23, left, seconds, CooldownRing.tint(manager.registry, item.element))
	if item.is_consumable():
		var badge := Rect2(rect.end - Vector2(28, 25), Vector2(28, 25))
		draw_rect(badge, Color("152124"))
		draw_string(get_theme_default_font(), badge.position + Vector2(0, 21), str(entry.get("units", []).size()), HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color("f4d48e"))
