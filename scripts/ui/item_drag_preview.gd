class_name ItemDragPreview
extends Control

const BOARD_ICON_SCALE := 0.9

var manager: GameManager
var item: ItemData
var entry: Dictionary
var texture: Texture2D
var artwork: MapItemArtwork

func configure(game: GameManager, definition: ItemData, instance: Dictionary, footprint: Vector2) -> void:
	manager = game
	item = definition
	entry = instance.duplicate(true)
	texture = null if item.icon_path.is_empty() else load(item.icon_path)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork = MapItemArtwork.new()
	artwork.configure(MapItemArtwork.battle_record(manager, item))
	artwork.show_behind_parent = true
	add_child(artwork)
	set_footprint(footprint)

func set_footprint(footprint: Vector2) -> void:
	size = footprint
	position = -size * 0.5
	if artwork != null: artwork.place_on_board(Rect2(Vector2.ZERO, size))
	queue_redraw()

static func artwork_rect(footprint: Rect2) -> Rect2:
	var interior := footprint.grow(-9)
	var dimensions := interior.size * BOARD_ICON_SCALE
	return Rect2(interior.get_center() - dimensions * 0.5, dimensions)

static func fitted_icon_rect(texture_value: Texture2D, footprint: Rect2, visual_scale: float = 1.0) -> Rect2:
	var interior := artwork_rect(footprint)
	var used := Rect2(MapItemArtwork.TextureMetrics.inspect(texture_value).used_rect)
	var factor := minf(interior.size.x / used.size.x, interior.size.y / used.size.y) * visual_scale
	var dimensions := used.size * factor
	var center := MapItemArtwork.TextureMetrics.alignment_center(texture_value) - used.position
	return Rect2(interior.get_center() - center * factor, dimensions)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-4)
	var id: String = entry.get("instance_id", "")
	var remaining := manager.simulation.cooling_remaining_usec(id)
	if remaining > 0:
		CooldownRing.paint_text(self, InventoryView.rotation_ring_center(rect, item), str(ceili(remaining / 1_000_000.0)), 32)
	elif item.cooldown_usec > 0:
		var seconds := item.cooldown_usec / 1_000_000.0
		var progress := manager.simulation.activation_progress(id) if manager.simulation.state.item_runtime.has(id) else 0.0
		var left := seconds if manager.simulation.state.phase == GameState.Phase.PREPARATION else seconds * (1.0 - progress)
		var center := InventoryView.rotation_ring_center(rect, item)
		CooldownRing.paint(self, center, 23, left, seconds, CooldownRing.tint(manager.registry, item.element))
	if item.is_consumable():
		var badge := Rect2(rect.end - Vector2(28, 25), Vector2(28, 25))
		draw_rect(badge, Color("152124"))
		draw_string(get_theme_default_font(), badge.position + Vector2(0, 21), str(entry.get("units", []).size()), HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color("f4d48e"))
