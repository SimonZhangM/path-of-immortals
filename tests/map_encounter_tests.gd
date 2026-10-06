extends SceneTree

const SAVE := "res://artifacts/map-encounter-test.json"
const EVENT := "base.map_event.qingshihewan.cliff_encounter"
const POINT := "base.map.qingshihewan.point.n12"
const NEIGHBOR := "base.map.qingshihewan.point.n14"
const BEYOND := "base.map.qingshihewan.point.n11"
const ENEMY := "base.enemy.chisong_liaozhu"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _settle() -> void:
	for frame in 6:
		await process_frame

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func _clean() -> void:
	for suffix in ["", ".tmp", ".bak", ".cultivation.json"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	_clean()
	_check(MapEventState.session_completed.is_empty(), "fresh process starts with live enemies")
	root.size = Vector2i(2560, 1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = SAVE
	map.arrival_point_id = NEIGHBOR
	root.add_child(map)
	current_scene = map
	map.set_process(false)
	await _settle()
	_check(map.startup_error.is_empty(), "map starts with dialogue and encounter together")
	_check(map.travel.node_positions[POINT].is_equal_approx(Vector2(2575, 319)), "encounter bound to screenshot northeast trail")
	_check(not map.event_registry.by_point.has("base.map.qingshihewan.point.n30"), "old mistaken west node unbound")
	for entry: Dictionary in map.loadout.storage.entries():
		if entry.item_id == "base.map_item.qingshi_short_sword":
			_check(map.loadout.place(map.loadout.drag_data("storage", entry.instance_id), Vector2i.ZERO), "isolated sword loadout prepared")
			break
	_check(not map.encounter_dialog.visible, "neighbor has no encounter")
	var raw: Dictionary = map.event_registry.events[EVENT]
	var validation := MapEventRegistry.new()
	_check(validation.configure([raw], [POINT]).is_empty(), "valid encounter accepted")
	for key in ["title", "enemy_id", "battle_scene", "enemy_rank", "description"]:
		var bad := raw.duplicate(true)
		bad.erase(key)
		_check(not validation.configure([bad], [POINT]).is_empty(), "missing encounter field rejected: " + key)
	var outside := raw.duplicate(true)
	outside.presentation.background_region = [0, 0, 9000, 9000]
	_check(not validation.configure([outside], [POINT]).is_empty(), "out-of-image region rejected")
	_check(validation.events.has(EVENT), "failed registry validation preserves valid entries")
	var state := MapEventState.new(validation, {})
	_check(not state.try_start(POINT, NEIGHBOR, true), "remote encounter cannot start")
	_check(not state.try_start(POINT, POINT, false), "mid-edge encounter cannot start")
	_check(state.try_start(POINT, POINT, true, "arrival") and state.phase == "encounter", "arrival starts encounter phase")
	_check(state.advance().is_empty() and state.phase == "encounter", "dialogue advance cannot bypass encounter")
	_check(state.cancel_encounter() and state.completed.is_empty(), "retreat does not complete encounter")
	_check(state.try_start(POINT, POINT, true, "click"), "stationary retry accepted")
	state.cancel_encounter()
	state.completed[EVENT] = true
	_check(not state.try_start(POINT, POINT, true, "arrival"), "completed encounter remains disabled")
	_check(state.respawn_encounter(EVENT) and not state.completed.has(EVENT), "respawn resets only encounter completion")
	for result in ["defeat", "draw", "retreat"]:
		_check(state.resolve_encounter(EVENT, result) and not state.completed.has(EVENT), result + " leaves enemy alive")
	_check(not state.resolve_encounter(EVENT, "unknown"), "invalid result cannot mark defeated")
	var pointer: Vector2 = map.map_to_screen(map.travel.node_positions[POINT])
	_click(pointer)
	_check(not map.encounter_dialog.visible and map.travel.destination_id == POINT, "remote real click only plans journey")
	map.travel.advance(0.01)
	_check(not map.travel.stop_at_current_node(), "stop helper rejects mid-edge teleport")
	map.travel.advance(1000)
	map.player.present(map.travel)
	await _settle()
	var modal: MapEncounterDialog = map.encounter_dialog
	_check(modal.visible and map.event_state.active_id == EVENT, "arrival automatically opens modal")
	_check(map.travel.paused and map.player.animation == "idle", "arrival pauses travel and stands")
	_check(modal.heading.text == "夹壁山径" and modal.description.text == raw.description, "exact requested story content")
	_check(modal.enemy_name.text == "赤鬃獠猪" and modal.rank_label.text == "凡人级·首领" and modal.category_label.text == "野兽类", "enemy name rank and category")
	_check(modal.enemy_description.text == raw.enemy_description, "enemy introduction from data")
	_check(modal.portrait.texture.resource_path == "res://assets/enemy-qshw-chisongliaozhu.webp", "requested portrait")
	for path in ["battle-tanchuang-full", "enemy-qshw-chisongliaozhu", "enemy-level", "icon-enemy-health", "icon-enemy-attack", "icon-enemy-defense", "icon-enemy-chara"]:
		_check((load("res://assets/" + path + ".webp") as Texture2D).get_image().has_mipmaps(), "mipmap enabled: " + path)
	_check(is_equal_approx(modal.canvas.get_global_rect().size.x / map.exit_dialog.canvas.get_global_rect().size.x, 4.0 / 3.0 * 0.8), "encounter scales down20percent from prior size")
	_check(Rect2(Vector2.ZERO, map.size).encloses(modal.canvas.get_global_rect()), "entire encounter frame fits native viewport")
	for label in [modal.heading, modal.description, modal.enemy_name, modal.rank_label, modal.category_label, modal.enemy_description]:
		_check(label.size.y >= label.get_minimum_size().y, "label height fits content: " + label.text)
	for button in [modal.fight_button, modal.retreat_button]:
		_check(button.get_global_rect().size.is_equal_approx(map.exit_dialog.confirm_button.get_global_rect().size * 0.8), "buttons are 80percent of exit dialog display size")
		_check(button.get_node("Caption").get_global_rect().get_center().is_equal_approx(button.get_global_rect().get_center()), "button caption centered")
	_check(modal.fight_button.get_node("Caption").text == "开战" and modal.retreat_button.get_node("Caption").text == "撤退", "requested actions")
	_check(modal.fight_button.texture_normal.resource_path.ends_with("button-queren.webp") and modal.retreat_button.texture_normal.resource_path.ends_with("button-quxiao.webp"), "correct action textures")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.save_png("res://artifacts/map-encounter-2k.png")
		shot.get_region(Rect2i(modal.canvas.get_global_rect())).save_png("res://artifacts/map-encounter-detail.png")
	_key(KEY_SPACE)
	_key(KEY_I)
	_click(Vector2(100, 300))
	_check(modal.visible and not map.is_inventory_open() and map.event_state.phase == "encounter", "space inventory and outside clicks cannot bypass modal")
	_click(modal.retreat_button.get_global_rect().get_center())
	await _settle()
	_check(not modal.visible and not map.travel.paused and map.travel.mode == "idle" and map.travel.current_node_id == POINT, "real retreat stays at node and releases map")
	_check(not map.event_state.completed.has(EVENT) and map.content.get_node("Points/N12/Sign").visible, "retreat preserves encounter sign")
	_click(pointer)
	await _settle()
	_check(modal.visible, "real stationary click reopens encounter")
	_key(KEY_ESCAPE)
	_check(not modal.visible, "escape retreats")
	map.travel.request_destination(NEIGHBOR)
	map.travel.advance(1000)
	map.travel.request_destination(BEYOND)
	map.travel.advance(1000)
	_check(map.travel.current_node_id == POINT and map.travel.paused and modal.visible, "large step stops at passing encounter before next edge")
	var position: Vector2 = map.travel.map_position
	map.travel.advance(1000)
	_check(map.travel.map_position == position, "active encounter blocks further travel")
	_click(modal.retreat_button.get_global_rect().get_center())
	map.travel.advance(1000)
	_check(map.travel.current_node_id == POINT and map.travel.mode == "idle" and map.travel.destination_id == POINT, "retreat cancels remaining route")
	_click(pointer)
	await _settle()
	map.inventory_save_path = "res://artifacts/missing-encounter-directory/save.json"
	_click(modal.fight_button.get_global_rect().get_center())
	await _settle()
	_check(current_scene == map and modal.visible and not modal.error_label.text.is_empty() and not modal.fight_button.disabled, "failed save leaves encounter retryable")
	map.inventory_save_path = SAVE
	var before: Dictionary = map.loadout.snapshot()
	_click(modal.fight_button.get_global_rect().get_center())
	# Duplicate signal in the same frame must not launch a second battle.
	map._confirm_encounter()
	await _wait_for_battle()
	var battle := current_scene
	_check(battle != map and battle.has_node("GameManager"), "real fight click transitions to battle scene")
	var manager: GameManager = battle.get_node("GameManager")
	manager.set_process(false)
	_check(manager.startup_error.is_empty() and manager.enemy_id == ENEMY, "actual manager selects boar")
	_check(manager.enemies[0].definition.name == "赤鬃獠猪" and manager.enemies[0].hp == 96 and manager.enemies[0].maximum("hp") == 96, "actual boar starts with exactly96 health: %s/%s" % [manager.enemies[0].hp, manager.enemies[0].maximum("hp")])
	_check(manager.enemies[0].inventory.get_instances().size() == 5 and manager.enemies[0].inventory.get_instances().all(func(entry: Dictionary): return entry.item_id.begins_with("base.organ.cslz_")), "enemy uses five own organs instead of dog claw")
	var dog := manager.registry.get_enemy(GameManager.ENEMY_ID)
	for key in ["max_spirit"]:
		_check(manager.enemies[0].definition[key] == dog[key], "unchanged dog parameter: " + key)
	_check(manager.enemies[0].definition.max_hp == 96 and manager.enemies[0].board.resource_bonuses.is_empty() and manager.enemies[0].maximum("stamina") == 98, "boar has no board bonuses")
	_check(manager.enemies[0].armor_type == "轻甲" and manager.enemies[0].armor == 0 and manager.enemies[0].maximum("armor") == 6, "actual boar armor matches preview")
	_check(manager.simulation.state.phase == GameState.Phase.PREPARATION, "encounter waits for explicit battle start")
	manager.start_battle()
	_check(manager.loadout_save_path == SAVE and manager._durable_snapshot == before, "battle receives same inventory and isolated path")
	_check(root.get_children().filter(func(child: Node): return child.has_node("GameManager")).size() == 1, "only one battle scene created")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/map-encounter-battle-2k.png")
	# Isolate victory/return wiring from combat balance. The real roster is now
	# empty, so this fixture no longer has two free test allies to win the fight.
	manager.enemies[0].hp = 1
	for second in 180:
		if manager.simulation.state.is_finished():
			break
		manager._process(1.0)
	_check(manager.simulation.state.result == "victory", "actual simulation wins against boar")
	_check(MapEventState.session_completed.has(EVENT), "real finished event records victory before returning")
	_check(not FileAccess.get_file_as_string(SAVE).contains(EVENT), "defeat state is not persisted to inventory save")
	var ui = battle.get_node("MainUI")
	ui._refresh()
	_check(ui._retreat_dialog.visible and ui._result_heading.text == "战斗胜利" and ui._exit_button.text == "返回地图", "victory offers return to map")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/encounter-victory-result.png")
	_click(ui._exit_button.get_global_rect().get_center())
	await _wait_for_map()
	var returned = current_scene
	_check(returned != battle and returned.has_method("_try_start_event"), "real return button loads original map")
	if not returned.has_method("_try_start_event"):
		quit(1)
		return
	returned.set_process(false)
	_check(returned.travel.current_node_id == POINT and returned.travel.mode == "idle", "return stands at screenshot node")
	_check(not returned.encounter_dialog.visible and not returned.content.get_node("Points/N12/Sign").visible, "victory hides sign and does not reopen popup")
	_check(returned.content.get_node("Points/N12").visible and returned.content.get_node("Points/N30/Sign").visible, "route point and unrelated west marker remain")
	_check(returned.loadout.snapshot() == before and returned.inventory_save_path == SAVE, "return preserves equipment and isolated save")
	returned.travel.request_destination(NEIGHBOR)
	returned.travel.advance(1000)
	returned.travel.request_destination(BEYOND)
	returned.travel.advance(1000)
	_check(returned.travel.current_node_id == BEYOND and not returned.event_state.is_active(), "passing defeated enemy no longer interrupts route")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/encounter-defeated-map.png")
	returned.queue_free()
	await _settle()
	var reentered = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	reentered.inventory_save_path = SAVE
	reentered.arrival_point_id = NEIGHBOR
	root.add_child(reentered)
	current_scene = reentered
	reentered.set_process(false)
	await _settle()
	_check(reentered.event_state.completed.has(EVENT) and not reentered.content.get_node("Points/N12/Sign").visible, "same-session map recreation preserves defeated enemy")
	_check(reentered.event_state.respawn_encounter(EVENT), "future respawn command accepted")
	_check(reentered.content.get_node("Points/N12/Sign").visible and not reentered.sign_motion.signs[POINT].finished, "respawn restores marker and idle animation")
	reentered.travel.request_destination(BEYOND)
	reentered.travel.advance(1000)
	_check(reentered.travel.current_node_id == POINT and reentered.encounter_dialog.visible, "passing respawned enemy auto encounters again")
	_check(not reentered.event_state.respawn_encounter(EVENT), "cannot respawn during active encounter")
	_click(reentered.encounter_dialog.fight_button.get_global_rect().get_center())
	await _wait_for_battle()
	var retreat_battle := current_scene
	var retreat_manager: GameManager = retreat_battle.get_node("GameManager")
	retreat_manager.set_process(false)
	_check(retreat_manager.request_retreat(), "combat retreat requested")
	for second in 10:
		if retreat_manager.simulation.state.is_finished():
			break
		retreat_manager._process(1.0)
	_check(retreat_manager.simulation.state.result == "defeat" and retreat_manager.simulation.state.finish_reason == "retreat" and not MapEventState.session_completed.has(EVENT), "combat retreat loses without removing enemy")
	var retreat_ui = retreat_battle.get_node("MainUI")
	retreat_ui._refresh()
	_click(retreat_ui._exit_button.get_global_rect().get_center())
	await _wait_for_map()
	var after_retreat = current_scene
	_check(after_retreat.has_method("_try_start_event"), "combat retreat returns instead of quitting application")
	if after_retreat.has_method("_try_start_event"):
		after_retreat.set_process(false)
		_check(after_retreat.content.get_node("Points/N12/Sign").visible and not after_retreat.encounter_dialog.visible, "retreat return keeps enemy alive without immediate reentry")
	after_retreat.queue_free()
	await _settle()
	_clean()
	print("MAP ENCOUNTER: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _wait_for_battle() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.has_node("GameManager") and not root.get_node("MapPresentation").transitioning:
			return
		await process_frame

func _wait_for_map() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.has_method("_try_start_event") and not root.get_node("MapPresentation").transitioning:
			await _settle()
			return
		await create_timer(0.01).timeout
