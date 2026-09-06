class_name InventoryView
extends Control

signal selection_changed(item_id: String)
signal feedback(message: String)

var manager: GameManager
var member_index: int = 0
var compact: bool = false
var display_side: float = 0.0
var inventory: InventoryState:
	get:
		return manager.party[member_index].inventory if manager != null else null
var selected_instance: String = ""
var _grab_offset := Vector2i.ZERO
var _hover_cell := Vector2i(-100, -100)
var _hover_valid: bool = false
var _drag_instance: String = ""
var _generation: int = 0
var _textures: Dictionary = {}
var _last_time_usec: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(220, 220) if compact else Vector2(495, 495)
	if display_side > 0:
		custom_minimum_size = Vector2.ONE * display_side
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): _hover_cell = Vector2i(-100, -100); queue_redraw())

func bind_game(game: GameManager, index: int = 0) -> void:
	manager = game
	member_index = index
	manager.inventory_changed.connect(queue_redraw)
	manager.battle_restarted.connect(reset_interaction)
	manager.battle_started.connect(reset_interaction)
	manager.inventory_access_changed.connect(reset_interaction)
	manager.member_selected.connect(func(_index: int): reset_interaction())
	for instance in inventory.get_instances():
		var item := manager.registry.get_item(instance["item_id"])
		if not item.icon_path.is_empty():
			_textures[item.id] = load(item.icon_path)
	queue_redraw()

func set_member(index: int) -> void:
	member_index = index
	reset_interaction()

func _process(_delta: float) -> void:
	if manager != null and manager.simulation != null:
		var time_usec := manager.simulation.state.time_usec
		if time_usec != _last_time_usec:
			_last_time_usec = time_usec
			queue_redraw()

func cooldown_progress(instance_id: String) -> float:
	return manager.simulation.activation_progress(instance_id)

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
	if manager == null or inventory == null:
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
	for instance in inventory.get_instances():
		var item := manager.registry.get_item(instance["item_id"])
		var rect := Rect2(area.position + Vector2(instance["cell"]) * step, Vector2(item.grid_size) * step).grow(-4)
		var active: bool = instance["instance_id"] == selected_instance
		draw_rect(rect, Color("394943") if item.type == "armor" else Color("4a3c30"))
		draw_rect(rect, Color("e5c181") if active else Color("a99b71"), false, 3 if active else 2)
		var caption_height := 20.0 if compact else 30.0
		var icon_rect := Rect2(rect.position + Vector2(5, 4), rect.size - Vector2(10, caption_height + 6))
		if _textures.has(item.id):
			var texture: Texture2D = _textures[item.id]
			var icon_size := texture.get_size() * minf(icon_rect.size.x / texture.get_width(), icon_rect.size.y / texture.get_height())
			draw_texture_rect(texture, Rect2(icon_rect.get_center() - icon_size * 0.5, icon_size), false)
			var progress := cooldown_progress(instance["instance_id"])
			if progress < 1.0:
				var boundary_y := icon_rect.position.y + icon_rect.size.y * (1.0 - progress)
				draw_rect(Rect2(icon_rect.position, Vector2(icon_rect.size.x, boundary_y - icon_rect.position.y)), Color(0.43, 0.45, 0.47, 0.74))
				draw_dashed_line(Vector2(icon_rect.position.x, boundary_y), Vector2(icon_rect.end.x, boundary_y), Color("f4e5bc"), 1.5 if compact else 2.0, 4.0 if compact else 7.0)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - caption_height), Vector2(rect.size.x, caption_height)), Color("101b20", 0.85))
		draw_string(get_theme_default_font(), rect.position + Vector2(0, rect.size.y - 6), item.display_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12 if compact else 18, Color("e4d8b7"))
	if not _drag_instance.is_empty() and _hover_cell.x > -100:
		var instance := inventory.get_instance(_drag_instance)
		if not instance.is_empty():
			var dimensions := manager.registry.get_item(instance["item_id"]).grid_size
			var preview := Rect2(area.position + Vector2(_hover_cell) * step, Vector2(dimensions) * step).grow(-3)
			var tint := Color("7ed6ad") if _hover_valid else Color("ee857a")
			draw_rect(preview, Color(tint, 0.22))
			draw_rect(preview, tint, false, 4)

func _gui_input(event: InputEvent) -> void:
	if manager == null:
		return
	if compact:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			manager.select_member(member_index)
			accept_event()
		return
	if inventory.locked or manager.selected_member_index != member_index:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_at(event.position)
		var hit := inventory.item_at(cell)
		if not hit.is_empty():
			selected_instance = hit
			var instance := inventory.get_instance(hit)
			_grab_offset = cell - Vector2i(instance["cell"])
			selection_changed.emit(instance["item_id"])
		elif not selected_instance.is_empty():
			var moved := manager.move_item(selected_instance, cell)
			feedback.emit("已调整位置" if moved else "此处放不下：不能越界或与其他装备重叠")
		queue_redraw()
		accept_event()

func drag_data_at(point: Vector2) -> Dictionary:
	if manager == null or compact or inventory.locked or manager.selected_member_index != member_index:
		return {}
	var cell := _cell_at(point)
	var hit := inventory.item_at(cell)
	if hit.is_empty():
		return {}
	var instance := inventory.get_instance(hit)
	selected_instance = hit
	_drag_instance = hit
	_grab_offset = cell - Vector2i(instance["cell"])
	selection_changed.emit(instance["item_id"])
	return {"source": get_instance_id(), "generation": _generation, "member_index": member_index, "instance_id": hit, "offset": _grab_offset}

func _get_drag_data(point: Vector2) -> Variant:
	var data := drag_data_at(point)
	if data.is_empty():
		return null
	var item := manager.registry.get_item(inventory.get_instance(data["instance_id"])["item_id"])
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
	if compact or not data is Dictionary or data.get("source") != get_instance_id() or data.get("generation") != _generation or data.get("member_index") != member_index or member_index != manager.selected_member_index:
		return false
	_hover_cell = _cell_at(point) - Vector2i(data["offset"])
	_drag_instance = data["instance_id"]
	_hover_valid = inventory.can_move(_drag_instance, _hover_cell)
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
