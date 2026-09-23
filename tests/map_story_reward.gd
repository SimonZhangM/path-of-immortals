extends SceneTree

const SAVE := "res://artifacts/story-reward-test.json"
const JADE := "base.map_item.warm_jade"
const REWARD := "base.map_reward.qingshihewan.warm_jade"
const BRIDGE := "base.map_event.qingshihewan.bridge_traces"
const N20 := "base.map.qingshihewan.point.n20"
const N37 := "base.map.qingshihewan.point.n37"
var checks := 0
var failures := 0
var screen: Control

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	_clean()
	MapEventState.session_completed.clear()
	root.size = Vector2i(1920, 1080)
	await _load_map()
	_check(screen.startup_error.is_empty(), "map starts")
	# N37 is on the route to N20; a large delta must not skip its event.
	screen.travel.request_destination(N20)
	screen.travel.advance(1000)
	screen.player.present(screen.travel)
	_check(screen.travel.current_node_id == N37 and screen.event_state.active_id == BRIDGE, "passing through a story node starts it automatically")
	_check(screen.travel.paused and screen.player.animation == "idle" and screen.event_state.line_index == 0, "arrival stands still and preserves first line")
	var position_before: Vector2 = screen.travel.map_position
	screen.travel.advance(1000)
	_check(screen.travel.map_position == position_before, "active story pauses remaining travel")
	for i in 5:
		screen._advance_dialogue()
	_check(not screen.travel.paused and not screen.event_state.is_active(), "finishing story releases travel")
	screen.travel.advance(1000)
	_check(screen.travel.current_node_id == N20 and screen.event_state.phase == "illustration", "original route resumes and N20 auto opens")
	screen.player.present(screen.travel)
	screen._advance_dialogue()
	for i in 14:
		screen._advance_dialogue()
	_check(screen.event_state.current_line().contains("那这个先借你"), "reward waits until lending line has been read")
	_check(_quantity(screen.loadout) == 1, "opening dialogue gives no item")
	screen._advance_dialogue()
	await _settle()
	var modal: MapRewardDialog = screen.reward_dialog
	_check(modal.visible and not screen.dialogue.visible and screen.event_state.phase == "reward", "reward modal replaces story presentation")
	_check(modal.heading.text == "获得物品" and modal.card.entry.id == JADE and not modal.card.canvas.has_node("Quantity"), "correct heading and single jade card without quantity")
	_check(modal.card.canvas.scale.x > 0 and modal.card.canvas.get_node("ItemName").text == "温玉佩", "reward card foreground has visible scale and name")
	_check(modal.accept_button.texture_normal.resource_path == "res://assets/button-queren.webp" and modal.pick_sound.stream == GameAudio.STREAMS.pick, "authored button and requested sound")
	_check(modal.accept_button.get_node("AcceptCaption").text == "收下" and modal.accept_button.get_node("AcceptCaption").get_theme_color("font_color") == Color.WHITE, "white accept caption")
	_check(is_equal_approx(modal.card.size.x / modal.card.size.y, 0.75) and modal.card.quality_badge.get_rect().get_center().is_equal_approx(Vector2(modal.card.size.x * 0.5, modal.card.size.y)), "reward card uses3:4 geometry with its quality badge centered on the lower border")
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = dimensions
		await _settle()
		_check(modal.heading.get_rect().end.y < modal.card.position.y and modal.card.get_rect().end.y < modal.accept_button.position.y, "title, item and button do not overlap")
		_check(Rect2(Vector2.ZERO, screen.size).encloses(modal.canvas.get_global_rect()), "modal fits viewport")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/story_reward_%d.png" % dimensions.x)
	_key(KEY_SPACE)
	_check(modal.visible and screen.event_state.phase == "reward" and _quantity(screen.loadout) == 1, "space cannot bypass the explicit reward acceptance")
	_click(Vector2(40, 300))
	_check(modal.visible and _quantity(screen.loadout) == 1, "outside click cannot claim or dismiss reward")
	screen.set_inventory_open(true)
	_check(not screen.is_inventory_open(), "inventory stays locked during reward")
	screen.inventory_save_path = "res://artifacts/nonexistent-story-directory/save.json"
	_click(modal.accept_button.get_global_rect().get_center())
	_check(modal.visible and not modal.error_label.text.is_empty() and not modal.accept_button.disabled, "failed save shows retryable error")
	_check(_quantity(screen.loadout) == 1 and not screen.loadout.has_reward(REWARD), "failed save changes neither inventory nor receipt")
	screen.inventory_save_path = SAVE
	_click(modal.accept_button.get_global_rect().get_center())
	_check(not modal.visible and screen.event_state.line_index == 15 and screen.dialogue.visible, "real accept click resumes next line exactly once")
	_check(_quantity(screen.loadout) == 2 and screen.loadout.has_reward(REWARD), "accept adds one jade and records receipt")
	_check(modal.pick_sound.playing, "successful acceptance plays pick sound")
	screen._accept_reward()
	_check(_quantity(screen.loadout) == 2, "stale/repeated acceptance cannot duplicate item")
	var fresh := _fresh()
	_check(MapLoadoutStore.load_into(fresh, SAVE).is_empty() and _quantity(fresh) == 2 and fresh.has_reward(REWARD), "receipt and item survive save reload")
	var reward_unit := "reward.%s.0" % REWARD
	var storage_id := _jade_storage(fresh)
	_check(fresh.place(fresh.drag_data("storage", storage_id), Vector2i.ZERO), "original jade equips from stack")
	storage_id = _jade_storage(fresh)
	_check(fresh.place(fresh.drag_data("storage", storage_id), Vector2i(1, 0)) and not fresh.inventory.get_instance(reward_unit).is_empty(), "reward jade equips as a separate stable instance")
	_check(MapLoadoutStore.save(fresh, SAVE).is_empty(), "equipped reward saves")
	var restored := _fresh()
	_check(MapLoadoutStore.load_into(restored, SAVE).is_empty() and restored.inventory.get_instance(reward_unit).get("cell") == Vector2i(1, 0), "equipped reward position survives restart")
	var receipt_before := restored.snapshot()
	_check(MapLoadoutStore.claim_reward(restored, screen.event_registry.events[screen.event_registry.by_point[N20]].reward, SAVE).is_empty() and restored.snapshot() == receipt_before, "receipt prevents direct duplicate grants after reload")
	var malformed := receipt_before.duplicate(true)
	malformed.granted_rewards[REWARD].quantity = -1
	_check(not restored.restore(malformed).is_empty() and restored.snapshot() == receipt_before, "malformed receipt is rejected atomically")
	var battle := GameManager.new()
	battle.use_saved_loadout = true
	battle.loadout_save_path = SAVE
	root.add_child(battle)
	battle.set_process(false)
	_check(battle.startup_error.is_empty() and battle.party[0].inventory.get_instance(reward_unit).get("cell") == Vector2i(1, 0), "battle reads the acquired item and saved placement")
	battle.queue_free()
	var replay := MapEventState.new(screen.event_registry, {BRIDGE: true})
	replay.reward_claimed = restored.has_reward
	replay.try_start(N20, N20, true, "arrival")
	replay.advance()
	for i in 15:
		replay.advance()
	_check(replay.phase == "dialogue" and replay.line_index == 15, "replayed story skips already claimed reward")
	var card := MapInventoryItemCard.new()
	var record: Dictionary = screen.loadout.records[JADE].duplicate(true)
	record.quantity = 2
	card.configure(record, "法器")
	_check(card.canvas.get_node("Quantity").text == "×2", "multiple items show quantity")
	card.free()
	# Do not let scene shutdown overwrite the isolated equipped-save fixture.
	screen.inventory_save_path = ""
	await create_timer(0.4).timeout
	screen.queue_free()
	await process_frame
	MapEventState.session_completed.clear()
	_clean()
	print("MAP STORY REWARD RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _jade_storage(state: MapLoadoutState) -> String:
	for entry in state.storage.entries():
		if entry.item_id == JADE:
			return entry.instance_id
	return ""

func _fresh() -> MapLoadoutState:
	var registry := ContentRegistry.new()
	registry.load_base_content()
	return MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag")).state

func _quantity(state: MapLoadoutState) -> int:
	var entry := state.storage.get_entry(_jade_storage(state))
	return entry.get("units", []).size()

func _load_map() -> void:
	screen = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	screen.inventory_save_path = SAVE
	root.add_child(screen)
	screen.set_process(false)
	await _settle()

func _settle() -> void:
	for i in 6:
		await process_frame

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event, true)

func _clean() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
