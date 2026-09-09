class_name InventoryView
extends Control

signal selection_changed(item_id: String)
signal feedback(message: String)

const PULSE_DURATION := 0.24
const FLASH_SHADER := preload("res://scripts/ui/item_flash.gdshader")
var _pulses: Dictionary = {}

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
var _hover_item: ItemData
var _drag_preview: ItemDragPreview
var _generation: int = 0
var _native_drag_active: bool = false
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
	manager.adjustment_changed.connect(reset_interaction)
	manager.selection_changed.connect(queue_redraw)
	manager.presentation_events.connect(_on_presentation_events)
	for instance in inventory.get_instances():
		var item := manager.registry.get_item(instance["item_id"])
		if not item.icon_path.is_empty():
			_textures[item.id] = load(item.icon_path)
	queue_redraw()

func set_member(index: int) -> void:
	member_index = index
	reset_interaction()

func _process(delta: float) -> void:
	for id in _pulses.keys():
		_pulses[id]["elapsed"] += delta
		if _pulses[id]["elapsed"] >= PULSE_DURATION:
			_pulses[id]["overlay"].queue_free()
			_pulses.erase(id)
		queue_redraw()
	if manager != null and manager.simulation != null:
		var time_usec := manager.simulation.state.time_usec
		if time_usec != _last_time_usec:
			_last_time_usec = time_usec
			queue_redraw()

func _on_presentation_events(events: Array[Dictionary]) -> void:
	var owner: PartyMemberState = (manager.enemies if enemy_side else manager.party)[member_index]
	for event in events:
		if event["kind"] != "item_activated" or event["owner_id"] != owner.id or event["side"] != (1 if enemy_side else 0):
			continue
		var entry: Dictionary = event["entry"]
		var id: String = entry["instance_id"]
		if _pulses.has(id):
			_pulses[id]["overlay"].queue_free()
		var overlay := TextureRect.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.texture = load(manager.registry.get_item(entry["item_id"]).icon_path)
		var flash := ShaderMaterial.new()
		flash.shader = FLASH_SHADER
		overlay.material = flash
		overlay.modulate.a = 0
		add_child(overlay)
		_pulses[id] = {"entry": entry, "elapsed": 0.0, "overlay": overlay}
	queue_redraw()

static func pulse_scale(progress: float) -> float:
	if progress < 0.35:
		return lerpf(1.0, 1.08, sin(progress / 0.35 * PI * 0.5))
	if progress < 0.75:
		return lerpf(1.08, 0.97, smoothstep(0.35, 0.75, progress))
	return lerpf(0.97, 1.0, smoothstep(0.75, 1.0, progress))

func cooldown_progress(instance_id: String) -> float:
	return manager.simulation.activation_progress(instance_id)

func reset_interaction() -> void:
	_generation += 1
	selected_instance = ""
	_drag_instance = ""
	_hover_item = null
	_hover_cell = Vector2i(-100, -100)
	queue_redraw()

func grid_rect() -> Rect2:
	return board_layout.footprint_rect(Vector2i.ZERO, InventoryState.GRID_SIZE, size)

func cell_center(cell: Vector2i) -> Vector2:
	return board_layout.footprint_rect(cell, Vector2i.ONE, size).get_center()

func _cell_at(point: Vector2) -> Vector2i:
	return board_layout.cell_at(point, size)

func nearest_footprint_cell(point: Vector2, dimensions: Vector2i) -> Vector2i:
	var closest := Vector2i.ZERO
	var distance := INF
	for y in range(InventoryState.GRID_SIZE.y - dimensions.y + 1):
		for x in range(InventoryState.GRID_SIZE.x - dimensions.x + 1):
			var cell := Vector2i(x, y)
			var candidate := board_layout.footprint_rect(cell, dimensions, size).get_center().distance_squared_to(point)
			if candidate < distance:
				distance = candidate
				closest = cell
	return closest

func make_drag_preview(item: ItemData, entry: Dictionary) -> Control:
	var holder := Control.new()
	holder.name = "CenteredItemDragPreview"
	holder.z_index = 30
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview = ItemDragPreview.new()
	holder.add_child(_drag_preview)
	_drag_preview.configure(manager, item, entry, board_layout.footprint_rect(entry.get("cell", Vector2i.ZERO), item.grid_size, size).size)
	return holder

func _draw() -> void:
	if manager == null or inventory == null:
		return
	if board_texture != null:
		draw_texture_rect(board_texture, board_layout.art_rect(size), false)
	var visible_items := inventory.get_instances()
	for id in _pulses:
		if inventory.get_instance(id).is_empty():
			visible_items.append(_pulses[id]["entry"])
	for instance in visible_items:
		var item := manager.registry.get_item(instance["item_id"])
		if not _textures.has(item.id) and not item.icon_path.is_empty():
			_textures[item.id] = load(item.icon_path)
		var rect := board_layout.footprint_rect(instance["cell"], item.grid_size, size).grow(-4)
		var icon_rect := rect.grow(-5)
		var id: String = instance["instance_id"]
		var ghost := inventory.get_instance(id).is_empty()
		if _textures.has(item.id):
			var texture: Texture2D = _textures[item.id]
			var icon_size := ItemDragPreview.fitted_icon_rect(texture, rect.grow(4)).size
			if _pulses.has(id):
				var pulse: Dictionary = _pulses[id]
				var t: float = pulse["elapsed"] / PULSE_DURATION
				icon_size *= pulse_scale(t)
				pulse["overlay"].position = icon_rect.get_center() - icon_size * 0.5
				pulse["overlay"].size = icon_size
				pulse["overlay"].modulate.a = 0.26 * sin(PI * t)
			draw_texture_rect(texture, Rect2(icon_rect.get_center() - icon_size * 0.5, icon_size), false)
		if ghost:
			continue
		var remaining := manager.simulation.cooling_remaining_usec(instance["instance_id"])
		if remaining > 0:
			draw_rect(rect, Color(0.25, 0.27, 0.29, 0.42))
			draw_string(get_theme_default_font(), Vector2(rect.position.x, rect.get_center().y + 10), "%ds" % ceili(remaining / 1_000_000.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24 if compact else 34, Color.WHITE)
		if remaining == 0 and item.cooldown_usec > 0:
			var seconds := item.cooldown_usec / 1_000_000.0
			var left := seconds if manager.simulation.state.phase == GameState.Phase.PREPARATION else seconds * (1.0 - cooldown_progress(id))
			CooldownRing.paint(self, rotation_ring_center(rect, item), 23, left, seconds, CooldownRing.tint(manager.registry, item.element))
		if item.is_consumable():
			var badge_size := Vector2(19, 20) if compact else Vector2(28, 25)
			var badge := Rect2(rect.end - badge_size, badge_size)
			draw_rect(badge, Color("152124"))
			draw_string(get_theme_default_font(), badge.position + Vector2(0, badge_size.y - 4), str(instance["units"].size()), HORIZONTAL_ALIGNMENT_CENTER, badge_size.x, 13 if compact else 16, Color("f4d48e"))
	if _hover_item != null and _hover_cell.x > -100:
		var tint := Color("7ed6ad") if _hover_valid else Color("ee857a")
		for y in _hover_item.grid_size.y:
			for x in _hover_item.grid_size.x:
				var preview := board_layout.footprint_rect(_hover_cell + Vector2i(x, y), Vector2i.ONE, size).grow(-3)
				draw_rect(preview, Color(tint, 0.22))
				draw_rect(preview, tint, false, 2)

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
			manager.unequip(member_index, hit, true)
			reset_interaction()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_at(event.position)
		var hit := inventory.item_at(cell)
		if not hit.is_empty():
			selected_instance = hit
			manager.inventory_interaction.emit("pick")
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
	_native_drag_active = true
	var item := manager.registry.get_item(inventory.get_instance(data["instance_id"])["item_id"])
	set_drag_preview(make_drag_preview(item, inventory.get_instance(data["instance_id"])))
	return data

func _can_drop_data(point: Vector2, data: Variant) -> bool:
	_hover_cell = Vector2i(-100, -100)
	_hover_item = null
	queue_redraw()
	if manager == null or enemy_side or not manager.can_edit_inventory() or not data is Dictionary or data.get("epoch") != manager.interaction_epoch or not grid_rect().has_point(point):
		return false
	if data.get("kind") == "storage":
		var entry := manager.storage.peek_one(data.get("storage_id", ""))
		if entry.is_empty():
			return false
		_hover_item = manager.registry.get_item(entry["item_id"])
		_hover_cell = nearest_footprint_cell(point, _hover_item.grid_size)
		var stack := inventory.matching_stack(_hover_item.id)
		if not stack.is_empty():
			_hover_cell = inventory.get_instance(stack)["cell"]
		_hover_valid = manager.can_equip(data["storage_id"], member_index, _hover_cell)
	elif data.get("kind") == "inventory" and data.get("source") == get_instance_id() and data.get("generation") == _generation and data.get("member_index") == member_index:
		var entry := inventory.get_instance(data.get("instance_id", ""))
		if entry.is_empty():
			return false
		_hover_item = manager.registry.get_item(entry["item_id"])
		_hover_cell = nearest_footprint_cell(point, _hover_item.grid_size)
		_drag_instance = data["instance_id"]
		_hover_valid = inventory.can_move(_drag_instance, _hover_cell)
	else:
		return false
	if is_instance_valid(_drag_preview):
		_drag_preview.set_footprint(board_layout.footprint_rect(_hover_cell, _hover_item.grid_size, size).size)
	return _hover_valid

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		if data.get("kind") == "storage":
			manager.equip(data["storage_id"], member_index, _hover_cell)
		else:
			manager.move_item(member_index, data["instance_id"], _hover_cell)
		feedback.emit("已调整位置")
	_drag_instance = ""
	_hover_cell = Vector2i(-100, -100)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _native_drag_active:
			_native_drag_active = false
			if not get_viewport().gui_is_drag_successful():
				manager.inventory_interaction.emit("invalid")
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

static func rotation_ring_center(rect: Rect2, item: ItemData) -> Vector2:
	# Bottom left for stacks reserves bottom right for quantity; otherwise bottom right.
	return Vector2(rect.position.x + 24 if item.is_consumable() else rect.end.x - 24, rect.end.y - 24)
