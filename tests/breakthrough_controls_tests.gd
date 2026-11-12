extends "res://tests/save_actions_tests.gd"
const Flow = preload("res://scripts/map/map_breakthrough_session.gd")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event,true)
	await settle()

func run() -> void:
	create_timer(58).timeout.connect(func(): quit(2))
	directory = "res://artifacts/breakthrough-controls-20261104/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts")
	var before: Dictionary = map.loadout.snapshot()
	map.set_breakthrough_open(true)
	await settle()
	var screen: Control = map.breakthrough_screen
	var flow: RefCounted = map.breakthrough_session
	check(flow.pair_index==0 and screen.current_realm_art.texture.resource_path.ends_with("fanren.webp") and screen.target_realm_art.texture.resource_path.ends_with("lianqi.webp"),"initial story pair is mortal to qi, regardless of legacy test realm")
	var names := ["fanren","lianqi","zhuji","jiedan","yuanying","huashen"]
	for index in 5:
		screen.present_pair(index)
		check(screen.current_realm_art.texture.resource_path.ends_with(names[index]+".webp") and screen.target_realm_art.texture.resource_path.ends_with(names[index+1]+".webp"),"ordered realm pair %d" % index)
		for art: TextureRect in [screen.current_realm_art,screen.target_realm_art]:
			check(art.texture.get_image().has_mipmaps() and art.get_global_rect().end.y<330,"realm art uses mipmaps and remains in top plaque")
		if DisplayServer.get_name()!="headless": await capture("pair-%d-2560" % index)
	# Future progression selects from the same five pairs, without altering real state.
	var flag_before: Dictionary = map.loadout.narrative.flags.duplicate(true)
	var realm_before: int = map.loadout.growth.realm
	map.loadout.narrative.flags[Flow.FIRST_QI_FLAG] = true
	for realm in [1,2,3,4,5]:
		map.loadout.growth.realm = realm
		var next := Flow.new()
		next.configure(map.loadout)
		check(next.pair_index==mini(realm,4),"story-confirmed progression selects next legal pair")
	map.loadout.narrative.flags = flag_before
	map.loadout.growth.realm = realm_before
	screen.refresh()
	check(screen.pause_button.disabled and not screen.change_button.disabled,"preparation permits changes and has no running pause control")
	await click(screen.start_button)
	check(flow.phase=="running" and screen.change_button.disabled,"start runs panel session and disables change")
	map._process(2.5)
	check(flow.elapsed_usec==2500000,"running session clock advances")
	await click(screen.change_button)
	await key(KEY_I)
	await key(KEY_G)
	check(map.is_breakthrough_open() and not map.is_inventory_open() and not map.is_technique_open(),"running change click and keyboard cannot bypass pause")
	check(screen.composition_art.material.get_shader_parameter("change_disabled"),"running change artwork is gray")
	if DisplayServer.get_name()!="headless": await capture("running-gray-2560")
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		await click(screen.pause_button)
		check(flow.phase=="paused" and screen.pause_art.texture.resource_path.ends_with("UI-tupo-dibu-jixu.webp") and not screen.change_button.disabled,"pause click shows resume and enables adjustment")
		var stopped: int = flow.elapsed_usec
		map._process(9.0)
		check(flow.elapsed_usec==stopped,"paused clock remains fixed")
		if DisplayServer.get_name()!="headless": await capture("paused-%d" % resolution.x)
		await click(screen.change_button)
		check(map.is_inventory_open() and not map.is_breakthrough_open() and map._breakthrough_adjusting,"paused change opens bag with breakthrough parent")
		map._process(5.0)
		check(flow.elapsed_usec==stopped,"bag adjustment does not advance session")
		if resolution.x==2560:
			var chosen: Dictionary = {}
			for item: Dictionary in map.loadout.storage.entries():
				if map.loadout.equip_random(item.instance_id):
					chosen = item
					break
			check(not chosen.is_empty(),"actual storage item can be equipped during paused adjustment")
			await click(map.inventory_screen.return_button)
		else:
			await key(KEY_ESCAPE)
		check(map.is_breakthrough_open() and not map.is_inventory_open() and not map._breakthrough_adjusting and flow.phase=="paused","bag returns to paused breakthrough")
		await click(screen.pause_button)
		check(flow.phase=="running" and screen.pause_art.texture.resource_path.ends_with("UI-tupo-dibu-zanting.webp") and screen.change_button.disabled,"resume restores pause artwork and adjustment lock")
		map._process(0.5)
		check(flow.elapsed_usec==stopped+500000,"resume advances retained progress")
	await click(screen.pause_button)
	await click(screen.change_button)
	await key(KEY_T)
	check(map.is_breakthrough_open() and flow.phase=="paused","T from adjustment bag returns to breakthrough")
	await click(screen.pause_button)
	await click(screen.exit_button)
	await click(map.breakthrough_exit_dialog.confirm_button)
	check(not map.is_breakthrough_open() and flow.phase=="ready" and not flow.started and map.status_header.map_title.visible,"red exit closes and resets session")
	var stopped: int = flow.elapsed_usec
	await key(KEY_T)
	check(map.is_breakthrough_open() and flow.phase=="ready" and flow.elapsed_usec==0 and stopped==0,"reopen after red exit is ready with zero progress")
	check(map.loadout.growth==before.growth and map.loadout.quests==before.quests and map.loadout.calendar==before.calendar,"interface does not award a real breakthrough or advance the quest/calendar")
	check(map.loadout.snapshot().owned_units==before.owned_units,"adjustment preserves all item ownership")
	var restored := MapLoadoutStore.candidate(map.loadout)
	var restore_error := MapLoadoutStore.load_into(restored.state,map.inventory_save_path)
	check(restored.error.is_empty() and restore_error.is_empty() and FileAccess.file_exists(map.inventory_save_path) and restored.state.snapshot().placements==map.loadout.snapshot().placements,"bag return saves and reloads actual equipment changes")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("BREAKTHROUGH_CONTROLS: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
