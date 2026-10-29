extends SceneTree

const Settings = preload("res://scripts/settings/game_settings.gd")
const SettingsInput = preload("res://scripts/settings/settings_input.gd")
const WorldMap = preload("res://scripts/map/map_world_map.gd")
var checks := 0
var failures := 0
var settings: Node
var before: Dictionary

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for _frame in 3: await process_frame

func apply(changes: Dictionary) -> void:
	var error: String = settings.apply_values(changes)
	check(error.is_empty(), "apply valid test preferences: " + error)

func wheel(button: MouseButton, point: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.global_position = point
	event.pressed = true
	return event

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	settings = root.get_node_or_null("GameSettings")
	if settings == null:
		settings = Settings.new()
		settings.name = "GameSettings"
		root.add_child(settings)
	before = Settings.values_snapshot()
	apply({"background_pause": false, "battle_speed": 2.0, "invert_zoom": false, "shortcut_hints": true})
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920,1080)
	var battle: Node = load("res://scenes/main/main.tscn").instantiate()
	var manager: GameManager = battle.get_node("GameManager")
	manager.use_saved_loadout = false
	manager.loadout_save_path = ""
	var ui: Control = battle.get_node("MainUI")
	ui.defer_battle_music = true
	ui.preview_all_status_icons = false
	root.add_child(battle)
	await settle()
	manager.set_process(false)
	check(manager.startup_error.is_empty(), "isolated actual battle starts without saved loadout")
	if not manager.startup_error.is_empty(): quit(1); return
	check(manager.simulation.state.phase == GameState.Phase.PREPARATION, "default speed does not auto-start combat")
	check(is_equal_approx(manager.simulation.clock.speed_multiplier,2.0), "new encounter starts with selected default speed")
	check(is_equal_approx(Engine.time_scale,1.0), "battle preference does not change Engine.time_scale")
	manager.start_battle()
	check(is_equal_approx(manager.simulation.clock.speed_multiplier,2.0), "starting combat preserves selected initial speed")
	manager.set_speed(0.5)
	check(is_equal_approx(float(Settings.value("battle_speed")),2.0), "temporary combat speed never overwrites preference")
	apply({"battle_speed":1.0})
	check(is_equal_approx(manager.simulation.clock.speed_multiplier,0.5), "changing preference does not alter running encounter")
	manager.restart()
	check(is_equal_approx(manager.simulation.clock.speed_multiplier,1.0), "next encounter takes new preference")
	var bindings: Dictionary = Settings.value("bindings")
	bindings.map_inventory = KEY_B
	bindings.map_world_map = KEY_N
	bindings.battle_pause = KEY_P
	bindings.speed_double = KEY_F8
	apply({"bindings":bindings})
	await settle()
	check(SettingsInput.action_label("speed_double")=="F8", "key label reads remapped physical key")
	check(ui._speed_buttons[2.0].tooltip_text.contains("F8"), "battle speed tooltip updates after rebinding")
	check(ui._bag_button.tooltip_text.contains("B"), "inventory tooltip updates after rebinding")
	manager._unhandled_key_input(key(KEY_F3))
	check(is_equal_approx(manager.simulation.clock.speed_multiplier,1.0), "old battle speed key is inactive")
	manager._unhandled_key_input(key(KEY_F8))
	check(is_equal_approx(manager.simulation.clock.speed_multiplier,2.0), "new battle speed key operates real manager")
	manager._unhandled_key_input(key(KEY_P))
	check(manager.simulation.state.phase==GameState.Phase.BATTLE, "new battle pause key starts preparation")
	manager._unhandled_key_input(key(KEY_P))
	check(manager.simulation.clock.paused, "new battle pause key toggles real pause")
	var view := WorldMap.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.present("base.map.qingshihewan",{})
	await settle()
	check(view.close_keys.text=="N/Esc", "world map closing hint follows remapped key")
	var anchor: Vector2 = view.map_window.size*0.5
	view._apply_zoom(anchor,10)
	view._map_input(wheel(MOUSE_BUTTON_WHEEL_UP,anchor))
	check(view.zoom_index==11,"world map normal wheel-up zooms in")
	view._map_input(wheel(MOUSE_BUTTON_WHEEL_DOWN,anchor))
	check(view.zoom_index==10,"world map normal wheel-down zooms out")
	view._slider_input(wheel(MOUSE_BUTTON_WHEEL_UP,Vector2(35,175)))
	check(view.zoom_index==11,"slider normal wheel uses same direction")
	apply({"invert_zoom":true})
	view._map_input(wheel(MOUSE_BUTTON_WHEEL_UP,anchor))
	check(view.zoom_index==10,"world map reversed wheel-up zooms out")
	view._slider_input(wheel(MOUSE_BUTTON_WHEEL_DOWN,Vector2(35,175)))
	check(view.zoom_index==11,"slider reversed wheel-down zooms in")
	view.plus_button.pressed.emit()
	check(view.zoom_index==view.zoom_levels.size()-1,"invert option does not reverse plus button")
	view.minus_button.pressed.emit()
	check(view.zoom_index==0,"invert option does not reverse minus button")
	view._set_slider_y(view.TRACK_TOP)
	check(view.zoom_index==view.zoom_levels.size()-1,"invert option does not reverse dragging the slider")
	apply({"shortcut_hints":false})
	await settle()
	check(not view.close_keys.visible and view.footer.visible,"hiding key hints keeps world map operation descriptions")
	check(ui._speed_buttons[2.0].tooltip_text=="2倍速","hiding key hints keeps battle button function names")
	check(not ui._battle_button.tooltip_text.contains("P"),"battle state tooltip hides key suffix")
	apply({"shortcut_hints":true})
	check(view.close_keys.visible and view.close_keys.text=="N/Esc","re-enabled world map hint uses latest binding")
	check(ui._speed_buttons[2.0].tooltip_text.contains("F8"),"re-enabled battle hint uses latest binding")
	var travel_map: Control = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	travel_map.inventory_save_path = ""
	travel_map.defer_location_save = true
	travel_map.defer_optional_views = true
	travel_map.defer_map_music = true
	root.add_child(travel_map)
	await settle()
	travel_map.set_process(false)
	check(travel_map.startup_error.is_empty(), "isolated travel map starts without user save")
	var travel_anchor: Vector2 = travel_map.map_viewport.get_rect().get_center()
	var travel_zoom: float = travel_map.zoom_factor
	travel_map._gui_input(wheel(MOUSE_BUTTON_WHEEL_UP,travel_anchor))
	check(travel_map.zoom_factor<travel_zoom, "travel map reversed wheel-up zooms out")
	apply({"invert_zoom":false})
	travel_map._gui_input(wheel(MOUSE_BUTTON_WHEEL_UP,travel_anchor))
	check(is_equal_approx(travel_map.zoom_factor,travel_zoom), "travel map normal wheel-up returns to prior zoom")
	travel_map.queue_free()
	view.queue_free()
	battle.queue_free()
	await settle()
	# Flush click voices produced by the actual plus/minus buttons before exit.
	var click_audio := root.get_node_or_null("UiButtonAudio")
	if click_audio != null: click_audio.player.stop()
	await create_timer(0.2).timeout
	settings.apply_values(before)
	print("settings_battle_input_tests: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
