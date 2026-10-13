extends SceneTree

const CASES := [
	["huiji_shanlang", "shanjihuilang", 12, 45, 4, 0],
	["qingke_heyuan", "qingkeheyuan", 7, 51, 7, 3],
	["qingling_yanzhi", "qinglingyanzhi", 28, 46, 7, 2],
	["chisong_liaozhu", "chisongliaozhu", 17, 96, 9, 2]
]
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 8: await process_frame
func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var run_id := str(Time.get_ticks_usec())
	for row: Array in CASES:
		MapEventState.session_completed.clear()
		MapEventState.session_encounters.clear()
		var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
		map.inventory_save_path = "res://artifacts/river-ready-%s-%s.json" % [run_id,row[0]]
		map.defer_map_music = true
		root.add_child(map)
		current_scene = map
		map.set_process(false)
		await settle()
		check(map.startup_error.is_empty(),row[0]+" actual map starts")
		var enemy_id: String = "base.enemy." + row[0]
		var background: String = "res://assets/battle-qingshihewan-"+row[1]+".webp"
		var definition: Dictionary = map.loadout.registry.get_enemy(enemy_id)
		check(map.loadout.registry.enemy_battle_error(enemy_id).is_empty(),row[0]+" available")
		check(EnemyPresentation.background_path(definition)==background,row[0]+" mapped filename")
		var texture := load(background) as Texture2D
		check(texture != null and texture.get_image().has_mipmaps(),row[0]+" background mipmaps")
		var point := "base.map.qingshihewan.point.n%02d" % row[2]
		map.travel.current_node_id = point
		map.travel.mode = "idle"
		map.travel.node_arrived.emit(point)
		check(map.encounter_dialog.visible and map.event_state.active_event().enemy_id==enemy_id,row[0]+" arrival opens correct enemy")
		check(map.encounter_dialog.location_illustration.texture.resource_path==map.event_state.active_event().presentation.illustration,row[0]+" location illustration matches")
		check(map.encounter_dialog.portrait.texture.resource_path==definition.portrait,row[0]+" portrait matches")
		check(map.encounter_dialog.description.text==map.event_state.active_event().description,row[0]+" authored location prose")
		await capture("river-ready-"+row[0]+"-encounter")
		# Exercise the actual dialog command and map-to-battle transition, without OS mouse input.
		map.encounter_dialog.select_action(1)
		map.encounter_dialog.fight_button.pressed.emit()
		var presentation := root.get_node("MapPresentation")
		while current_scene == map or presentation.transitioning: await process_frame
		var battle := current_scene
		var manager: GameManager = battle.get_node("GameManager")
		manager.set_process(false)
		var ui = battle.get_node("MainUI")
		check(manager.startup_error.is_empty() and manager.enemy_id==enemy_id,row[0]+" actual transition uses enemy")
		check(manager.simulation.state.phase==GameState.Phase.PREPARATION and manager.simulation.state.time_usec==0,row[0]+" waits for start")
		check(ui._backdrop.texture.resource_path==background,row[0]+" live battle shares preview image")
		var enemy: PartyMemberState = manager.enemies[0]
		check(enemy.maximum("hp")==row[3] and enemy.armor==0,row[0]+" authored hp and empty initial armor")
		check(enemy.inventory.occupied_cells()==row[4],row[0]+" correct occupied cells")
		await capture("river-ready-"+row[0]+"-battle")
		ui._battle_button.pressed.emit()
		check(manager.simulation.state.phase==GameState.Phase.BATTLE,row[0]+" starts through actual UI command")
		manager.simulation.advance(7)
		var events := manager.simulation.drain_events()
		check(events.any(func(e:Dictionary):return e.kind=="damage"),row[0]+" attacks run")
		check(enemy.armor==row[5],row[0]+" armor produced only after cooldown")
		battle.queue_free()
		await settle()
	print("RIVER BATTLE READY: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
