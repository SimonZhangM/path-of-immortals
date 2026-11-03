extends SceneTree

var checks := 0
var failures := 0
var directory := "res://artifacts/battle-return-latency-20261101/"

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 5: await process_frame

func run() -> void:
	var outcome := OS.get_environment("BATTLE_RETURN_CASE")
	if outcome.is_empty(): outcome = "victory"
	create_timer(60).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(directory)
	var map = load("res://scenes/maps/wumingjiuci.tscn").instantiate()
	map.inventory_save_path = directory+"save-%d.json" % Time.get_ticks_usec()
	map.defer_optional_views = true
	map.defer_map_music = true
	root.add_child(map)
	current_scene = map
	await settle()
	check(map.startup_error.is_empty(),"map startup")
	map._ensure_inventory_view()
	map._ensure_technique_view()
	var inventory = map.inventory_screen
	var technique = map.technique_screen
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/wumingjiuci_encounter_n04.json"))
	map.travel.current_node_id = event.point_id
	map.travel.mode = "idle"
	check(map._try_start_event(event.point_id,"click",true),"encounter opens")
	map._confirm_encounter()
	var presentation := root.get_node("MapPresentation")
	while current_scene==map or presentation.transitioning: await process_frame
	var battle := current_scene
	check(is_instance_valid(map) and not map.visible and not map.can_process() and not map._location_active,"original map retained hidden and paused")
	var camera: Vector2 = map.content.position
	var calendar: Dictionary = map.loadout.calendar.duplicate(true)
	var position: Vector2 = map.travel.map_position
	await settle()
	check(map.loadout.calendar==calendar and map.travel.map_position==position,"hidden map does not advance travel or date")
	if outcome=="abandon":
		var replacement := Control.new()
		root.add_child(replacement)
		current_scene = replacement
		battle.queue_free()
		await settle()
		check(not is_instance_valid(map),"scene replacement frees retained map")
		presentation.music.stop()
		replacement.queue_free()
		print("BATTLE_RETURN_ABANDON: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0)
		return
	var game: GameManager = battle.get_node("GameManager")
	var ui = battle.get_node("MainUI")
	game.set_process(false)
	game.start_battle()
	game.party[0].hp = 0 if outcome=="defeat" else 17
	game.simulation._finish(outcome,1000000)
	game._process(0)
	ui._refresh()
	await settle()
	if outcome=="victory":
		ui.victory_banner.reset()
		ui._show_victory_rewards()
	await settle()
	check(game.loot_error.is_empty() and (ui.victory_rewards.visible if outcome=="victory" else ui._retreat_dialog.visible),"result dialog ready")
	var expected: Dictionary = game._durable_snapshot.duplicate(true)
	var flow = battle.get_node("MapBattleReturn")
	if outcome=="victory":
		game._durable_snapshot.growth = {"invalid":true}
		check(not (await flow.return_to_map()).is_empty(),"invalid restore remains retryable")
		check(current_scene==battle and not flow._returning and not map.visible,"failed restore does not switch scene")
		game._durable_snapshot = expected.duplicate(true)
	var started := Time.get_ticks_usec()
	var previous := started
	var maximum_gap := 0.0
	var transition_ms := -1.0
	if outcome=="victory": ui.victory_rewards.accept_button.pressed.emit()
	else: game.request_battle_exit()
	while current_scene==battle or presentation.transitioning:
		await process_frame
		var now := Time.get_ticks_usec()
		maximum_gap = maxf(maximum_gap,(now-previous)/1000.0)
		previous = now
		if presentation.transitioning and transition_ms<0: transition_ms=(now-started)/1000.0
	var elapsed_ms := (Time.get_ticks_usec()-started)/1000.0
	var destination := current_scene
	check(destination==map,"return reuses original map instance")
	check(destination.inventory_screen==inventory and destination.technique_screen==technique,"existing views retained")
	check(destination.content.position==camera,"camera preserved")
	check(destination.can_process() and destination._location_active and not destination.travel.paused,"map resumed")
	check(destination.scene_file_path.ends_with("wumingjiuci.tscn") and destination.startup_error.is_empty(),"returns to original map")
	check(destination.travel.current_node_id==(event.point_id if outcome=="victory" else flow.retreat_point_id),"arrival follows result and retreat approach")
	check(destination.loadout.snapshot().owned_units==expected.owned_units,"all awarded units preserved exactly once")
	check(destination.loadout.battle_rewards==expected.get("battle_rewards",{}),"reward receipt preserved")
	check(destination.loadout.encounter_cooldowns==expected.get("encounter_cooldowns",{}),"respawn deadline preserved")
	if outcome=="victory": check(destination.loadout.growth==expected.growth,"resources and growth preserved")
	check(is_equal_approx(destination.player_status.resources.hp,1 if outcome=="defeat" else 17),"defeat one HP or surviving HP preserved")
	check(not destination.event_state.is_active() and not destination.encounter_dialog.visible,"encounter closed without retrigger")
	check(destination.event_state.completed.has(event.id)==(outcome=="victory"),"completion matches result")
	print("RETURN_TIMING: "+JSON.stringify({"fade_start_ms":transition_ms,"max_frame_gap_ms":maximum_gap,"total_ms":elapsed_ms,"inventory_built":destination.inventory_screen!=null,"technique_built":destination.technique_screen!=null}))
	await settle()
	check(not is_instance_valid(battle),"battle released")
	destination._ensure_inventory_view()
	check(destination.inventory_screen!=null,"inventory still opens on demand")
	destination._ensure_event_views()
	check(destination.encounter_dialog!=null,"encounter views still open on demand")
	destination.deactivate_location()
	destination.queue_free()
	await settle()
	presentation.music.stop()
	print("BATTLE_RETURN_LATENCY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
