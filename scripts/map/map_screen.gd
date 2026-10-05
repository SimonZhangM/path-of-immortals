@tool
extends Control

const MIN_ZOOM := 1.0
const MAX_ZOOM := 1.75
const ZOOM_STEP := 1.1

@export_file("*.json") var definition_path := "res://data/maps/qingshihewan.json"
@export var inventory_save_path := MapLoadoutStore.DEFAULT_PATH
var loadout: MapLoadoutState
var _saved_loadout_revision := -1
var definition: Dictionary = {}
var startup_error: String = ""
var zoom_factor := 1.25
var _dragging := false
var _pointer_down := false
var _press_position := Vector2.ZERO
var _drag_delta := Vector2.ZERO
var _suppress_click := false
var _cursor_position := Vector2(-1, -1)
var travel: MapTravelState
var player: MapPlayer
var event_registry: MapEventRegistry
var event_state: MapEventState
var dialogue: MapDialogue
var reward_dialog: MapRewardDialog
var encounter_dialog: MapEncounterDialog
var _encounter_enemies: Dictionary = {}
var exit_dialog: MapExitDialog
var exits_by_point: Dictionary = {}
var _active_exit: Dictionary = {}
var arrival_point_id := ""
var arrival_facing := ""
var sign_motion: MapSignMotion
var player_status: MapPlayerStatus
var status_header: MapStatusHeader
var inventory_screen: MapInventoryScreen
var inventory_catalog: MapInventoryCatalog
var _last_view_size := Vector2.ZERO
@onready var map_viewport: Control = $MapViewport
@onready var content: Node2D = $MapViewport/MapContent

func _ready() -> void:
	# Re-rasterize text at its displayed size inside scaled map/UI groups.
	set_deferred("oversampling_with_scale", CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(definition_path))
	if not raw is Dictionary or not raw.has("source_size") or raw["source_size"].size() != 2:
		startup_error = "地图元信息无效：" + definition_path
		push_error(startup_error)
		return
	definition = raw
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	mouse_exited.connect(_clear_hover)
	resized.connect(_fit_map)
	_fit_map()
	if not Engine.is_editor_hint():
		_setup_player()
		if startup_error.is_empty():
			_setup_events()
		if startup_error.is_empty():
			_setup_status_header()

func _setup_status_header() -> void:
	var registry := ContentRegistry.new()
	if not registry.load_base_content():
		startup_error = "地图玩家状态配置无效：" + "; ".join(registry.errors)
		push_error(startup_error)
		return
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json"))
	if not config is Dictionary:
		startup_error = "地图顶部栏配置无效。"
		push_error(startup_error)
		return
	player_status = MapPlayerStatus.new()
	startup_error = player_status.configure(registry, config)
	if not startup_error.is_empty():
		push_error(startup_error)
		return
	status_header = MapStatusHeader.new()
	startup_error = status_header.configure(player_status, config)
	if not startup_error.is_empty():
		push_error(startup_error)
		status_header.free()
		status_header = null
		return
	add_child(status_header)
	status_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_header.map_title.visible = bool(definition.get("show_map_title", true))
	_setup_inventory(registry)

func _setup_inventory(registry: ContentRegistry) -> void:
	inventory_save_path = MapLoadoutStore.session_path(inventory_save_path)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var character := registry.get_character(player_status.character_id)
	inventory_catalog = MapInventoryCatalog.new()
	inventory_catalog.configure(config)
	var created := MapLoadoutStore.create_state(registry, registry.get_board(character.board_layout))
	startup_error = created.error
	if not startup_error.is_empty():
		push_error(startup_error)
		return
	loadout = created.state
	startup_error = MapLoadoutStore.load_into(loadout, inventory_save_path)
	if not startup_error.is_empty():
		loadout = null
		push_error(startup_error)
		return
	event_state.reward_claimed = loadout.has_reward
	for event: Dictionary in event_registry.events.values():
		if event.type == "encounter":
			var enemy := registry.get_enemy(event.enemy_id)
			if enemy.is_empty() or not ResourceLoader.exists(enemy.get("portrait", ""), "Texture2D"):
				startup_error = "地图遭遇引用了未知敌人或头像。"
				push_error(startup_error)
				return
			_encounter_enemies[event.id] = PartyMemberState.new(enemy, registry)
		if event.has("reward") and not loadout.records.has(event.reward.item_id):
			startup_error = "剧情奖励引用了未知物品。"
			push_error(startup_error)
			return
	inventory_catalog.replace_entries(loadout.storage_records())
	inventory_screen = MapInventoryScreen.new()
	inventory_screen.configure(inventory_catalog, config, registry.get_board(character.board_layout), loadout, player_status)
	inventory_screen.formation_save_callback = _save_loadout
	add_child(inventory_screen)
	inventory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_screen.close_requested.connect(func(): set_inventory_open(false))
	if sign_motion != null:
		inventory_screen.visibility_changed.connect(func(): sign_motion.set_suspended(inventory_screen.visible))
		sign_motion.set_suspended(inventory_screen.visible)

func is_inventory_open() -> bool:
	return inventory_screen != null and inventory_screen.visible

func is_exit_open() -> bool:
	return exit_dialog != null and exit_dialog.visible

func set_inventory_open(open: bool) -> void:
	if inventory_screen == null or is_exit_open() or (open and event_state != null and event_state.is_active()):
		return
	if is_inventory_open() == open:
		return
	if not open:
		inventory_screen.close_formation_dialog()
		inventory_screen.cancel_item_drag()
		var save_error := _save_loadout()
		if not save_error.is_empty():
			var notice := AcceptDialog.new()
			notice.dialog_text = save_error
			add_child(notice)
			notice.confirmed.connect(notice.queue_free)
			notice.popup_centered()
			return
	inventory_screen.visible = open
	status_header.map_title.visible = not open and bool(definition.get("show_map_title", true))
	_end_drag()
	_clear_hover()
	if open:
		player.pause()
	else:
		inventory_screen.search.release_focus()
		player.play()

func _save_loadout() -> String:
	if Engine.is_editor_hint() or loadout == null or _saved_loadout_revision == loadout.revision:
		return ""
	var error := MapLoadoutStore.save(loadout, inventory_save_path)
	if error.is_empty():
		_saved_loadout_revision = loadout.revision
	return error

func _exit_tree() -> void:
	var error := _save_loadout()
	if not error.is_empty():
		push_error(error)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_exit_open():
		if event.keycode == KEY_ESCAPE:
			_cancel_exit()
		get_viewport().set_input_as_handled()
		return
	if event_state != null and event_state.is_active():
		if event_state.phase == "encounter":
			if event.keycode == KEY_ESCAPE:
				_retreat_encounter()
			get_viewport().set_input_as_handled()
			return
		if (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE) and dialogue != null and dialogue.visible:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if is_inventory_open() and inventory_screen.is_formation_dialog_open():
		if event.keycode == KEY_ESCAPE or (event.is_action_pressed("map_inventory") and not (get_viewport().gui_get_focus_owner() is LineEdit)):
			inventory_screen.close_formation_dialog()
			get_viewport().set_input_as_handled()
		return
	if is_inventory_open() and event.keycode == KEY_ESCAPE:
		set_inventory_open(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map_inventory"):
		# Typing I in a search field must not close the interface.
		if is_inventory_open() and get_viewport().gui_get_focus_owner() is LineEdit:
			return
		set_inventory_open(not is_inventory_open())
		get_viewport().set_input_as_handled()

func _setup_events() -> void:
	var files: Variant = definition.get("event_files", [])
	if not files is Array:
		startup_error = "地图事件文件列表无效。"
		push_error(startup_error)
		return
	event_registry = MapEventRegistry.new()
	startup_error = event_registry.load_files(files, travel.node_positions.keys())
	if not startup_error.is_empty():
		push_error(startup_error)
		return
	dialogue = MapDialogue.new()
	startup_error = dialogue.prepare(event_registry)
	if not startup_error.is_empty():
		push_error(startup_error)
		dialogue.free()
		dialogue = null
		return
	event_state = MapEventState.new(event_registry)
	event_state.encounter_changed.connect(_on_encounter_changed)
	add_child(dialogue)
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue.advance_requested.connect(_advance_dialogue)
	reward_dialog = MapRewardDialog.new()
	add_child(reward_dialog)
	reward_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_dialog.accept_requested.connect(_accept_reward)
	encounter_dialog = MapEncounterDialog.new()
	add_child(encounter_dialog)
	encounter_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_dialog.fight_requested.connect(_confirm_encounter)
	encounter_dialog.retreat_requested.connect(_retreat_encounter)
	startup_error = _configure_exits(definition.get("exits", []))
	if not startup_error.is_empty():
		push_error(startup_error)
		return
	if not exits_by_point.is_empty():
		exit_dialog = MapExitDialog.new()
		add_child(exit_dialog)
		exit_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		exit_dialog.cancelled.connect(_cancel_exit)
		exit_dialog.confirmed.connect(_confirm_exit)
	travel.node_arrived.connect(_on_node_arrived)
	if definition.has("sign_motion"):
		sign_motion = MapSignMotion.new()
		add_child(sign_motion)
		startup_error = sign_motion.configure(content.get_node("Points"), map_viewport, definition.sign_motion)
		if not startup_error.is_empty():
			push_error(startup_error)
			return
	_sync_completed_signs()

func _configure_exits(configs: Variant) -> String:
	if not configs is Array:
		return "地图出口列表无效。"
	var checked := {}
	for config: Variant in configs:
		if not config is Dictionary:
			return "地图出口配置无效。"
		for key in ["point_id", "title", "scene", "target_point"]:
			if not config.get(key) is String or config[key].strip_edges().is_empty():
				return "地图出口字段无效：" + key
		if not travel.node_positions.has(config.point_id) or checked.has(config.point_id) or not ResourceLoader.exists(config.scene, "PackedScene"):
			return "地图出口节点重复、缺失或目标场景无效。"
		if config.has("target_facing") and config.target_facing not in ["left", "right"]:
			return "地图出口目标朝向无效。"
		checked[config.point_id] = config.duplicate(true)
	exits_by_point = checked
	return ""

func _sync_completed_signs(animate: bool = false) -> void:
	for point: MapRoutePoint in content.get_node("Points").get_children():
		var event_id: String = event_registry.by_point.get(point.point_id, "")
		if event_state.completed.has(event_id) and point.has_node("Sign"):
			if sign_motion != null:
				sign_motion.complete(point.point_id, animate)
			else:
				point.get_node("Sign").hide()

func _on_encounter_changed(event_id: String) -> void:
	var point_id: String = event_registry.events[event_id].point_id
	if event_state.completed.has(event_id):
		_sync_completed_signs(true)
	elif sign_motion != null:
		sign_motion.restore(point_id)
	else:
		for point: MapRoutePoint in content.get_node("Points").get_children():
			if point.point_id == point_id and point.has_node("Sign"):
				point.get_node("Sign").show()

func _advance_dialogue() -> void:
	if event_state == null or not event_state.is_active():
		return
	var completed_id := event_state.advance()
	_present_event_progress(completed_id)

func _present_event_progress(completed_id: String = "") -> void:
	if not completed_id.is_empty():
		dialogue.hide()
		reward_dialog.hide()
		travel.paused = false
		_sync_completed_signs(true)
		_end_drag()
		_clear_hover()
	elif event_state.phase == "encounter":
		dialogue.hide()
		reward_dialog.hide()
		encounter_dialog.present(event_state.active_event(), _encounter_enemies[event_state.active_id])
	elif event_state.phase == "reward":
		dialogue.hide()
		var reward: Dictionary = event_state.active_event().reward
		var record: Dictionary = loadout.records[reward.item_id].duplicate(true)
		record.quantity = reward.quantity
		record.identified = loadout.can_use_item(reward.item_id)
		reward_dialog.present(record, inventory_catalog.category_names.get(record.category, "法器"))
	else:
		reward_dialog.hide()
		dialogue.present(event_state.active_event(), event_state.current_line(), event_state.current_speaker_id(), event_state.phase)

func _accept_reward() -> void:
	if event_state.phase != "reward" or reward_dialog.accept_button.disabled:
		return
	reward_dialog.accept_button.disabled = true
	var error := MapLoadoutStore.claim_reward(loadout, event_state.active_event().reward, inventory_save_path)
	if not error.is_empty():
		reward_dialog.error_label.text = error
		reward_dialog.accept_button.disabled = false
		return
	_saved_loadout_revision = loadout.revision
	reward_dialog.pick_sound.play()
	_present_event_progress(event_state.accept_reward())

func _on_node_arrived(point_id: String) -> void:
	_try_start_event(point_id, "arrival", true)

func _retreat_encounter() -> void:
	if event_state.phase != "encounter" or encounter_dialog.retreat_button.disabled:
		return
	travel.stop_at_current_node()
	event_state.cancel_encounter()
	encounter_dialog.hide()
	travel.paused = false
	player.present(travel)
	_end_drag()
	_clear_hover()

func _confirm_encounter() -> void:
	if event_state.phase != "encounter" or encounter_dialog.fight_button.disabled:
		return
	encounter_dialog.set_busy(true)
	_start_encounter_battle.call_deferred()

func _encounter_error(message: String) -> void:
	encounter_dialog.error_label.text = message
	encounter_dialog.set_busy(false)

func _start_encounter_battle() -> void:
	if event_state.phase != "encounter" or not encounter_dialog.visible:
		return
	var error := _save_loadout()
	if not error.is_empty():
		_encounter_error(error)
		return
	var event := event_state.active_event()
	var scene := load(String(event.battle_scene)) as PackedScene
	if scene == null:
		_encounter_error("战斗场景暂时无法载入，请重试。")
		return
	var battle := scene.instantiate()
	var manager := battle.get_node_or_null("GameManager") as GameManager
	if manager == null:
		battle.free()
		_encounter_error("战斗入口配置无效。")
		return
	manager.enemy_id = event.enemy_id
	manager.use_saved_loadout = true
	manager.loadout_save_path = inventory_save_path
	var battle_ui := battle.get_node_or_null("MainUI")
	if battle_ui == null or scene_file_path.is_empty():
		battle.free()
		_encounter_error("战斗返回入口配置无效。")
		return
	if battle_ui != null and event.presentation.has("battle_background"):
		battle_ui.battle_background_path = event.presentation.battle_background
	var return_flow := MapBattleReturn.new()
	return_flow.name = "MapBattleReturn"
	return_flow.manager = manager
	return_flow.events = event_state
	return_flow.event_id = event.id
	return_flow.map_scene_path = scene_file_path
	return_flow.point_id = event.point_id
	return_flow.facing = "left" if player.flip_h else "right"
	return_flow.save_path = inventory_save_path
	battle.add_child(return_flow)
	battle_ui.battle_exit_handler = return_flow.return_to_map
	get_tree().root.add_child(battle)
	if not manager.startup_error.is_empty():
		battle.queue_free()
		_encounter_error("战斗载入失败：" + manager.startup_error)
		return
	manager.start_battle()
	if manager.simulation.state.phase != GameState.Phase.BATTLE:
		var reason := manager.simulation.configuration_error
		battle.queue_free()
		_encounter_error("暂时无法开战。" + reason)
		return
	get_tree().current_scene = battle
	queue_free()

func _try_open_exit(point_id: String) -> bool:
	if exit_dialog == null or is_exit_open() or is_inventory_open() or event_state.is_active() or travel.mode != "idle" or point_id != travel.current_node_id or not exits_by_point.has(point_id):
		return false
	_active_exit = exits_by_point[point_id].duplicate(true)
	travel.paused = true
	exit_dialog.present(_active_exit.title)
	_end_drag()
	_clear_hover()
	return true

func _cancel_exit() -> void:
	if not is_exit_open() or exit_dialog.cancel_button.disabled:
		return
	exit_dialog.hide()
	_active_exit.clear()
	travel.paused = false
	_end_drag()
	_clear_hover()

func _confirm_exit() -> void:
	if not is_exit_open() or exit_dialog.confirm_button.disabled:
		return
	exit_dialog.set_busy(true)
	_complete_exit.call_deferred()

func _complete_exit() -> void:
	if _active_exit.is_empty() or not is_exit_open() or travel.current_node_id != _active_exit.point_id:
		return
	var error := _save_loadout()
	if not error.is_empty():
		exit_dialog.error_label.text = error
		exit_dialog.set_busy(false)
		return
	var scene := load(String(_active_exit.scene)) as PackedScene
	if scene == null:
		exit_dialog.error_label.text = "暂时无法前往，请稍后重试。"
		exit_dialog.set_busy(false)
		return
	# Preserve the configured inventory path (including isolated test saves).
	var destination = scene.instantiate()
	destination.inventory_save_path = inventory_save_path
	destination.arrival_point_id = _active_exit.target_point
	destination.arrival_facing = _active_exit.get("target_facing", "")
	# Validate before entering the tree, so malformed links cannot load/save a map.
	var target_points := destination.get_node_or_null("MapViewport/MapContent/Points")
	var target_found := false
	if target_points != null:
		for point in target_points.get_children():
			if point is MapRoutePoint and point.point_id == destination.arrival_point_id:
				target_found = true
				break
	if not target_found:
		destination.free()
		exit_dialog.error_label.text = "目的地路径节点不存在。"
		exit_dialog.set_busy(false)
		return
	get_tree().root.add_child(destination)
	if not destination.startup_error.is_empty():
		exit_dialog.error_label.text = "目的地图加载失败，请稍后重试。"
		exit_dialog.set_busy(false)
		destination.queue_free()
		return
	get_tree().current_scene = destination
	queue_free()

func _try_start_event(point_id: String, trigger: String, stationary: bool) -> bool:
	if event_state.try_start(point_id, travel.current_node_id, stationary, trigger):
		travel.paused = true
		_end_drag()
		_clear_hover()
		_present_event_progress()
		return true
	return false

func _setup_player() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/player.json"))
	if not arrival_facing.is_empty():
		config.initial_facing = arrival_facing
	var positions := {}
	for point: MapRoutePoint in content.get_node("Points").get_children():
		positions[point.point_id] = content.to_local(point.global_position)
	var edges: Array[Dictionary] = []
	for route: MapRoute in content.get_node("Routes").get_children():
		route.sync_endpoints()
		var curve := Curve2D.new()
		curve.bake_interval = route.curve.bake_interval
		for i in route.curve.point_count:
			var p := route.curve.get_point_position(i)
			var mapped := content.to_local(route.to_global(p))
			var incoming := content.to_local(route.to_global(p + route.curve.get_point_in(i))) - mapped
			var outgoing := content.to_local(route.to_global(p + route.curve.get_point_out(i))) - mapped
			curve.add_point(mapped, incoming, outgoing)
		edges.append({"id": route.route_id, "from": route.get_node(route.start_point).point_id, "to": route.get_node(route.end_point).point_id, "curve": curve})
	travel = MapTravelState.new()
	var start_id: String = arrival_point_id if not arrival_point_id.is_empty() else definition.get("start_point", config.start_point)
	startup_error = travel.configure(positions, edges, start_id, config.walk_speed, config.run_speed)
	if not startup_error.is_empty():
		push_error(startup_error)
		travel = null
		return
	player = MapPlayer.new()
	player.name = "MapPlayer"
	startup_error = player.configure(config)
	if not startup_error.is_empty():
		push_error(startup_error)
		player.free()
		player = null
		travel = null
		return
	content.add_child(player)
	player.position = travel.map_position
	# Start with the player visible. Subsequent camera movement stays manual.
	content.position = map_viewport.size * 0.5 - player.position * content.scale
	_clamp_position()

func _process(delta: float) -> void:
	if is_inventory_open() or is_exit_open():
		return
	if travel != null and player != null:
		if event_state == null or not event_state.is_active():
			travel.advance(delta)
		player.present(travel)

func _select_destination(pointer: Vector2) -> void:
	if travel == null or is_inventory_open() or is_exit_open() or (event_state != null and event_state.is_active()):
		return
	var closest_id := _node_at(pointer)
	if not closest_id.is_empty():
		if _try_open_exit(closest_id):
			return
		if _try_start_event(closest_id, "click", travel.mode == "idle"):
			return
		travel.request_destination(closest_id)
		player.present(travel)

func _node_at(pointer: Vector2) -> String:
	if not is_instance_valid(content) or not map_viewport.get_rect().has_point(pointer):
		return ""
	var closest_id := ""
	var closest_distance := INF
	# Constant minimum hit target, expanding with the drawn marker when zoomed.
	var radius := maxf(18.0, 22.4 * content.scale.x + 4.0)
	for point: MapRoutePoint in content.get_node("Points").get_children():
		var screen_position := map_to_screen(content.to_local(point.global_position))
		var distance := pointer.distance_to(screen_position)
		if distance <= radius and distance < closest_distance:
			closest_id = point.point_id
			closest_distance = distance
	return closest_id

func _refresh_cursor() -> void:
	if is_inventory_open() or is_exit_open() or (event_state != null and event_state.is_active()):
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif _dragging:
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _node_at(_cursor_position).is_empty() else Control.CURSOR_ARROW

func _clear_hover() -> void:
	_cursor_position = Vector2(-1, -1)
	_refresh_cursor()

func _source_size() -> Vector2:
	return Vector2(definition["source_size"][0], definition["source_size"][1])

func _fit_scale() -> float:
	# 100% means the image width exactly fills the viewport.
	return size.x / _source_size().x

func map_to_screen(point: Vector2) -> Vector2:
	return map_viewport.position + content.position + point * content.scale

func _fit_map() -> void:
	if definition.is_empty() or size.x <= 0 or size.y <= 0:
		return
	var focus := _source_size() * 0.5
	if _last_view_size != Vector2.ZERO:
		focus = (_last_view_size * 0.5 - content.position) / content.scale
	var header_height := 0.0 if Engine.is_editor_hint() else MapStatusHeader.height_for_width(size.x)
	map_viewport.position = Vector2(0, header_height)
	map_viewport.size = Vector2(size.x, maxf(1.0, size.y - header_height))
	content.scale = Vector2.ONE * _fit_scale() * zoom_factor
	content.position = map_viewport.size * 0.5 - focus * content.scale
	_last_view_size = map_viewport.size
	_clamp_position()

func _clamp_position() -> void:
	var extent := _source_size() * content.scale
	for axis in 2:
		if extent[axis] <= map_viewport.size[axis]:
			content.position[axis] = 0.0 if axis == 1 else (map_viewport.size[axis] - extent[axis]) * 0.5
		else:
			content.position[axis] = clampf(content.position[axis], map_viewport.size[axis] - extent[axis], 0.0)
	_refresh_cursor()

func _zoom_at(factor: float, anchor: Vector2) -> void:
	var next_zoom := clampf(factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom_factor):
		return
	var local_anchor := anchor - map_viewport.position
	var map_position := (local_anchor - content.position) / content.scale
	zoom_factor = next_zoom
	content.scale = Vector2.ONE * _fit_scale() * zoom_factor
	content.position = local_anchor - map_position * content.scale
	_clamp_position()

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or definition.is_empty():
		return
	if is_inventory_open() or is_exit_open() or (event_state != null and event_state.is_active()):
		accept_event()
		return
	if event is InputEventMouse and not map_viewport.get_rect().has_point(event.position):
		_end_drag()
		_clear_hover()
		accept_event()
		return
	if event is InputEventMouse:
		_cursor_position = event.position
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pointer_down = true
				_dragging = false
				_suppress_click = false
				_press_position = event.position
				_drag_delta = Vector2.ZERO
			else:
				if _pointer_down and not _dragging and not _suppress_click and event.position.distance_to(_press_position) <= 6.0:
					_select_destination(event.position)
				_end_drag()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			_suppress_click = true
			var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_zoom_at(zoom_factor * pow(ZOOM_STEP, direction), event.position)
			accept_event()
	elif event is InputEventMouseMotion and _pointer_down:
		# Also recover if the mouse was released outside the game window.
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_end_drag()
			return
		if not _dragging:
			_drag_delta += event.relative
			if _drag_delta.length() <= 6.0:
				_refresh_cursor()
				return
			_dragging = true
			mouse_default_cursor_shape = Control.CURSOR_MOVE
			content.position += _drag_delta
		else:
			content.position += event.relative
		_clamp_position()
		accept_event()
	_refresh_cursor()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if inventory_screen != null:
			inventory_screen.cancel_item_drag()
		_end_drag()
		_clear_hover()

func _end_drag() -> void:
	_dragging = false
	_pointer_down = false
	_refresh_cursor()
