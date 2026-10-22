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
var exploration: MapExplorationState
var exploration_save_error := ""
var location_save_error := ""
var _location_active := false
var player: MapPlayer
var event_registry: MapEventRegistry
var event_state: MapEventState
var dialogue: MapDialogue
var reward_dialog: MapRewardDialog
var chest_dialog: Control
var chest_observation_dialog: Control
var gathering_dialog: MapGatheringDialog
var gathering_result: Control
var rest_dialog: MapRestDialog
var cultivation_dialog: MapCultivationDialog
var cultivation_progress_dialog: MapCultivationProgressDialog
var cultivation_session: MapCultivationSession
var _cultivation_adjusting := false
var shop_dialog: MapShopDialog
var clinic_dialog: MapClinicDialog
var inn_dialog: MapInnDialog
var shops: Dictionary = {}
var _gathering_rng := RandomNumberGenerator.new()
var _chest_rng := RandomNumberGenerator.new()
var encounter_dialog: MapEncounterDialog
var _encounter_enemies: Dictionary = {}
var exit_dialog: MapExitDialog
var exits_by_point: Dictionary = {}
var _active_exit: Dictionary = {}
var arrival_point_id := ""
var arrival_facing := ""
var defer_map_music := false
var defer_location_save := false
var sign_motion: MapSignMotion
var player_status: MapPlayerStatus
var status_header: MapStatusHeader
var calendar_readout: MapCalendarReadout
var inventory_screen: MapInventoryScreen
var technique_screen: Control
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
		if startup_error.is_empty():
			_restore_saved_location()
		if startup_error.is_empty():
			_setup_exploration()
		if startup_error.is_empty():
			startup_error = MapPresentation.validate_music(definition)
		if startup_error.is_empty():
			if not defer_location_save: activate_location()
			if not defer_map_music: MapPresentation.enter_map(definition)

func _restore_saved_location() -> void:
	# Explicit transition/battle-return arrivals always take precedence.
	if not arrival_point_id.is_empty() or loadout.map_location.get("map_id", "") != definition.id: return
	var point_id: String = loadout.map_location.get("point_id", "")
	if not travel.node_positions.has(point_id): return
	travel.current_node_id = point_id
	travel.map_position = travel.node_positions[point_id]
	travel.stop_at_current_node()
	player.position = travel.map_position
	content.position = map_viewport.size * 0.5 - player.position * content.scale
	_clamp_position()

func activate_location() -> void:
	if not startup_error.is_empty() or loadout == null or travel == null: return
	_location_active = true
	loadout.set_map_location(definition.id, travel.current_node_id)
	_save_location()

func deactivate_location() -> void:
	_location_active = false

func _save_location() -> void:
	location_save_error = _save_loadout()
	if not location_save_error.is_empty(): push_warning("地图落点尚未保存：" + location_save_error)

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
	# Scene changes carry the current model; only a fresh session initializes it.
	if player_status == null:
		player_status = MapPlayerStatus.new()
		startup_error = player_status.configure(registry, config)
	if not startup_error.is_empty():
		push_error(startup_error)
		return
	# Events are created before the player status on a fresh map session.
	# Bind only after initialization so dialogue shares the header's live state.
	if dialogue != null:
		dialogue.player_status = player_status
	status_header = MapStatusHeader.new()
	startup_error = status_header.configure(player_status, config, definition.get("title_image", ""))
	if not startup_error.is_empty():
		push_error(startup_error)
		status_header.free()
		status_header = null
		return
	add_child(status_header)
	status_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_header.map_title.visible = bool(definition.get("show_map_title", true))
	_setup_inventory(registry)
	if startup_error.is_empty():
		calendar_readout = MapCalendarReadout.new()
		# Shared date banner for fullscreen inventory, warehouse and techniques.
		calendar_readout.hide()
		add_child(calendar_readout)
		inventory_screen.visibility_changed.connect(_update_calendar_visibility)
		technique_screen.visibility_changed.connect(_update_calendar_visibility)
		resized.connect(_layout_calendar)
		_update_calendar_readout()

func _refresh_travel_capacity() -> void:
	travel.set_running_allowed(not loadout.storage_over_capacity())

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
	if loadout.growth.is_empty():
		if not player_status.growth.is_empty(): loadout.growth=player_status.growth.duplicate(true)
		else:
			loadout.growth = CultivationGrowth.initial(int(registry.get_cultivation(loadout.cultivation_rank_id).order))
			var base := CultivationGrowth.maxima(loadout.growth)
			for key: String in base: loadout.growth.resources[key] = int(base[key])*100
		loadout.growth.experience=player_status.experience
		startup_error=MapLoadoutStore.save(loadout,inventory_save_path)
		if not startup_error.is_empty(): return
	player_status._active_board_bonuses=loadout.board.resource_bonuses.duplicate()
	player_status.character_definition.board_layout=loadout.board.id
	player_status.apply_growth(loadout.growth)
	if not player_status.changed.is_connected(player_status.capture_growth): player_status.changed.connect(player_status.capture_growth)
	loadout.changed.connect(func():
		if not loadout.growth.is_empty():
			player_status._active_board_bonuses=loadout.board.resource_bonuses.duplicate()
			player_status.character_definition.board_layout=loadout.board.id
			player_status.apply_growth(loadout.growth)
	)
	loadout.changed.connect(_refresh_travel_capacity)
	_refresh_travel_capacity()
	event_state.reward_claimed = loadout.has_reward
	event_state.chest_resolver = func(event: Dictionary): return MapChestRewards.current_event(loadout,event)
	event_state.enemy_lookup = registry.get_enemy
	event_state.enemy_available = func(id: String): return registry.enemy_battle_error(id).is_empty()
	for event: Dictionary in event_registry.events.values():
		if event.type == "encounter":
			for id: String in event.get("enemy_sequence", [event.enemy_id]):
				if registry.get_enemy(id).is_empty():
					startup_error = "地图遭遇引用未知敌人：" + id
					return
		if not event.get("enabled", true): continue
		if event.type == "shop":
			var shop := MapShop.new()
			startup_error = shop.load_catalog(event.catalog,loadout)
			if not startup_error.is_empty(): return
			shops[event.id] = shop
		if event.type == "inn" and event.has("food_catalog"):
			var food_shop := MapShop.new()
			startup_error = food_shop.load_catalog(event.food_catalog,loadout)
			if not startup_error.is_empty(): return
		if event.type == "gathering" and (not loadout.records.has(event.item_id) or loadout.records[event.item_id].category not in ["plant", "mineral"]):
			startup_error = "采集点引用了未知材料。"
			return
		if event.type == "chest":
			startup_error = MapChestRewards.configuration_error(loadout,event)
			if not startup_error.is_empty(): return
			if loadout.has_reward(event.reward_id): event_state.completed[event.id] = true
		if event.type == "encounter":
			var current_event := event_state.resolved_event(event.id)
			if not event_state.enemy_available.call(current_event.enemy_id): continue
			var enemy := registry.get_enemy(current_event.enemy_id)
			if enemy.is_empty() or not ResourceLoader.exists(enemy.get("portrait", ""), "Texture2D"):
				startup_error = "地图遭遇引用了未知敌人或头像。"
				push_error(startup_error)
				return
			var presentation_error := EnemyPresentation.validation_error(enemy.get("presentation"))
			if not presentation_error.is_empty():
				startup_error = "地图遭遇敌人展示配置无效：" + presentation_error
				push_error(startup_error)
				return
			_encounter_enemies[event.id] = PartyMemberState.new(enemy, registry)
			_encounter_enemies[event.id].equip_definition_loadout()
		if event.has("reward") and not loadout.records.has(event.reward.item_id):
			startup_error = "剧情奖励引用了未知物品。"
			push_error(startup_error)
			return
	inventory_catalog.replace_entries(loadout.storage_records())
	player_status.apply_board(loadout.board)
	_sync_currency()
	loadout.changed.connect(_sync_currency)
	_sync_player_name()
	loadout.changed.connect(_sync_player_name)
	loadout.changed.connect(func(): player_status.apply_board(loadout.board))
	loadout.changed.connect(_sync_calendar)
	# Restore persisted deadlines before the first frame, without completion fades.
	_sync_calendar(false)
	_sync_completed_signs()
	inventory_screen = MapInventoryScreen.new()
	inventory_screen.configure(inventory_catalog, config, registry.get_board(character.board_layout), loadout, player_status)
	inventory_screen.formation_save_callback = _save_loadout
	add_child(inventory_screen)
	inventory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_screen.close_requested.connect(func(): set_inventory_open(false))
	inventory_screen.warehouse_transfer_requested.connect(_transfer_warehouse)
	inventory_screen.warehouse_bulk_transfer_requested.connect(func(id: String, withdraw: bool): _transfer_warehouse(id,"",withdraw,true))
	inventory_screen.warehouse_quantity_transfer_requested.connect(func(id: String, item_id: String, withdraw: bool, quantity: int): _transfer_warehouse(id,item_id,withdraw,false,quantity))
	inventory_screen.warehouse_undo_requested.connect(_undo_warehouse)
	inventory_screen.warehouse_history_provider = func(): return warehouse_transfers.view_history(loadout)
	technique_screen = preload("res://scripts/map/map_technique_screen.gd").new()
	var technique_memory := preload("res://scripts/map/map_technique_view_memory.gd")
	technique_screen.selected_book_id = technique_memory.read_book(inventory_save_path, registry.library)
	technique_screen.configure(registry.library, loadout.knowledge)
	technique_screen.bind_learning(loadout,inventory_save_path)
	technique_screen.book_selected.connect(func(book_id: String):
		if technique_memory.save_book(inventory_save_path, registry.library, book_id) != OK:
			push_warning("功法浏览记录保存失败，本次选择仍保留，重启后可能无法恢复。"))
	add_child(technique_screen)
	technique_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	technique_screen.close_requested.connect(func(): set_technique_open(false))
	ItemTooltipHost.for_control(self).technique_requested.connect(_open_book_details)
	if sign_motion != null:
		inventory_screen.visibility_changed.connect(func(): sign_motion.set_suspended(is_inventory_open() or is_technique_open()))
		technique_screen.visibility_changed.connect(func(): sign_motion.set_suspended(is_inventory_open() or is_technique_open()))
		sign_motion.set_suspended(inventory_screen.visible)

var warehouse_transfers := preload("res://scripts/map/map_warehouse_transfer.gd").new()

func _transfer_warehouse(id: String, item_id: String, withdraw: bool, all_items: bool = false, quantity: int = -1) -> void:
	if not is_inventory_open() or inventory_screen.warehouse_id != id: return
	var error := warehouse_transfers.transfer(loadout,id,item_id,withdraw,inventory_save_path,all_items,quantity)
	_finish_warehouse_command(error)

func _undo_warehouse(operation_id: int) -> void:
	if not is_inventory_open() or inventory_screen.warehouse_id.is_empty(): return
	_finish_warehouse_command(warehouse_transfers.revert(loadout,operation_id,inventory_save_path))

func _finish_warehouse_command(error: String) -> void:
	if error.is_empty():
		_saved_loadout_revision = loadout.revision
		loadout.interaction.emit("place")
	else:
		var notice := AcceptDialog.new()
		notice.title = "仓库存取"
		notice.dialog_text = error
		add_child(notice)
		notice.confirmed.connect(notice.queue_free)
		notice.canceled.connect(notice.queue_free)
		notice.popup_centered()
	inventory_screen._refresh_warehouse_actions.call_deferred()

func _sync_calendar(animate_signs: bool = true) -> void:
	player_status.food_modifiers = MapFood.modifiers(loadout)
	player_status.cultivation_bonus_percent = loadout.cultivation_bonus_percent()
	player_status.apply_calendar(loadout.calendar)
	var today := WorldCalendar.current_day(loadout.calendar)
	if cultivation_session!=null: cultivation_session.sync_calendar(today)
	for event: Dictionary in event_registry.events.values():
		var managed := false
		var waiting := false
		if event.type == "chest":
			managed = true
			waiting = loadout.has_reward(MapChestRewards.current_event(loadout,event).reward_id)
		elif event.type == "encounter" and loadout.encounter_cooldowns.has(event.id):
			managed = true
			waiting = today < int(loadout.encounter_cooldowns[event.id])
		if not managed: continue
		var was_waiting := event_state.completed.has(event.id)
		if waiting: event_state.completed[event.id] = true
		else: event_state.completed.erase(event.id)
		if was_waiting != waiting: _on_encounter_changed(event.id, animate_signs)
	_update_calendar_readout()

func _update_calendar_readout() -> void:
	if calendar_readout == null or loadout == null: return
	calendar_readout.present(loadout.calendar)
	_update_calendar_visibility()
	_layout_calendar.call_deferred()

func _update_calendar_visibility() -> void:
	if calendar_readout == null: return
	calendar_readout.visible = is_inventory_open() or is_technique_open()
	if calendar_readout.visible: _layout_calendar.call_deferred()

func _layout_calendar() -> void:
	if calendar_readout != null:
		calendar_readout.layout_for(size,MapStatusHeader.height_for_width(size.x))

func is_inventory_open() -> bool:
	return inventory_screen != null and inventory_screen.visible

func is_technique_open() -> bool:
	return technique_screen != null and technique_screen.visible

func _open_book_details(book_id: String) -> void:
	if not is_visible_in_tree() or not loadout.registry.library.books.has(book_id): return
	if is_inventory_open():
		if not _prepare_inventory_close(): return
		if not inventory_screen.warehouse_id.is_empty(): _close_home_warehouse()
		else: inventory_screen.hide()
	elif event_state != null and event_state.is_active(): return
	technique_screen.show()
	technique_screen.focus_book(book_id)
	status_header.map_title.hide()
	player.pause()
	_end_drag()
	_clear_hover()

func set_technique_open(open: bool) -> void:
	if technique_screen == null or is_technique_open() == open: return
	if open and (is_inventory_open() or is_exit_open() or (event_state != null and event_state.is_active())): return
	ItemTooltipHost.for_control(self).dismiss()
	technique_screen.visible = open
	status_header.map_title.visible = not open and bool(definition.get("show_map_title", true))
	_end_drag()
	_clear_hover()
	if open: player.pause()
	else:
		if _cultivation_adjusting:
			_cultivation_adjusting = false
			cultivation_session.suspend("inventory", false, WorldCalendar.current_day(loadout.calendar))
			cultivation_progress_dialog.show()
			status_header.map_title.hide()
			return
		player.play()

func _prepare_inventory_close() -> bool:
	inventory_screen.close_board_change_dialog()
	inventory_screen.close_formation_dialog()
	inventory_screen.cancel_item_drag()
	var save_error := _save_loadout()
	if save_error.is_empty(): return true
	var notice := AcceptDialog.new()
	notice.dialog_text = save_error
	add_child(notice)
	notice.confirmed.connect(notice.queue_free)
	notice.popup_centered()
	return false

func _handle_fullscreen_switch(event: InputEventKey) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	var to_techniques := event.is_action_pressed("map_techniques") and is_inventory_open()
	var to_inventory := event.is_action_pressed("map_inventory") and (is_technique_open() or (is_inventory_open() and not inventory_screen.warehouse_id.is_empty()))
	if not to_techniques and not to_inventory: return false
	if is_inventory_open():
		if not _prepare_inventory_close(): return true
		if not inventory_screen.warehouse_id.is_empty(): _close_home_warehouse()
		else: inventory_screen.hide()
	if is_technique_open(): technique_screen.hide()
	if to_techniques: technique_screen.show()
	else:
		inventory_screen.set_warehouse()
		inventory_screen.show()
	ItemTooltipHost.for_control(self).dismiss()
	status_header.map_title.hide()
	player.pause()
	_end_drag()
	_clear_hover()
	return true

func is_exit_open() -> bool:
	return exit_dialog != null and exit_dialog.visible

func set_inventory_open(open: bool) -> void:
	if not open and is_inventory_open() and not inventory_screen.warehouse_id.is_empty():
		_close_home_warehouse()
		return
	if inventory_screen == null or is_technique_open() or is_exit_open() or (open and event_state != null and event_state.is_active()):
		return
	if is_inventory_open() == open:
		return
	if not open and not _prepare_inventory_close(): return
	inventory_screen.visible = open
	status_header.map_title.visible = not open and bool(definition.get("show_map_title", true))
	_end_drag()
	_clear_hover()
	if open:
		player.pause()
	else:
		if _cultivation_adjusting:
			_cultivation_adjusting=false
			cultivation_session.suspend("inventory",false,WorldCalendar.current_day(loadout.calendar))
			cultivation_progress_dialog.show()
			status_header.map_title.hide()
			return
		player.play()

func _save_loadout() -> String:
	if Engine.is_editor_hint() or not _location_active or not startup_error.is_empty() or loadout == null or _saved_loadout_revision == loadout.revision:
		return ""
	var error := MapLoadoutStore.save(loadout, inventory_save_path)
	if error.is_empty():
		_saved_loadout_revision = loadout.revision
	return error

func _exit_tree() -> void:
	var error := _save_loadout()
	if not error.is_empty():
		push_error(error)

func _sync_currency() -> void:
	if player_status.spirit_stones != loadout.spirit_stones:
		player_status.spirit_stones = loadout.spirit_stones
		player_status.changed.emit()

func _sync_player_name() -> void:
	var full_name := DialogueJournal.full_name(loadout.narrative)
	if player_status.display_name!=full_name:
		player_status.display_name = full_name
		player_status.changed.emit()

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event is InputEventKey and event.pressed and not event.echo:
		if _handle_fullscreen_switch(event):
			get_viewport().set_input_as_handled()
			return
	if not Engine.is_editor_hint() and is_technique_open():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.is_action_pressed("map_techniques"):
				set_technique_open(false)
			else:
				# Let the focused rank button receive native activation/navigation.
				# The early return below still prevents map movement shortcuts.
				var focus := get_viewport().gui_get_focus_owner()
				if focus != null and technique_screen.progress_art.rank_selection.is_ancestor_of(focus):
					for action in ["ui_accept", "ui_focus_next", "ui_focus_prev", "ui_left", "ui_right", "ui_up", "ui_down"]:
						if event.is_action(action): return
			get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and event_state != null and event_state.phase == "inn":
		if inn_dialog.handle_continue_input(event):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: _close_inn()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			if event.pressed and event.keycode == KEY_ESCAPE: _close_inn()
			get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and event_state != null and event_state.phase == "clinic":
		if clinic_dialog.handle_continue_input(event):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: _close_clinic()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			if event.pressed and event.keycode == KEY_ESCAPE: _close_clinic()
			get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and event_state != null and event_state.phase == "shop":
		if shop_dialog.conversing and shop_dialog.conversation_view.handle_continue_input(event):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: _close_shop()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			if event.pressed and event.keycode == KEY_ESCAPE: _close_shop()
			get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and is_inventory_open() and not inventory_screen.warehouse_id.is_empty():
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or (event.is_action_pressed("map_inventory") and not get_viewport().gui_get_focus_owner() is LineEdit)):
			_close_home_warehouse()
			get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and event_state != null and event_state.phase == "cultivation":
		if _cultivation_adjusting:
			if event is InputEventKey and event.pressed and not event.echo:
				if event.keycode==KEY_ESCAPE or (event.is_action_pressed("map_inventory") and not get_viewport().gui_get_focus_owner() is LineEdit):
					if inventory_screen.is_board_change_dialog_open(): inventory_screen.close_board_change_dialog()
					elif inventory_screen.is_formation_dialog_open(): inventory_screen.close_formation_dialog()
					else: set_inventory_open(false)
					get_viewport().set_input_as_handled()
			return
		if cultivation_progress_dialog.technique_choice.visible:
			if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.keycode==KEY_ESCAPE):
				if event.pressed: cultivation_progress_dialog.technique_choice.close()
				get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: _close_cultivation()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			if event.pressed and event.keycode == KEY_ESCAPE: _close_cultivation()
			get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and event_state != null and event_state.phase == "rest" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: _cancel_rest()
		get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and event_state != null and event_state.phase in ["chest_observation", "chest"] and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: _cancel_chest()
		get_viewport().set_input_as_handled()
		return
	if not Engine.is_editor_hint() and is_exit_open() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_cancel_exit()
		get_viewport().set_input_as_handled()
		return
	if Engine.is_editor_hint() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_exit_open():
		if event.keycode == KEY_ESCAPE:
			_cancel_exit()
		get_viewport().set_input_as_handled()
		return
	if event_state != null and event_state.is_active():
		if event_state.phase == "rest":
			if event.keycode == KEY_ESCAPE: _cancel_rest()
			get_viewport().set_input_as_handled()
			return
		if event_state.phase in ["chest_observation", "chest"]:
			if event.keycode == KEY_ESCAPE: _cancel_chest()
			get_viewport().set_input_as_handled()
			return
		if event_state.phase == "encounter":
			if event.keycode == KEY_ESCAPE:
				_retreat_encounter()
			get_viewport().set_input_as_handled()
			return
		if (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE) and dialogue != null and dialogue.visible:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if is_inventory_open() and inventory_screen.is_board_change_dialog_open():
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("map_inventory"):
			inventory_screen.close_board_change_dialog()
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
		# Typing I in an editable field must not close the interface.
		if is_inventory_open() and get_viewport().gui_get_focus_owner() is LineEdit:
			return
		set_inventory_open(not is_inventory_open())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map_techniques") and not is_inventory_open():
		set_technique_open(true)
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
	reward_dialog.use_small_reward_art(MapExitDialog.DESIGN_SIZE.y)
	add_child(reward_dialog)
	reward_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_dialog.accept_requested.connect(_accept_reward)
	chest_dialog = load("res://scripts/map/map_chest_dialog.gd").new()
	add_child(chest_dialog)
	chest_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest_dialog.accept_requested.connect(_accept_chest)
	chest_dialog.cancelled.connect(_cancel_chest)
	chest_observation_dialog = load("res://scripts/map/map_chest_observation_dialog.gd").new()
	add_child(chest_observation_dialog)
	chest_observation_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest_observation_dialog.open_requested.connect(_open_chest)
	chest_observation_dialog.cancelled.connect(_cancel_chest)
	_chest_rng.randomize()
	_gathering_rng.randomize()
	gathering_dialog = MapGatheringDialog.new()
	add_child(gathering_dialog)
	gathering_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gathering_dialog.gathering_requested.connect(_begin_gathering)
	gathering_dialog.cancelled.connect(_cancel_gathering)
	gathering_result = load("res://scripts/map/map_gathering_result_dialog.gd").new()
	add_child(gathering_result)
	gathering_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gathering_result.accept_requested.connect(_accept_gathering)
	gathering_result.cancelled.connect(_cancel_gathering)
	rest_dialog = MapRestDialog.new()
	add_child(rest_dialog)
	rest_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rest_dialog.rest_requested.connect(_confirm_rest)
	rest_dialog.warehouse_requested.connect(_open_home_warehouse)
	rest_dialog.cancelled.connect(_cancel_rest)
	cultivation_dialog=MapCultivationDialog.new()
	add_child(cultivation_dialog)
	cultivation_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cultivation_dialog.cancelled.connect(_close_cultivation)
	cultivation_dialog.cultivation_requested.connect(_request_cultivation)
	cultivation_progress_dialog=MapCultivationProgressDialog.new()
	add_child(cultivation_progress_dialog)
	cultivation_progress_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cultivation_progress_dialog.ended.connect(_close_cultivation)
	cultivation_progress_dialog.pause_requested.connect(_toggle_cultivation_pause)
	cultivation_progress_dialog.board_requested.connect(_open_cultivation_inventory)
	cultivation_progress_dialog.technique_requested.connect(_open_cultivation_techniques)
	cultivation_progress_dialog.technique_choice.technique_chosen.connect(func(id: String): cultivation_session.choose_technique(id))
	cultivation_progress_dialog.technique_choice.books_chosen.connect(func(ids: Array): cultivation_session.select_books(ids))
	cultivation_progress_dialog.technique_choice.closed.connect(func():
		if cultivation_session!=null: cultivation_session.suspend("choice",false,WorldCalendar.current_day(loadout.calendar))
	)
	shop_dialog = MapShopDialog.new()
	add_child(shop_dialog)
	shop_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_dialog.cancelled.connect(_close_shop)
	shop_dialog.purchase_requested.connect(_purchase_shop_item)
	shop_dialog.sale_requested.connect(_sell_shop_item)
	shop_dialog.dialogue_requested.connect(_shop_dialogue_command)
	shop_dialog.benefit_tooltip_shown.connect(_shop_benefit_tooltip_shown)
	clinic_dialog = MapClinicDialog.new()
	add_child(clinic_dialog)
	clinic_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clinic_dialog.cancelled.connect(_close_clinic)
	clinic_dialog.dialogue_requested.connect(_clinic_dialogue_command)
	clinic_dialog.treatment_requested.connect(_confirm_clinic_treatment)
	inn_dialog = MapInnDialog.new()
	add_child(inn_dialog)
	inn_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inn_dialog.cancelled.connect(_close_inn)
	inn_dialog.dialogue_requested.connect(_inn_dialogue_command)
	inn_dialog.lodging_requested.connect(_confirm_inn_lodging)
	inn_dialog.food_purchase_requested.connect(_purchase_inn_food)
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
		exit_dialog.use_map_exit_art()
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

func _on_encounter_changed(event_id: String, animate_signs: bool = true) -> void:
	var point_id: String = event_registry.events[event_id].point_id
	if event_state.completed.has(event_id):
		_sync_completed_signs(animate_signs)
	elif sign_motion != null:
		sign_motion.restore(point_id)
	else:
		for point: MapRoutePoint in content.get_node("Points").get_children():
			if point.point_id == point_id and point.has_node("Sign"):
				point.get_node("Sign").show()

func _advance_dialogue() -> void:
	if event_state == null or not event_state.is_active():
		return
	var event := event_state.active_event()
	if event_state.phase=="dialogue" and event_state.line_index+1==event.get("lines",[]).size():
		var flags: Array = event.get("story_flags_on_complete",[])
		if not flags.is_empty():
			var error := NpcDialogueActions.set_story_flags(loadout,flags,inventory_save_path)
			if not error.is_empty():
				dialogue.text_label.text = event_state.current_line()+"\n"+error
				return
			_saved_loadout_revision = loadout.revision
	var completed_id := event_state.advance()
	_present_event_progress(completed_id)

func _present_event_progress(completed_id: String = "") -> void:
	if not completed_id.is_empty():
		dialogue.hide()
		reward_dialog.hide()
		chest_dialog.hide()
		chest_observation_dialog.hide()
		gathering_dialog.hide()
		gathering_result.hide()
		rest_dialog.hide()
		cultivation_dialog.hide()
		cultivation_progress_dialog.hide()
		shop_dialog.hide()
		clinic_dialog.hide()
		inn_dialog.hide()
		travel.paused = false
		_sync_completed_signs(true)
		_end_drag()
		_clear_hover()
	elif event_state.phase == "shop":
		shop_dialog.present(event_state.active_event(),shops[event_state.active_id],loadout,player_status)
		if shop_dialog.conversation_view!=null: _shop_dialogue_command("visit","")
	elif event_state.phase == "inn":
		inn_dialog.present(event_state.active_event(),loadout,player_status)
		_inn_dialogue_command("visit","")
	elif event_state.phase == "clinic":
		clinic_dialog.present(event_state.active_event(),loadout,player_status)
		_clinic_dialogue_command("visit","")
	elif event_state.phase == "cultivation":
		dialogue.hide()
		reward_dialog.hide()
		cultivation_dialog.present(event_state.active_event())
	elif event_state.phase == "rest":
		dialogue.hide()
		reward_dialog.hide()
		rest_dialog.present(event_state.active_event(),player_status.needs_rest(),loadout)
	elif event_state.phase == "gathering":
		var event := event_state.active_event()
		if not MapGatheringRewards.pending(loadout,event).is_empty():
			_show_gathering_result()
		else:
			_set_gathering_profile(MapGatheringOptions.path_for_record(loadout.records[event.item_id]))
			gathering_dialog.bind_herb(loadout.records[event.item_id],loadout)
			gathering_dialog.present(event.title)
	elif event_state.phase == "chest_observation":
		dialogue.hide()
		reward_dialog.hide()
		chest_dialog.hide()
		chest_observation_dialog.present(event_state.active_event())
	elif event_state.phase == "chest":
		dialogue.hide()
		reward_dialog.hide()
		var event := event_state.active_event()
		var error := MapChestRewards.ensure_offer(loadout,event,inventory_save_path,_chest_rng)
		_show_chest_choices(event, error)
	elif event_state.phase == "encounter":
		dialogue.hide()
		reward_dialog.hide()
		var event := event_state.active_event()
		# Resolve per opening so rotation never reuses the preceding species' preview.
		var enemy := PartyMemberState.new(loadout.registry.get_enemy(event.enemy_id), loadout.registry)
		enemy.equip_definition_loadout()
		_encounter_enemies[event.id] = enemy
		encounter_dialog.present(event, enemy)
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

func _setup_exploration() -> void:
	var settings: Variant = definition.get("exploration", {})
	if not settings is Dictionary or not settings.get("enabled", false) is bool:
		startup_error = "地图探索配置无效。"
		push_error(startup_error)
		return
	if not settings.get("enabled", false): return
	var hint: Variant = settings.get("hint_length", 72.0)
	if not (hint is float or hint is int) or not is_finite(float(hint)) or float(hint) <= 0:
		startup_error = "地图探索路线提示长度无效。"
		push_error(startup_error)
		return
	exploration = MapExplorationState.new()
	travel.exploration_enabled = true
	_visit_exploration(travel.current_node_id)

func _visit_exploration(point_id: String) -> void:
	if exploration == null or loadout == null: return
	var changed := loadout.visit_map_point(definition.id, point_id)
	exploration.rebuild(travel.adjacency, loadout.map_visited.get(definition.id, []))
	travel.revealed_points = exploration.revealed.duplicate()
	travel.revealed_routes = exploration.full_routes.duplicate()
	for point: MapRoutePoint in content.get_node("Points").get_children():
		point.present_exploration(exploration.revealed.has(point.point_id), exploration.visited.has(point.point_id))
	for route: MapRoute in content.get_node("Routes").get_children():
		var first: String = route.get_node(route.start_point).point_id
		var last: String = route.get_node(route.end_point).point_id
		route.present_exploration(exploration.full_routes.has(route.route_id), exploration.revealed.has(first), exploration.revealed.has(last), float(definition.exploration.get("hint_length", 72.0)))
	if changed or not exploration_save_error.is_empty():
		exploration_save_error = _save_loadout()
		if not exploration_save_error.is_empty(): push_warning("探索进度尚未保存：" + exploration_save_error)

func _on_node_arrived(point_id: String) -> void:
	if _location_active: loadout.set_map_location(definition.id, point_id)
	_visit_exploration(point_id)
	if _location_active: _save_location()
	if exits_by_point.has(point_id) and not event_state.is_active():
		travel.stop_at_current_node()
		if _try_open_exit(point_id):
			return
	_try_start_event(point_id, "arrival", true)

func _open_home_warehouse() -> void:
	if event_state.phase != "rest" or not rest_dialog.visible or rest_dialog.warehouse_button.disabled: return
	var warehouse_id: String = event_state.active_event().get("warehouse_id","")
	if warehouse_id.is_empty(): return
	warehouse_transfers.clear()
	rest_dialog.hide()
	inventory_screen.set_warehouse(warehouse_id)
	inventory_screen.show()
	status_header.map_title.hide()
	player.pause()
	_end_drag()
	_clear_hover()

func _close_home_warehouse() -> void:
	warehouse_transfers.clear()
	inventory_screen.hide()
	inventory_screen.set_warehouse()
	status_header.map_title.visible = bool(definition.get("show_map_title",true))
	if event_state.phase == "rest": _close_rest()
	player.play()
	_end_drag()
	_clear_hover()

func _purchase_shop_item(item_id: String, quantity: int) -> void:
	if event_state.phase != "shop" or not shop_dialog.visible or shop_dialog.busy or shop_dialog.selling or shop_dialog.crafting or shop_dialog.conversing: return
	shop_dialog.set_busy(true)
	var shop: MapShop = shops[event_state.active_id]
	var error := shop.purchase(loadout,item_id,quantity,inventory_save_path)
	if error.is_empty(): _saved_loadout_revision = loadout.revision
	shop_dialog.set_busy(false)
	shop_dialog.refresh_checkout()
	shop_dialog.message.text = error if not error.is_empty() else "已购买 %s ×%d，已放入储物袋。" % [loadout.records[item_id].name,quantity]

func _sell_shop_item(item_id: String, quantity: int) -> void:
	if event_state.phase != "shop" or not shop_dialog.visible or shop_dialog.busy or not shop_dialog.selling or shop_dialog.crafting or shop_dialog.conversing: return
	shop_dialog.set_busy(true)
	var shop: MapShop = shops[event_state.active_id]
	var before := loadout.spirit_stones
	var error := shop.sell(loadout,item_id,quantity,inventory_save_path)
	if error.is_empty():
		_saved_loadout_revision = loadout.revision
		shop_dialog.quantity = 1
	shop_dialog.set_busy(false)
	shop_dialog._refresh_page(false)
	shop_dialog.message.text = error if not error.is_empty() else "已出售 %s ×%d，获得%d灵石。" % [loadout.records[item_id].name,quantity,loadout.spirit_stones-before]

func _close_shop() -> void:
	if event_state.phase != "shop" or shop_dialog.busy: return
	travel.stop_at_current_node()
	event_state.close_shop()
	shop_dialog.hide()
	travel.paused = false
	player.present(travel)
	_end_drag()
	_clear_hover()

func _close_clinic() -> void:
	if not event_state.close_clinic(): return
	travel.stop_at_current_node()
	clinic_dialog.hide()
	travel.paused = false
	player.present(travel)
	_end_drag()
	_clear_hover()

func _close_inn() -> void:
	if not event_state.close_inn(): return
	travel.stop_at_current_node()
	inn_dialog.hide()
	travel.paused = false
	player.present(travel)
	_end_drag()
	_clear_hover()

func _confirm_inn_lodging(room_id: String) -> void:
	if event_state.phase!="inn" or not inn_dialog.visible or inn_dialog.mode!="lodging" or inn_dialog.lodging_content.busy: return
	inn_dialog.lodging_content.set_busy(true)
	var result := MapInnLodging.stay(loadout,player_status,event_state.active_event().get("lodging",{}),room_id,inventory_save_path)
	if result.error.is_empty(): _saved_loadout_revision = loadout.revision
	inn_dialog.lodging_content.set_busy(false)
	inn_dialog.lodging_content.refresh(result.error if not result.error.is_empty() else "已歇息一晚，三项状态已恢复。")

func _purchase_inn_food(item_id: String, quantity: int) -> void:
	if event_state.phase!="inn" or not inn_dialog.visible or inn_dialog.mode!="food" or inn_dialog.food_view.busy: return
	var view := inn_dialog.food_view
	view.set_busy(true)
	var error := inn_dialog.food_shop.purchase(loadout,item_id,quantity,inventory_save_path)
	if error.is_empty(): _saved_loadout_revision = loadout.revision
	view.set_busy(false)
	view.message.text = error if not error.is_empty() else "已购买 %s ×%d，已放入储物袋。" % [loadout.records[item_id].name,quantity]

func _inn_dialogue_command(action: String, topic: String) -> void:
	if event_state.phase!="inn" or inn_dialog.library==null or inn_dialog.mode!="conversation": return
	var context := {"resources":player_status.resources,"maxima":player_status.maxima}
	var error := NpcDialogueActions.command(loadout,inn_dialog.library,action,inventory_save_path,topic,context)
	if error.is_empty(): _saved_loadout_revision = loadout.revision
	inn_dialog.refresh_dialogue(error)

func _clinic_dialogue_command(action: String, topic: String) -> void:
	if event_state.phase!="clinic" or clinic_dialog.library==null: return
	var context := {"resources":player_status.resources,"maxima":player_status.maxima}
	var error := NpcDialogueActions.command(loadout,clinic_dialog.library,action,inventory_save_path,topic,context)
	if error.is_empty(): _saved_loadout_revision = loadout.revision
	clinic_dialog.refresh_dialogue(error)

func _shop_dialogue_command(action: String, topic: String) -> void:
	if event_state.phase!="shop" or not shop_dialog.conversing: return
	var view: MapClinicDialog = shop_dialog.conversation_view
	if view==null or view.library==null: return
	var context := {"resources":player_status.resources,"maxima":player_status.maxima}
	var error := NpcDialogueActions.command(loadout,view.library,action,inventory_save_path,topic,context)
	if error.is_empty(): _saved_loadout_revision = loadout.revision
	view.refresh_dialogue(error)

func _shop_benefit_tooltip_shown() -> void:
	if event_state.phase!="shop" or shop_dialog.conversing or not shop_dialog.apprentice_badge.is_visible_in_tree(): return
	var benefit: Dictionary = shop_dialog.shop.definition.get("purchase_discount",{})
	var flag: String = benefit.get("dialogue_unlock_flag","")
	if flag.is_empty(): return
	var error := NpcDialogueActions.record_dialogue_fact(loadout,flag,inventory_save_path)
	var previous_error: String = shop_dialog.apprentice_badge.get_meta("unlock_error","")
	if error.is_empty():
		_saved_loadout_revision = loadout.revision
		if not previous_error.is_empty() and shop_dialog.message.text==previous_error: shop_dialog.message.text = ""
	else: shop_dialog.message.text = error
	shop_dialog.apprentice_badge.set_meta("unlock_error",error)

func _confirm_clinic_treatment() -> void:
	if event_state.phase!="clinic" or not clinic_dialog.visible or clinic_dialog.mode!="treatment": return
	var event := event_state.active_event()
	var result := MapClinicTreatment.treat(loadout,player_status,event.get("treatment",{}),inventory_save_path,clinic_dialog.library)
	if result.error.is_empty(): _saved_loadout_revision = loadout.revision
	clinic_dialog.treatment_content.refresh(result.error if not result.error.is_empty() else "诊治完成，气血已恢复。")

func _request_cultivation(mode_id: String, duration_days: int) -> void:
	if event_state.phase != "cultivation" or not cultivation_dialog.visible: return
	var session:=MapCultivationSession.new()
	if not session.begin(event_state.active_event(),mode_id,duration_days,WorldCalendar.current_day(loadout.calendar)): return
	var books: Array[Dictionary] = []
	for record: Dictionary in loadout.storage_records():
		if record.category == "book": books.append(record)
	session.set_available_techniques(books)
	if not session.bind(loadout,player_status,inventory_save_path):
		cultivation_dialog.notice.text=session.error
		return
	cultivation_session=session
	cultivation_dialog.hide()
	cultivation_progress_dialog.present(session)

func _toggle_cultivation_pause() -> void:
	if cultivation_session==null or not cultivation_session.active: return
	cultivation_session.set_paused(not cultivation_session.paused,WorldCalendar.current_day(loadout.calendar))

func _open_cultivation_techniques() -> void:
	if cultivation_session==null or not cultivation_progress_dialog.visible: return
	cultivation_session.suspend("choice",true,WorldCalendar.current_day(loadout.calendar))
	cultivation_progress_dialog.technique_choice.present_multiple(cultivation_session.techniques,cultivation_session.pending_ids if cultivation_session._selection_pending else cultivation_session.selected_ids,int(cultivation_session.site.get("slots",1)))

func _open_cultivation_inventory() -> void:
	if cultivation_session==null or not cultivation_progress_dialog.visible: return
	cultivation_session.suspend("inventory",true,WorldCalendar.current_day(loadout.calendar))
	_cultivation_adjusting=true
	cultivation_progress_dialog.hide()
	inventory_screen.set_warehouse()
	inventory_screen.show()
	status_header.map_title.hide()
	player.pause()
	_end_drag()
	_clear_hover()

func _close_cultivation() -> void:
	if _cultivation_adjusting: return
	if not event_state.close_cultivation(): return
	cultivation_progress_dialog.technique_choice.close()
	if cultivation_session!=null: cultivation_session.finish(WorldCalendar.current_day(loadout.calendar))
	cultivation_progress_dialog.hide()
	travel.stop_at_current_node()
	cultivation_dialog.hide()
	status_header.map_title.visible=bool(definition.get("show_map_title",true))
	travel.paused=false
	player.present(travel)
	_end_drag()
	_clear_hover()

func _confirm_rest() -> void:
	if event_state.phase != "rest" or not rest_dialog.visible or rest_dialog.start_button.disabled: return
	if rest_dialog.food_choice.visible: return
	rest_dialog.set_busy(true)
	var event := event_state.active_event()
	var result := MapTimeActions.rest(loadout,player_status,event,inventory_save_path,rest_dialog.selected_food_id)
	if not result.error.is_empty():
		rest_dialog.set_busy(false)
		rest_dialog.error_label.text = result.error
		return
	_saved_loadout_revision = loadout.revision
	_close_rest()

func _cancel_rest() -> void:
	if event_state.phase != "rest" or rest_dialog.later_button.disabled: return
	if rest_dialog.food_choice.visible:
		rest_dialog.food_choice.close()
		return
	_close_rest()

func _close_rest() -> void:
	travel.stop_at_current_node()
	event_state.close_rest()
	rest_dialog.hide()
	rest_dialog.food_choice.close()
	travel.paused = false
	player.present(travel)
	_end_drag()
	_clear_hover()

func _set_gathering_profile(path: String) -> void:
	if gathering_dialog.options.profile_path == path: return
	remove_child(gathering_dialog)
	gathering_dialog.queue_free()
	gathering_dialog = MapGatheringDialog.new(path)
	add_child(gathering_dialog)
	gathering_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gathering_dialog.gathering_requested.connect(_begin_gathering)
	gathering_dialog.cancelled.connect(_cancel_gathering)

func _begin_gathering(forecast: Dictionary) -> void:
	if event_state.phase != "gathering": return
	var error := MapGatheringRewards.prepare(loadout,event_state.active_event(),forecast.get("method_id",""),inventory_save_path,_gathering_rng)
	if not error.is_empty():
		gathering_dialog.error_label.text = error
		gathering_dialog.set_busy(false)
		return
	_saved_loadout_revision = loadout.revision
	_show_gathering_result()

func _show_gathering_result() -> void:
	var offer := MapGatheringRewards.pending(loadout,event_state.active_event())
	if offer.is_empty(): return
	event_state.phase = "gathering_reward"
	gathering_dialog.hide()
	var record: Dictionary = loadout.records[offer.item_id].duplicate(true)
	record.quantity = offer.quantity
	gathering_result.present_herb(record,loadout)

func _accept_gathering() -> void:
	if event_state.phase != "gathering_reward" or gathering_result.accept_button.disabled: return
	gathering_result.accept_button.disabled = true
	var event := event_state.active_event()
	var error := MapGatheringRewards.claim(loadout,event,inventory_save_path)
	if not error.is_empty():
		gathering_result.error_label.text = error
		gathering_result.accept_button.disabled = false
		return
	_saved_loadout_revision = loadout.revision
	gathering_result.pick_sound.play()
	_present_event_progress(event_state.close_gathering(loadout.gathering_offers[event.id].id))

func _cancel_gathering() -> void:
	if event_state.phase not in ["gathering","gathering_reward"]: return
	travel.stop_at_current_node()
	event_state.close_gathering()
	gathering_dialog.hide()
	gathering_result.hide()
	travel.paused = false
	player.present(travel)
	_end_drag()
	_clear_hover()

func _open_chest() -> void:
	if event_state.phase != "chest_observation": return
	chest_observation_dialog.set_busy(true)
	var event := event_state.active_event()
	var error := MapChestRewards.ensure_offer(loadout,event,inventory_save_path,_chest_rng)
	if not error.is_empty():
		chest_observation_dialog.error_label.text = error
		chest_observation_dialog.set_busy(false)
		return
	if event_state.open_chest():
		_show_chest_choices(event)

# Stage-two presentation seam: receives the full event (including result copy)
# and the persisted offer. Replacing its UI must not reroll or grant rewards.
func _show_chest_choices(event: Dictionary, error := "") -> void:
	var records: Array[Dictionary] = []
	if error.is_empty():
		_saved_loadout_revision = loadout.revision
		for id: String in MapChestRewards.items(loadout,event):
			var record: Dictionary = loadout.records[id].duplicate(true)
			record.quantity = 1
			record.identified = loadout.can_use_item(id)
			records.append(record)
	chest_observation_dialog.hide()
	chest_dialog.present_choices(event,records,inventory_catalog.category_names,loadout,error)

func _accept_chest() -> void:
	if event_state.phase != "chest" or chest_dialog.accept_button.disabled: return
	chest_dialog.set_busy(true)
	var error := MapChestRewards.claim(loadout,event_state.active_event(),chest_dialog.selected_index,inventory_save_path)
	if not error.is_empty():
		chest_dialog.error_label.text = error
		chest_dialog.set_busy(false)
		return
	_saved_loadout_revision = loadout.revision
	chest_dialog.pick_sound.play()
	_present_event_progress(event_state.close_chest(true))

func _cancel_chest() -> void:
	if event_state.phase not in ["chest_observation", "chest"]: return
	if event_state.phase == "chest" and chest_dialog.review_button.disabled: return
	if event_state.phase == "chest_observation" and chest_observation_dialog.later_button.disabled: return
	travel.stop_at_current_node()
	event_state.close_chest(false)
	chest_dialog.hide()
	chest_observation_dialog.hide()
	travel.paused = false
	player.present(travel)
	_end_drag()
	_clear_hover()

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
	manager.player_snapshot = player_status.battle_snapshot()
	manager.use_saved_loadout = true
	manager.loadout_save_path = inventory_save_path
	var battle_ui := battle.get_node_or_null("MainUI")
	if battle_ui == null or scene_file_path.is_empty():
		battle.free()
		_encounter_error("战斗返回入口配置无效。")
		return
	var return_flow := MapBattleReturn.new()
	return_flow.name = "MapBattleReturn"
	return_flow.manager = manager
	return_flow.player_status = player_status
	return_flow.events = event_state
	return_flow.event_id = event.id
	return_flow.map_scene_path = scene_file_path
	return_flow.point_id = event.point_id
	return_flow.facing = "left" if player.flip_h else "right"
	return_flow.save_path = inventory_save_path
	battle.add_child(return_flow)
	battle_ui.battle_exit_handler = return_flow.return_to_map
	battle_ui.defer_battle_music = true
	battle_ui.hide()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(battle)
	if not manager.startup_error.is_empty():
		battle.queue_free()
		_encounter_error("战斗载入失败：" + manager.startup_error)
		MapPresentation.enter_map(definition)
		return
	# Keep PREPARATION until the player explicitly presses 战斗开始.
	# Board artwork is initialized during binding/resizing, even while disabled.
	encounter_dialog.hide()
	await MapPresentation.change_battle_scene(self, battle, self, battle_ui, true, battle_ui.game_audio)
	queue_free()

func _try_open_exit(point_id: String) -> bool:
	if exit_dialog == null or is_exit_open() or is_inventory_open() or is_technique_open() or event_state.is_active() or travel.mode != "idle" or point_id != travel.current_node_id or not exits_by_point.has(point_id):
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
	destination.player_status = player_status
	destination.defer_map_music = true
	destination.defer_location_save = true
	destination.hide()
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
	exit_dialog.hide()
	var outgoing := MapPresentation.direction(travel.node_positions[_active_exit.point_id], _source_size(), false)
	var incoming := MapPresentation.direction(destination.travel.node_positions[destination.arrival_point_id], destination._source_size(), true)
	await MapPresentation.change_map(self, destination, outgoing, incoming)
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
	if cultivation_session != null and not Engine.is_editor_hint(): cultivation_session.advance(delta)
	if is_inventory_open() or is_technique_open() or is_exit_open():
		return
	if travel != null and player != null:
		if event_state == null or not event_state.is_active():
			travel.advance(delta)
		player.present(travel)

func _select_destination(pointer: Vector2) -> void:
	if travel == null or is_inventory_open() or is_technique_open() or is_exit_open() or (event_state != null and event_state.is_active()):
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
		if not point.is_visible_in_tree(): continue
		var screen_position := map_to_screen(content.to_local(point.global_position))
		var distance := pointer.distance_to(screen_position)
		if distance <= radius and distance < closest_distance:
			closest_id = point.point_id
			closest_distance = distance
	return closest_id

func _refresh_cursor() -> void:
	if is_inventory_open() or is_technique_open() or is_exit_open() or (event_state != null and event_state.is_active()):
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
	if is_inventory_open() or is_technique_open() or is_exit_open() or (event_state != null and event_state.is_active()):
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
