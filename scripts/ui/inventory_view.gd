class_name InventoryView
extends Control

signal selection_changed(item_id: String)
signal feedback(message: String)

var manager: GameManager
var member_index: int = 0
var enemy_side: bool = false
var compact: bool = false
var display_side: float = 0.0
var inventory: InventoryState:
	get:
		if manager == null:
			return null
		return (manager.enemies if enemy_side else manager.party)[member_index].inventory
var selected_instance: String = ""
var _grab_offset := Vector2i.ZERO
var _hover_cell := Vector2i(-100, -100)
var _hover_valid: bool = false
var _drag_instance: String = ""
var _generation: int = 0
var _textures: Dictionary = {}
var _last_time_usec: int = -1
var board_layout := BoardLayout.plain()
var board_texture: Texture2D
var _tooltip_entry: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(220, 220) if compact else Vector2(495, 495)
	if display_side > 0:
		custom_minimum_size = Vector2.ONE * display_side
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): _hover_cell = Vector2i(-100, -100); queue_redraw())

func bind_game(game: GameManager, index: int = 0, is_enemy: bool = false) -> void:
	manager = game
	member_index = index
	enemy_side = is_enemy
	var member: PartyMemberState = (manager.enemies if enemy_side else manager.party)[index]
	var mapped := manager.registry.get_board(member.definition.get("board_layout", ""))
	if mapped != null:
		board_layout = mapped
		board_texture = load(mapped.texture_path)
	manager.inventory_changed.connect(queue_redraw)
	manager.battle_restarted.connect(reset_interaction)
	manager.battle_started.connect(reset_interaction)
	manager.formation_changed.connect(reset_interaction)
	manager.adjustment_changed.connect(reset_interaction)
	manager.selection_changed.connect(queue_redraw)
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
	return board_layout.footprint_rect(Vector2i.ZERO, InventoryState.GRID_SIZE, size)

func cell_center(cell: Vector2i) -> Vector2:
	return board_layout.footprint_rect(cell, Vector2i.ONE, size).get_center()

func _cell_at(point: Vector2) -> Vector2i:
	return board_layout.cell_at(point, size)

func _draw() -> void:
	if manager == null or inventory == null:
		return
	var area := grid_rect()
	if board_texture != null:
		draw_texture_rect(board_texture, board_layout.art_rect(size), false)
	if not enemy_side and manager.adjustment_open and manager.selected_member_index == member_index:
		draw_rect(area.grow(7), Color("f4d48e"), false, 4)
	for instance in inventory.get_instances():
		var item := manager.registry.get_item(instance["item_id"])
		if not _textures.has(item.id) and not item.icon_path.is_empty():
			_textures[item.id] = load(item.icon_path)
		var rect := board_layout.footprint_rect(instance["cell"], item.grid_size, size).grow(-4)
		var active: bool = instance["instance_id"] == selected_instance
		if active and manager.can_edit_inventory():
			draw_rect(rect, Color("e5c181"), false, 2)
		var tiny_pill := compact and item.is_consumable()
		var caption_height := 0.0 if tiny_pill else (20.0 if compact else 30.0)
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
		if not tiny_pill:
			draw_string_outline(get_theme_default_font(), rect.position + Vector2(0, rect.size.y - 6), item.display_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12 if compact else 18, 3, Color("18252c"))
			draw_string(get_theme_default_font(), rect.position + Vector2(0, rect.size.y - 6), item.display_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12 if compact else 18, Color("e4d8b7"))
		var remaining := manager.simulation.cooling_remaining_usec(instance["instance_id"])
		if remaining > 0:
			draw_rect(rect, Color(0.25, 0.27, 0.29, 0.88))
			draw_string(get_theme_default_font(), Vector2(rect.position.x, rect.get_center().y + 10), "%ds" % ceili(remaining / 1_000_000.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24 if compact else 34, Color.WHITE)
		if item.is_consumable():
			var badge_size := Vector2(19, 20) if compact else Vector2(28, 25)
			var badge := Rect2(rect.end - badge_size, badge_size)
			draw_rect(badge, Color("152124"))
			draw_string(get_theme_default_font(), badge.position + Vector2(0, badge_size.y - 4), str(instance["units"].size()), HORIZONTAL_ALIGNMENT_CENTER, badge_size.x, 13 if compact else 16, Color("f4d48e"))
	if not _drag_instance.is_empty() and _hover_cell.x > -100:
		var instance := inventory.get_instance(_drag_instance)
		if not instance.is_empty():
			var dimensions := manager.registry.get_item(instance["item_id"]).grid_size
			var preview := board_layout.footprint_rect(_hover_cell, dimensions, size).grow(-3)
			var tint := Color("7ed6ad") if _hover_valid else Color("ee857a")
			draw_rect(preview, Color(tint, 0.22))
			draw_rect(preview, tint, false, 4)

func _gui_input(event: InputEvent) -> void:
	if manager == null:
		return
	if not enemy_side and event is InputEventMouseButton and event.pressed:
		manager.select_member(member_index)
	if enemy_side or inventory.locked or not manager.can_edit_inventory():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var hit := inventory.item_at(_cell_at(event.position))
		if not hit.is_empty():
			manager.unequip(member_index, hit)
			reset_interaction()
		accept_event()
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
			var moved := manager.move_item(member_index, selected_instance, cell)
			feedback.emit("已调整位置" if moved else "此处放不下：不能越界或与其他装备重叠")
		queue_redraw()
		accept_event()

func drag_data_at(point: Vector2) -> Dictionary:
	if manager == null or enemy_side or inventory.locked or not manager.can_edit_inventory():
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
	return {"kind": "inventory", "epoch": manager.interaction_epoch, "source": get_instance_id(), "generation": _generation, "member_index": member_index, "instance_id": hit, "offset": _grab_offset}

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
	preview.size = board_layout.footprint_rect(inventory.get_instance(data["instance_id"])["cell"], item.grid_size, size).size
	preview.modulate.a = 0.7
	preview.position = -Vector2(_grab_offset) * grid_rect().size.x / 4.0 - Vector2.ONE * 22
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	set_drag_preview(holder)
	return data

func _can_drop_data(point: Vector2, data: Variant) -> bool:
	if manager != null and not enemy_side and data is Dictionary and data.get("kind") == "storage" and data.get("epoch") == manager.interaction_epoch:
		var cell := _cell_at(point)
		return Rect2i(Vector2i.ZERO, InventoryState.GRID_SIZE).has_point(cell) and manager.can_equip(data["storage_id"], member_index, cell)
	if manager == null or enemy_side or not manager.can_edit_inventory() or not data is Dictionary or data.get("source") != get_instance_id() or data.get("generation") != _generation or data.get("member_index") != member_index:
		return false
	_hover_cell = _cell_at(point) - Vector2i(data["offset"])
	_drag_instance = data["instance_id"]
	_hover_valid = inventory.can_move(_drag_instance, _hover_cell)
	queue_redraw()
	return _hover_valid

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		if data.get("kind") == "storage":
			manager.equip(data["storage_id"], member_index, _cell_at(point))
		else:
			manager.move_item(member_index, data["instance_id"], _hover_cell)
		feedback.emit("已调整位置")
	_drag_instance = ""
	_hover_cell = Vector2i(-100, -100)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_instance = ""
		_hover_cell = Vector2i(-100, -100)
		queue_redraw()

func _get_tooltip(at_position: Vector2) -> String:
	if inventory == null:
		return ""
	var entry := inventory.get_instance(inventory.item_at(_cell_at(at_position)))
	if entry.is_empty():
		return ""
	var item := manager.registry.get_item(entry["item_id"])
	_tooltip_entry = entry
	return item.id

func _make_custom_tooltip(_for_text: String) -> Object:
	if _tooltip_entry.is_empty():
		return null
	var item := manager.registry.get_item(_tooltip_entry["item_id"])
	var panel := ItemTooltip.new()
	var owner: PartyMemberState = (manager.enemies if enemy_side else manager.party)[member_index]
	panel.configure(item, _tooltip_entry, owner.defense, manager.simulation.cooling_remaining_usec(_tooltip_entry["instance_id"]))
	return panel
