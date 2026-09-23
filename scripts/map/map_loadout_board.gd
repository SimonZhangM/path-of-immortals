class_name MapLoadoutBoard
extends TextureRect

var state: MapLoadoutState
var layout: BoardLayout
var _items: Dictionary = {}
var _hover_cell := Vector2i(-1, -1)
var _hover_dimensions := Vector2i.ZERO
var _hover_valid := false
var _hover_swap := false
const SWAP_COLOR := Color(0.55, 0.8, 1.0, 0.32)
var _drag_active := false

func configure(model: MapLoadoutState) -> void:
	state = model
	layout = state.board
	texture = load(layout.texture_path)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	state.changed.connect(_refresh_items)
	resized.connect(_layout_items)
	mouse_exited.connect(func(): _hover_dimensions = Vector2i.ZERO; queue_redraw())
	_refresh_items()

func _refresh_items() -> void:
	for art in _items.values():
		remove_child(art)
		art.queue_free()
	_items.clear()
	for entry in state.inventory.get_instances():
		var art := MapItemArtwork.new()
		art.configure(state.records[entry.item_id])
		add_child(art)
		_items[entry.instance_id] = art
	_layout_items()

func _layout_items() -> void:
	if state == null:
		return
	for entry in state.inventory.get_instances():
		var rect := ItemDragPreview.artwork_rect(layout.footprint_rect(entry.cell, state.registry.get_item(entry.item_id).grid_size, size))
		_items[entry.instance_id].position = rect.position
		_items[entry.instance_id].size = rect.size
	queue_redraw()

func nearest_cell(point: Vector2, dimensions: Vector2i) -> Vector2i:
	var closest := Vector2i(-1, -1)
	var distance := INF
	for y in range(state.inventory.grid_size.y - dimensions.y + 1):
		for x in range(state.inventory.grid_size.x - dimensions.x + 1):
			var cell := Vector2i(x, y)
			var candidate := layout.footprint_rect(cell, dimensions, size).get_center().distance_squared_to(point)
			if candidate < distance:
				distance = candidate
				closest = cell
	return closest

func make_preview(data: Dictionary) -> Control:
	var entry := state.drag_entry(data)
	if entry.is_empty():
		return null
	var holder := Control.new()
	holder.name = "MapItemDragPreview"
	holder.z_index = 100
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := MapItemArtwork.new()
	art.configure(state.records[entry.item_id])
	var dimensions := state.registry.get_item(entry.item_id).grid_size
	art.size = ItemDragPreview.artwork_rect(layout.footprint_rect(Vector2i.ZERO, dimensions, size)).size * get_global_transform().get_scale().abs()
	art.position = -art.size * 0.5
	holder.add_child(art)
	return holder

func _get_tooltip(at_position: Vector2) -> String:
	if state == null:
		return ""
	return state.inventory.item_at(layout.cell_at(at_position, size))

func _make_custom_tooltip(for_text: String) -> Object:
	var entry := state.inventory.get_instance(for_text)
	if entry.is_empty():
		return null
	var tooltip := ItemTooltip.new()
	tooltip.configure(state.registry.get_item(entry.item_id), entry, -1, 0, state.can_use_item(entry.item_id))
	return tooltip

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var id := state.inventory.item_at(layout.cell_at(event.position, size))
	if id.is_empty():
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		state.take_back(state.drag_data("board", id))
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_begin_drag.call_deferred(state.drag_data("board", id))
		accept_event()

func _begin_drag(data: Dictionary) -> void:
	if not is_visible_in_tree() or not state.valid_drag(data) or get_viewport().gui_is_dragging():
		return
	_drag_active = true
	state.interaction.emit("pick")
	force_drag(data, make_preview(data))
	if _items.has(data.id):
		_items[data.id].modulate.a = 0.25

func _can_drop_data(point: Vector2, data: Variant) -> bool:
	_hover_dimensions = Vector2i.ZERO
	_hover_valid = false
	_hover_swap = false
	var entry := state.drag_entry(data)
	if entry.is_empty() or not layout.footprint_rect(Vector2i.ZERO, state.inventory.grid_size, size).has_point(point):
		queue_redraw()
		return false
	_hover_dimensions = state.registry.get_item(entry.item_id).grid_size
	_hover_cell = nearest_cell(point, _hover_dimensions)
	var kind := state.placement_kind(data, _hover_cell)
	_hover_valid = kind != "invalid"
	_hover_swap = kind == "swap"
	queue_redraw()
	return _hover_valid

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		state.place(data, _hover_cell)
	_hover_dimensions = Vector2i.ZERO
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _drag_active and not get_viewport().gui_is_drag_successful():
			state.interaction.emit("invalid")
		_drag_active = false
		_hover_dimensions = Vector2i.ZERO
		for art in _items.values():
			art.modulate.a = 1.0
		queue_redraw()

func _draw() -> void:
	if _hover_dimensions == Vector2i.ZERO or not get_viewport().gui_is_dragging():
		return
	for y in _hover_dimensions.y:
		for x in _hover_dimensions.x:
			var rect := layout.footprint_rect(_hover_cell + Vector2i(x, y), Vector2i.ONE, size).grow(-3)
			var color := Color(0.3, 0.85, 0.55, 0.25) if _hover_valid else Color(0.9, 0.25, 0.3, 0.3)
			if _hover_swap:
				color = SWAP_COLOR
			draw_rect(rect, color)
			draw_rect(rect, Color(color, 0.7), false, 1.0)
