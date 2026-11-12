extends SceneTree

const RIVER := "res://scenes/maps/qingshihewan.tscn"
const EAST := "base.map.qingshihewan.point.east_exit"
const TOWN := "base.map.qingshizhen.point.n25"
const ENCOUNTER := "base.map.qingshihewan.point.n30"
const ENCOUNTER_APPROACH := "base.map.qingshihewan.point.n29"
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
var checks := 0
var failures := 0
var presentation: Node
var directory := "res://artifacts/map-presentation-20261110/run-%d/" % Time.get_ticks_usec()

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

func wait_for(condition: Callable, label: String, timeout_seconds := 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	var reached := bool(condition.call())
	check(reached, label)
	return reached

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory + label + ".png")

func _run() -> void:
	create_timer(50).timeout.connect(func():
		push_error("Map presentation test exceeded its 50-second limit.")
		quit(2))
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory + "auto.json"
	Session.index_path = directory + "session.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	var settings := root.get_node("GameSettings")
	settings.apply_values({"background_pause":false, "background_mute":false, "volume_master":1.0, "volume_music":1.0})
	settings.set_application_focus(true)
	# Muting pauses MusicPlayer. Use a quiet nonzero gain so track timing advances.
	settings._base_gain.volume_master = 0.000001
	settings.apply_values({"volume_master":1.0})
	presentation = root.get_node("MapPresentation")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	root.size = Vector2i(1920, 1080)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content registry accepts new innate armor data")
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "current combat catalog loads")
	if not created.error.is_empty(): quit(1); return
	# The round trip takes place after the rescue, with town-to-river travel open.
	var state: MapLoadoutState = created.state
	state.growth = CultivationGrowth.initial(int(registry.get_cultivation(state.cultivation_rank_id).order))
	var maxima := CultivationGrowth.maxima(state.growth)
	for resource: String in maxima:
		state.growth.resources[resource] = int(maxima[resource]) * 100
	var fixture := state.snapshot()
	for goal: Dictionary in QuestState.definition.objectives:
		fixture.quests[QuestState.ID].counts[goal.id] = goal.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[HerbQuest.ID].accepted_location = HerbQuest.data.accepted_location
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	fixture.quests[RiverQuest.ID].done = ["traces", "injured", "entrance", "root", "mirror", "beasts_gone", "medicine", "return_jade", "invite_doctor", "pickup", "clinic_arrival", "gift_book", "closing"]
	var fixture_error := state.restore(fixture)
	check(fixture_error.is_empty(), "post-rescue fixture satisfies current story prerequisites: " + fixture_error)
	if not fixture_error.is_empty(): quit(1); return
	var save_path: String = Slots.working_path()
	var save_error := MapLoadoutStore.save(state, save_path)
	check(save_error.is_empty(), "isolated fixture saved: " + save_error)
	if not save_error.is_empty(): quit(1); return
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
	map.inventory_save_path = save_path
	map.arrival_point_id = EAST
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	check(map.startup_error.is_empty(), "river ready")
	if not map.startup_error.is_empty(): quit(1); return
	# Begin measuring only after resource loading and scene construction finish.
	presentation.enter_map(map.definition)
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
	if not await wait_for(func(): return presentation.transitioning, "outgoing map transition starts"):
		quit(1); return
	var started := Time.get_ticks_msec()
	await wait_seconds(0.45)
	check(current_scene == map and presentation.transitioning and map.process_mode == Node.PROCESS_MODE_DISABLED, "old map retained and locked during wipe-out")
	check(presentation.music.volume_linear > 0 and presentation.music.volume_linear < presentation.MUSIC_VOLUME, "leaving music fades gradually")
	check(presentation._mask.get_shader_parameter("direction") == Vector2.RIGHT, "outgoing rightward shader")
	await wait_seconds(0.9)
	check(current_scene != map and presentation.transitioning, "scene changes after black, reveal still locked")
	check(presentation.map_id == "base.map.qingshizhen" and presentation.playlist.size() == 2, "town activates own two-song playlist")
	check(presentation._mask.get_shader_parameter("revealing"), "second half is reveal")
	if not await wait_for(func(): return not presentation.transitioning, "town reveal finishes"):
		quit(1); return
	check(absf(float(Time.get_ticks_msec() - started) / 1000.0 - 2.0) < 0.5, "total map picture/music transition takes 2 seconds")
	check(is_equal_approx(presentation.music.volume_linear,presentation.MUSIC_VOLUME), "map music completes fade with reveal")
	var town = current_scene
	check(town.travel.current_node_id == TOWN and not town.is_exit_open(), "town arrival at correct node without re-opening exit")
	check(not presentation._cover.visible and town.process_mode != Node.PROCESS_MODE_DISABLED, "reveal releases input lock")
	await capture("town-arrival")
	await wait_seconds(1.1)
	presentation.music.seek(presentation.music.stream.get_length() - 0.08)
	await wait_seconds(0.4)
	check(presentation.track_index == 1 and presentation.music.playing, "natural finish advances to town song 2")
	presentation.music.seek(presentation.music.stream.get_length() - 0.08)
	await wait_seconds(0.4)
	check(presentation.track_index == 0 and presentation.music.playing, "town playlist loops back to song 1")
	check(not HerbQuest.exit_blocked(town.loadout, town.definition.id, TOWN), "fixture keeps the town return exit unlocked")
	check(town._try_open_exit(TOWN) and not town.exit_dialog.confirm_button.disabled, "return exit confirmation available")
	town._confirm_exit()
	if not await wait_for(func(): return presentation.transitioning, "return map transition starts"):
		quit(1); return
	await wait_seconds(0.2)
	check(presentation._mask.get_shader_parameter("direction") == Vector2.LEFT, "reverse journey wipes right to left")
	if not await wait_for(func(): return not presentation.transitioning, "river reveal finishes"):
		quit(1); return
	map = current_scene
	check(map.travel.current_node_id == EAST and presentation.map_id == "base.map.qingshihewan", "reverse journey returns river music and node")
	check(presentation._mask.get_shader_parameter("direction") == Vector2.LEFT, "river reveals from right")
	await capture("river-return")
	await wait_seconds(1.1)
	# Start at the adjacent ordinary node so unrelated encounters cannot intercept.
	map._place_after_encounter(ENCOUNTER_APPROACH)
	check(map.travel.request_destination(ENCOUNTER), "adjacent route to the cliff boar is available")
	map.travel.advance(1000)
	check(map.encounter_dialog.visible and map.event_state.active_event().enemy_id == "base.enemy.chisong_liaozhu", "cliff boar encounter opens at N30")
	if not map.encounter_dialog.visible: quit(1); return
	map._confirm_encounter()
	if not await wait_for(func(): return presentation.transitioning, "battle transition starts"):
		quit(1); return
	var battle_started := Time.get_ticks_msec()
	await wait_seconds(0.25)
	check(current_scene == map and presentation.music_state == "pausing" and presentation.transitioning and presentation._cover.material == null, "battle entry fades picture and audio uniformly")
	if not await wait_for(func(): return current_scene != map, "battle reaches its black-screen midpoint"):
		quit(1); return
	var battle := current_scene
	check(absf((Time.get_ticks_msec()-battle_started)/1000.0-0.5)<.2, "battle midpoint at half a second")
	check(battle.has_node("GameManager"), "battle starts after map audio fades")
	if not battle.has_node("GameManager"):
		quit(1)
		return
	var manager: GameManager = battle.get_node("GameManager")
	manager.set_process(false)
	if not await wait_for(func(): return not presentation.transitioning, "battle reveal finishes"):
		quit(1); return
	check(absf((Time.get_ticks_msec()-battle_started)/1000.0-1.0)<.3, "battle entry picture and music complete in one second")
	check(presentation.music.stream_paused and presentation.music_state == "paused", "map stream paused, not stopped")
	check(manager.enemies[0].hp == 96 and manager.enemies[0].maximum("stamina") == 98 and manager.enemies[0].armor == 0 and manager.enemies[0].maximum("armor") == 6, "real battle matches popup stats")
	offset = presentation.music.get_playback_position()
	await wait_seconds(0.3)
	check(absf(presentation.music.get_playback_position() - offset) < 0.1, "music position remains fixed in combat")
	check(manager.simulation.state.phase == GameState.Phase.PREPARATION, "battle awaits the player's start command after reveal")
	manager.start_battle()
	var retreat_started := manager.request_retreat()
	check(retreat_started, "running battle accepts retreat")
	if not retreat_started: quit(1); return
	for i in 10:
		if manager.simulation.state.is_finished(): break
		manager._process(1.0)
	check(manager.simulation.state.result == "defeat" and manager.simulation.state.finish_reason == "retreat", "real battle finishes via retreat as defeat")
	var return_error: String = await battle.get_node("MapBattleReturn").return_to_map()
	check(return_error.is_empty(), "return coordinator succeeds: " + return_error)
	if not return_error.is_empty(): quit(1); return
	check(presentation.music_state == "playing" and not presentation.music.stream_paused and not presentation.transitioning, "combat return resumes after uniform transition")
	check(absf(presentation.music.get_playback_position() - offset - presentation.BATTLE_FADE) < 0.3, "combat return continues saved playback position during the half-second reveal")
	check(is_equal_approx(presentation.music.volume_linear, presentation.MUSIC_VOLUME), "return completes the half-second fade-in")
	await capture("battle-return")
	current_scene.queue_free()
	presentation.music.stop()
	await process_frame
	FileAccess.open(directory + "validation.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks, "failures":failures}, "\t"))
	print("MAP PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
