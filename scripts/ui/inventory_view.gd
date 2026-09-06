class_name InventoryView
extends Control

signal selection_changed(item_id: String)
signal feedback(message: String)

var manager: GameManager
var selected_instance: String = ""
var _grab_offset := Vector2i.ZERO
var _hover_cell := Vector2i(-100, -100)
var _hover_valid: bool = false
var _drag_instance: String = ""
var _generation: int = 0
var _textures: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(495, 495)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): _hover_cell = Vector2i(-100, -100); queue_redraw())

func bind_game(game: GameManager) -> void:
	manager = game
	manager.inventory_changed.connect(queue_redraw)
	manager.battle_restarted.connect(reset_interaction)
	manager.battle_started.connect(reset_interaction)
	for instance in manager.inventory.get_instances():
		var item := manager.registry.get_item(instance["item_id"])
		if not item.icon_path.is_empty():
			_textures[item.id] = load(item.icon_path)
	queue_redraw()

func reset_interaction() -> void:
	_generation += 1
	selected_instance = ""
	_drag_instance = ""
	_hover_cell = Vector2i(-100, -100)
	queue_redraw()

func grid_rect() -> Rect2:
	var side := minf(size.x, size.y) - 18.0
	return Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)

func cell_center(cell: Vector2i) -> Vector2:
	var area := grid_rect()
	return area.position + (Vector2(cell) + Vector2.ONE * 0.5) * area.size.x / 4.0

func _cell_at(point: Vector2) -> Vector2i:
	var relative := (point - grid_rect().position) / (grid_rect().size.x / 4.0)
	return Vector2i(floori(relative.x), floori(relative.y))

func _draw() -> void:
	if manager == null or manager.inventory == null:
		return
	var area := grid_rect()
	var step := area.size.x / 4.0
	draw_rect(area.grow(7), Color("a8a579"), false, 2)
	for y in 4:
		for x in 4:
			var rect := Rect2(area.position + Vector2(x, y) * step, Vector2.ONE * step).grow(-2)
			draw_rect(rect, Color("263b3e"))
			draw_rect(rect, Color("506160"), false, 1)
			draw_circle(rect.get_center(), 2, Color("708079", 0.4))
	for instance in manager.inventory.get_instances():
		var item := manager.registry.get_item(instance["item_id"])
		var rect := Rect2(area.position + Vector2(instance["cell"]) * step, Vector2(item.grid_size) * step).grow(-4)
		var active: bool = instance["instance_id"] == selected_instance
		draw_rect(rect, Color("394943") if item.type == "armor" else Color("4a3c30"))
		draw_rect(rect, Color("e5c181") if active else Color("a99b71"), false, 3 if active else 2)
		var icon_rect := Rect2(rect.position + Vector2(9, 8), rect.size - Vector2(18, 38))
		if _textures.has(item.id):
			var texture: Texture2D = _textures[item.id]
			var icon_size := texture.get_size() * minf(icon_rect.size.x / texture.get_width(), icon_rect.size.y / texture.get_height())
			draw_texture_rect(texture, Rect2(icon_rect.get_center() - icon_size * 0.5, icon_size), false)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 30), Vector2(rect.size.x, 30)), Color("101b20", 0.85))
		draw_string(get_theme_default_font(), rect.position + Vector2(0, rect.size.y - 9), item.display_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color("e4d8b7"))
	if not _drag_instance.is_empty() and _hover_cell.x > -100:
		var instance := manager.inventory.get_instance(_drag_instance)
		if not instance.is_empty():
			var dimensions := manager.registry.get_item(instance["item_id"]).grid_size
			var preview := Rect2(area.position + Vector2(_hover_cell) * step, Vector2(dimensions) * step).grow(-3)
			var tint := Color("7ed6ad") if _hover_valid else Color("ee857a")
			draw_rect(preview, Color(tint, 0.22))
			draw_rect(preview, tint, false, 4)

func _gui_input(event: InputEvent) -> void:
	if manager == null or manager.inventory.locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_at(event.position)
		var hit := manager.inventory.item_at(cell)
		if not hit.is_empty():
			selected_instance = hit
			var instance := manager.inventory.get_instance(hit)
			_grab_offset = cell - Vector2i(instance["cell"])
			selection_changed.emit(instance["item_id"])
		elif not selected_instance.is_empty():
			var moved := manager.move_item(selected_instance, cell)
			feedback.emit("已调整位置" if moved else "此处放不下：不能越界或与其他装备重叠")
		queue_redraw()
		accept_event()

func drag_data_at(point: Vector2) -> Dictionary:
	if manager == null or manager.inventory.locked:
		return {}
	var cell := _cell_at(point)
	var hit := manager.inventory.item_at(cell)
	if hit.is_empty():
		return {}
	var instance := manager.inventory.get_instance(hit)
	selected_instance = hit
	_drag_instance = hit
	_grab_offset = cell - Vector2i(instance["cell"])
	selection_changed.emit(instance["item_id"])
	return {"source": get_instance_id(), "generation": _generation, "instance_id": hit, "offset": _grab_offset}

func _get_drag_data(point: Vector2) -> Variant:
	var data := drag_data_at(point)
	if data.is_empty():
		return null
	var item := manager.registry.get_item(manager.inventory.get_instance(data["instance_id"])["item_id"])
	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.texture = _textures.get(item.id)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(item.grid_size) * grid_rect().size.x / 4.0
	preview.modulate.a = 0.7
	preview.position = -Vector2(_grab_offset) * grid_rect().size.x / 4.0 - Vector2.ONE * 22
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	set_drag_preview(holder)
	return data

func _can_drop_data(point: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("source") != get_instance_id() or data.get("generation") != _generation:
		return false
	_hover_cell = _cell_at(point) - Vector2i(data["offset"])
	_drag_instance = data["instance_id"]
	_hover_valid = manager.inventory.can_move(_drag_instance, _hover_cell)
	queue_redraw()
	return _hover_valid

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		manager.move_item(data["instance_id"], _hover_cell)
		feedback.emit("已调整位置")
	_drag_instance = ""
	_hover_cell = Vector2i(-100, -100)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_instance = ""
		_hover_cell = Vector2i(-100, -100)
		queue_redraw()
