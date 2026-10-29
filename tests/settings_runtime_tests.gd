extends SceneTree
const Settings = preload("res://scripts/settings/game_settings.gd")
const EntryMusic = preload("res://scripts/entry/entry_music.gd")
var checks := 0
var failures := 0
var service: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	service = root.get_node_or_null("GameSettings")
	if service == null:
		service = Settings.new()
		service.name = "SettingsRuntimeTestService"
		root.add_child(service)
	var original := Settings.values_snapshot()
	check(Settings.value("auto_save_minutes") == 10 and Settings.value("fps_limit") == 60, "confirmed initial values")
	check(Settings.value("volume_master") == 1.0 and Settings.value("volume_music") == 1.0 and Settings.value("volume_effects") == 1.0, "initial audio preserves full source loudness")
	var detached := Settings.values_snapshot()
	detached.bindings.map_inventory = KEY_X
	check(Settings.value("bindings").map_inventory == KEY_I, "snapshot cannot mutate committed bindings")
	check(service.defaults_for_page("game").size() == 7 and service.defaults_for_page("controls").size() == 3 and service.defaults_for_page("display").size() == 3 and service.defaults_for_page("audio").size() == 4 and service.defaults_for_page("other").is_empty(), "page defaults cover exact supported settings")
	check(InputMap.has_action("dialogue_continue") and InputMap.action_get_events("dialogue_continue").size() == 1, "dialogue action installed with one key")
	var changed_count := [0]
	service.settings_changed.connect(func(): changed_count[0] += 1)
	var rebound := Settings.values_snapshot()
	rebound.bindings.map_inventory = KEY_B
	check(service.apply_values(rebound).is_empty(), "valid remap applies")
	var old_input := InputEventKey.new()
	old_input.physical_keycode = KEY_I
	var new_input := InputEventKey.new()
	new_input.physical_keycode = KEY_B
	check(InputMap.event_is_action(new_input, "map_inventory") and not InputMap.event_is_action(old_input, "map_inventory"), "new key replaces old key rather than adding alternate")
	check(InputMap.action_get_events("map_inventory").size() == 1, "remapped action still has one key")
	var conflict := Settings.values_snapshot()
	conflict.bindings.map_techniques = KEY_B
	var before: int = changed_count[0]
	check(not service.apply_values(conflict).is_empty() and changed_count[0] == before, "same-context conflict rejected without change signal")
	check(Settings.value("bindings").map_techniques == KEY_G and InputMap.action_get_events("map_techniques")[0].physical_keycode == KEY_G, "invalid draft leaves committed state and InputMap intact")
	conflict.bindings.map_techniques = KEY_ESCAPE
	check(not service.apply_values(conflict).is_empty(), "Esc remains reserved")
	check(Settings.validate_bindings(original.bindings).is_empty(), "dialogue and battle may share Space across contexts")
	var shared: Dictionary = original.bindings.duplicate(true)
	shared.dialogue_continue = KEY_I
	check(Settings.validate_bindings(shared).is_empty(), "dialogue may reuse a map key behind the dialogue input gate")
	var battle_conflict: Dictionary = original.bindings.duplicate(true)
	battle_conflict.battle_pause = KEY_I
	check(not Settings.validate_bindings(battle_conflict).is_empty(), "battle pause cannot share the inventory key consumed before battle input")
	battle_conflict = original.bindings.duplicate(true)
	battle_conflict.speed_half = KEY_I
	check(not Settings.validate_bindings(battle_conflict).is_empty(), "battle speed cannot share the inventory key")
	battle_conflict = Settings.value("bindings")
	battle_conflict.map_inventory = KEY_F2
	check(not service.apply_values({"bindings": battle_conflict}).is_empty() and Settings.value("bindings").map_inventory == KEY_B, "inventory cannot take a battle speed key and invalid draft remains atomic")
	check(not service.apply_values({"fps_limit": 120}).is_empty() and Engine.max_fps == 60, "render cap cannot exceed 60")
	check(service.apply_values({"fps_limit": 30}).is_empty() and Engine.max_fps == 30, "render cap applies through Engine.max_fps")
	check(not service.apply_values({"volume_music": -0.1}).is_empty(), "invalid volume rejected")
	check(not service.apply_values({"auto_save_minutes": 11}).is_empty(), "unlisted save interval rejected")
	check(service.apply_values({"auto_save_minutes": 15, "auto_save": false, "quick_save": false}).is_empty() and Settings.value("auto_save_minutes") == 15 and not Settings.value("quick_save"), "save preferences are independent committed values")
	var entry := EntryMusic.new()
	root.add_child(entry)
	await process_frame
	var click = root.get_node("UiButtonAudio").player
	var map_music = root.get_node("MapPresentation").music
	check(entry.bus == "Music" and map_music.bus == "Music" and click.bus == "Effects", "entry/map music and UI effects routed separately")
	var entry_gain := entry.volume_db
	var click_gain: float = click.volume_db
	check(service.apply_values({"volume_master": 0.8, "volume_music": 0.5, "volume_effects": 0.25}).is_empty(), "audio settings apply")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.8) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.5) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Effects")), 0.25), "independent audio bus gains")
	check(entry.volume_db == entry_gain and click.volume_db == click_gain, "source gains remain unchanged")
	service.preview_audio({"volume_music": 0.2, "volume_effects": 0.4})
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.2) and Settings.value("volume_music") == 0.5, "audio preview does not commit draft")
	service.cancel_preview()
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.5), "cancel restores committed audio")
	service.apply_values({"background_pause": true, "background_mute": true})
	paused = false
	AudioServer.set_bus_mute(0, false)
	service.set_application_focus(false)
	check(paused and AudioServer.is_bus_mute(0), "focus loss pauses gameplay and mutes audio")
	service.set_application_focus(true)
	check(not paused and not AudioServer.is_bus_mute(0), "focus return releases owned pause and mute")
	paused = true
	AudioServer.set_bus_mute(0, true)
	service.set_application_focus(false)
	service.set_application_focus(true)
	check(paused and AudioServer.is_bus_mute(0), "preexisting pause and mute preserved")
	paused = false
	AudioServer.set_bus_mute(0, false)
	service.apply_values({"background_pause": false})
	service.set_application_focus(false)
	check(not paused and AudioServer.is_bus_mute(0), "background pause and mute independent")
	service.set_application_focus(true)
	service.apply_values({"background_pause": false, "background_mute": false})
	if OS.get_environment("SETTINGS_DISPLAY_TEST") == "1":
		check(DisplayServer.get_name() != "headless", "display test has actual window")
		check(service.apply_values({"display_mode": "windowed", "resolution": Vector2i(1280,720)}).is_empty(), "window mode and supported resolution apply")
		await process_frame
		await process_frame
		check(root.mode == Window.MODE_WINDOWED and root.size == Vector2i(1280,720), "actual window becomes 1280x720")
		check(service.apply_values({"display_mode": "borderless"}).is_empty(), "borderless fullscreen applies")
		await process_frame
		await process_frame
		check(root.mode == Window.MODE_FULLSCREEN and Settings.value("resolution") == service.native_resolution(), "fullscreen uses native display size")
	entry.stop()
	entry.stream = null
	entry.queue_free()
	check(service.apply_values(original).is_empty(), "all original session settings restored")
	service.set_application_focus(true)
	await create_timer(0.1).timeout
	print("SETTINGS_RUNTIME: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
