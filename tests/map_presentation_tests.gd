extends SceneTree

const RIVER := "res://scenes/maps/qingshihewan.tscn"
const EAST := "base.map.qingshihewan.point.east_exit"
const TOWN := "base.map.qingshizhen.point.n25"
const ENCOUNTER := "base.map.qingshihewan.point.n12"
var checks := 0
var failures := 0
var presentation: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000)
	while Time.get_ticks_usec() < until:
		await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/map-transition-" + label + ".png")

func _run() -> void:
	presentation = root.get_node("MapPresentation")
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content registry accepts new innate armor data")
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "current combat catalog loads")
	var enemy := PartyMemberState.new(registry.get_enemy("base.enemy.chisong_liaozhu"), registry)
	enemy.equip_definition_loadout()
	var ally := PartyMemberState.new(registry.get_character(GameManager.PARTY_IDS[0]), registry)
	var sim := BattleSimulation.new([ally], [enemy], registry)
	check(sim.start(), "boar simulation starts")
	check(enemy.hp == 96 and enemy.stamina == 98, "actual resources equal displayed 96/98")
	check(enemy.armor_type == "轻甲" and enemy.armor == 0 and enemy.maximum("armor") == 6, "actual armor light/0/6")
	sim.t01.refresh_equipment(enemy)
	check(enemy.maximum("armor") == 6 and enemy.armor_type == "轻甲", "hide armor survives equipment recomputation")
	check(enemy.defense == 0, "innate capacity is not legacy fixed defense")
	var invalid := registry.get_enemy("base.enemy.chisong_liaozhu").duplicate(true)
	invalid.id = "test.enemy.invalid"
	invalid.initial_armor = 7
	check(not registry.register_enemy(invalid), "invalid starting armor rejected")
	check(presentation.direction(Vector2(3113,823), Vector2(3215,1835), false) == Vector2.RIGHT, "river exits left to right")
	check(presentation.direction(Vector2(187,1469), Vector2(3317,1865), true) == Vector2.RIGHT, "town reveals from left")
	check(presentation.direction(Vector2(50,0), Vector2(100,100), false) == Vector2.UP, "future top exit direction")
	check(presentation.direction(Vector2(50,100), Vector2(100,100), true) == Vector2.UP, "future bottom arrival direction")
	check(not presentation.validate_music({"music": ["res://missing.mp3"]}).is_empty(), "missing track rejected before transition")
	var map = load(RIVER).instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	current_scene = map
	check(map.startup_error.is_empty(), "river ready")
	check(presentation.music.playing and presentation.music.volume_linear < 0.05, "entry starts music near silence")
	await wait_seconds(3.1)
	check(presentation.music_state == "playing" and is_equal_approx(presentation.music.volume_linear, presentation.MUSIC_VOLUME), "3 second music fade reaches full gain")
	var offset: float = presentation.music.get_playback_position()
	presentation.enter_map(map.definition)
	check(presentation.music.get_playback_position() >= offset - 0.1, "duplicate activation does not restart song")
	map._try_open_exit(EAST)
	map._active_exit.target_point = "missing"
	await map._complete_exit()
	check(current_scene == map and not presentation.transitioning and not map.exit_dialog.confirm_button.disabled, "bad link remains retryable without changing audio/map")
	map._active_exit.target_point = TOWN
	map._confirm_exit()
	while not presentation.transitioning: await process_frame
	var started := Time.get_ticks_msec()
	await wait_seconds(0.45)
	check(current_scene == map and presentation.transitioning and map.process_mode == Node.PROCESS_MODE_DISABLED, "old map retained and locked during wipe-out")
	check(presentation.music.volume_linear > 0 and presentation.music.volume_linear < presentation.MUSIC_VOLUME, "leaving music fades gradually")
	check(presentation._mask.get_shader_parameter("direction") == Vector2.RIGHT, "outgoing rightward shader")
	await capture("outgoing")
	await wait_seconds(0.9)
	check(current_scene != map and presentation.transitioning, "scene changes after black, reveal still locked")
	check(presentation.map_id == "base.map.qingshizhen" and presentation.playlist.size() == 2, "town activates own two-song playlist")
	check(presentation._mask.get_shader_parameter("revealing"), "second half is reveal")
	await capture("incoming")
	while presentation.transitioning:
		await process_frame
	check(absf(float(Time.get_ticks_msec() - started) / 1000.0 - 2.0) < 0.5, "total map picture/music transition takes 2 seconds")
	check(is_equal_approx(presentation.music.volume_linear,presentation.MUSIC_VOLUME), "map music completes fade with reveal")
	var town = current_scene
	check(town.travel.current_node_id == TOWN and not town.is_exit_open(), "town arrival at correct node without re-opening exit")
	check(not presentation._cover.visible and town.process_mode != Node.PROCESS_MODE_DISABLED, "reveal releases input lock")
	await wait_seconds(1.1)
	presentation.music.seek(presentation.music.stream.get_length() - 0.08)
	await wait_seconds(0.4)
	check(presentation.track_index == 1 and presentation.music.playing, "natural finish advances to town song 2")
	presentation.music.seek(presentation.music.stream.get_length() - 0.08)
	await wait_seconds(0.4)
	check(presentation.track_index == 0 and presentation.music.playing, "town playlist loops back to song 1")
	town._try_open_exit(TOWN)
	town._confirm_exit()
	await wait_seconds(0.2)
	check(presentation._mask.get_shader_parameter("direction") == Vector2.LEFT, "reverse journey wipes right to left")
	while presentation.transitioning:
		await process_frame
	map = current_scene
	check(map.travel.current_node_id == EAST and presentation.map_id == "base.map.qingshihewan", "reverse journey returns river music and node")
	check(presentation._mask.get_shader_parameter("direction") == Vector2.LEFT, "river reveals from right")
	await wait_seconds(1.1)
	map.travel.request_destination(ENCOUNTER)
	map.travel.advance(1000)
	check(map.encounter_dialog.visible, "encounter opens at N12")
	map._confirm_encounter()
	map._confirm_encounter()
	while not presentation.transitioning: await process_frame
	var battle_started := Time.get_ticks_msec()
	await wait_seconds(0.5)
	check(current_scene == map and presentation.music_state == "pausing" and presentation.transitioning and presentation._cover.material == null, "battle entry fades picture and audio uniformly")
	var deadline := Time.get_ticks_msec() + 4000
	while current_scene == map and Time.get_ticks_msec() < deadline:
		await process_frame
	var battle := current_scene
	check(absf((Time.get_ticks_msec()-battle_started)/1000.0-1.0)<.2, "battle midpoint at one second")
	check(battle.has_node("GameManager"), "battle starts after map audio fades")
	if not battle.has_node("GameManager"):
		quit(1)
		return
	var manager: GameManager = battle.get_node("GameManager")
	manager.set_process(false)
	while presentation.transitioning: await process_frame
	check(absf((Time.get_ticks_msec()-battle_started)/1000.0-2.0)<.3, "battle entry picture and music complete in two seconds")
	check(presentation.music.stream_paused and presentation.music_state == "paused", "map stream paused, not stopped")
	check(manager.enemies[0].hp == 96 and manager.enemies[0].maximum("stamina") == 98 and manager.enemies[0].armor == 0 and manager.enemies[0].maximum("armor") == 6, "real battle matches popup stats")
	offset = presentation.music.get_playback_position()
	await wait_seconds(0.3)
	check(absf(presentation.music.get_playback_position() - offset) < 0.1, "music position remains fixed in combat")
	manager.request_retreat()
	for i in 10:
		if manager.simulation.state.is_finished(): break
		manager._process(1.0)
	check(manager.simulation.state.result == "defeat" and manager.simulation.state.finish_reason == "retreat", "real battle finishes via retreat as defeat")
	var return_error: String = await battle.get_node("MapBattleReturn").return_to_map()
	check(return_error.is_empty(), "return coordinator succeeds")
	check(presentation.music_state == "playing" and not presentation.music.stream_paused and not presentation.transitioning, "combat return resumes after uniform transition")
	check(absf(presentation.music.get_playback_position() - offset - 1.0) < 0.3, "combat return continues saved playback position during reveal")
	check(is_equal_approx(presentation.music.volume_linear, presentation.MUSIC_VOLUME), "return completes 1 second fade-in")
	current_scene.queue_free()
	presentation.music.stop()
	await process_frame
	print("MAP PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
