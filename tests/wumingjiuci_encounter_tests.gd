extends SceneTree

const Session = preload("res://scripts/entry/game_save_session.gd")
const DIR := "res://artifacts/wumingjiuci/"
const MAP := "base.map.wumingjiuci"
const DISTRIBUTION := {3:"huiyi_fu",4:"yanfu_duzhu",8:"xueju_huizhu",10:"heiwei_cishu",16:"xueju_huizhu",18:"heiwei_cishu",20:"huiyi_fu",23:"yanfu_duzhu",26:"xueju_huizhu",28:"huiyi_fu",30:"heiwei_cishu"}
var checks := 0
var failures := 0
var saved := DIR + "encounter-%d.json" % Time.get_ticks_usec()

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 5: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+name+".png")
func place(map: Node, n: int) -> void:
	var point := MAP+".point.n%02d" % n
	map.travel.stop_at_current_node()
	map.travel.current_node_id=point
	map.travel.map_position=map.travel.node_positions[point]
	map.travel.paused=false
	map.loadout.set_map_location(MAP,point)
	map.player.present(map.travel)
func fits(label: Label) -> bool:
	var rect: Rect2 = label.get_meta("source_rect")
	return label.get_minimum_size().y <= rect.size.y * label.size.x/rect.size.x+1
func run() -> void:
	create_timer(55).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	Session.index_path=saved+".index.json"
	Session.clear_selection()
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	var map = load("res://scenes/maps/wumingjiuci.tscn").instantiate()
	map.inventory_save_path=saved
	map.defer_map_music=true
	map.defer_optional_views=true
	root.add_child(map)
	current_scene=map
	await settle()
	check(map.startup_error.is_empty(),"actual shrine starts: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1);return
	for n: int in DISTRIBUTION:
		place(map,n)
		check(map._try_start_event(map.travel.current_node_id,"arrival",true), "arrival N%02d" % n)
		var event: Dictionary = map.event_state.active_event()
		var enemy: Dictionary = map.loadout.registry.get_enemy(event.enemy_id)
		check(event.enemy_id=="base.enemy."+DISTRIBUTION[n], "correct species N%02d" % n)
		check(not map.encounter_dialog.fight_button.disabled and map.encounter_dialog.enemy_name.text==enemy.name, "identified and fight enabled")
		check(map.encounter_dialog.portrait.texture.resource_path==enemy.portrait and map.encounter_dialog.portrait_frame.visible, "configured portrait and frame")
		check(map.encounter_dialog.loot_slots.size()==enemy.loot.size(), "only droppable materials shown")
		check(map.encounter_dialog.trait_labels[0].text==enemy.presentation.traits[0] and map.encounter_dialog.trait_labels[1].text==enemy.presentation.traits[1], "two authored traits")
		await settle()
		check(fits(map.encounter_dialog.description), "location prose fits")
		check(fits(map.encounter_dialog.enemy_description), "enemy prose fits: "+enemy.name)
		if n in [3,4,8,10]: await capture("ready-"+DISTRIBUTION[n]+"-encounter")
		map.encounter_dialog.select_action(0)
		map.encounter_dialog.activate_action(0)
		check(not map.event_state.is_active() and not map.travel.paused,"retreat resumes map")
	# Map state and save policy, including exactly the twentieth day.
	var original: Dictionary = map.loadout.snapshot()
	var fixture := original.duplicate(true)
	fixture.encounter_cooldowns = {}
	var today := WorldCalendar.current_day(fixture.calendar)
	for n: int in DISTRIBUTION: fixture.encounter_cooldowns["base.map_event.wumingjiuci.encounter_n%02d" % n]=today+20
	check(map.loadout.restore(fixture).is_empty(),"fixture cooldowns accepted")
	map._sync_calendar()
	check(map.event_state.completed.size()>=11,"all sites cleared")
	map.loadout.advance_days(19,"base.test.shrine_wait")
	map._sync_calendar()
	check(DISTRIBUTION.keys().all(func(n):return map.event_state.completed.has("base.map_event.wumingjiuci.encounter_n%02d" % n)),"no early respawn")
	map.loadout.advance_days(1,"base.test.shrine_wait")
	map._sync_calendar()
	check(DISTRIBUTION.keys().all(func(n):return not map.event_state.completed.has("base.map_event.wumingjiuci.encounter_n%02d" % n)),"all respawn on day20")
	map.loadout.restore(original)
	map._sync_calendar()
	for n in [10,8,3,4]:
		place(map,n)
		for resource in ["hp","stamina","spirit"]: map.player_status.set_resource(resource,map.player_status.maxima[resource])
		check(map._try_start_event(map.travel.current_node_id,"click",true),"open actual battle encounter")
		var event: Dictionary = map.event_state.active_event()
		var expected: Dictionary = map.loadout.registry.get_enemy(event.enemy_id)
		var before_xp: int = map.player_status.experience
		var before_progress: float = map.player_status.cultivation_progress
		map.encounter_dialog.select_action(1)
		map.encounter_dialog.fight_button.pressed.emit()
		var presentation := root.get_node("MapPresentation")
		while current_scene==map or presentation.transitioning: await process_frame
		var battle := current_scene
		var game: GameManager = battle.get_node("GameManager")
		game.set_process(false)
		check(game.startup_error.is_empty() and game.enemy_id==event.enemy_id,"battle loads selected enemy")
		check(game.simulation.state.phase==GameState.Phase.PREPARATION,"battle waits for start")
		check(battle.get_node("MainUI")._backdrop.texture.resource_path==expected.presentation.battle_background,"configured battle background bound")
		check((load(expected.presentation.battle_background) as Texture2D).get_image().has_mipmaps(),"battle mipmaps")
		await settle()
		await capture("ready-"+DISTRIBUTION[n]+"-battle")
		game.start_battle()
		game.simulation.advance(7.1)
		check(game.simulation.state.phase==GameState.Phase.BATTLE,"live combat runs first cycles")
		var outcome: String = "retreat" if n==8 else ("defeat" if n==3 else "victory")
		game.simulation._finish(outcome,game.simulation.state.time_usec)
		game._process(0)
		var return_point: String = event.point_id if outcome=="victory" else battle.get_node("MapBattleReturn").retreat_point_id
		var error: String = await battle.get_node("MapBattleReturn").return_to_map()
		check(error.is_empty(),"battle returns: "+error)
		await settle()
		map=current_scene
		check(map.definition.id==MAP and map.travel.current_node_id==return_point,"returns to shrine result location")
		if outcome=="victory":
			check(map.player_status.experience==before_xp+expected.progression_rewards.experience,"configured experience")
			check(is_equal_approx(map.player_status.cultivation_progress,before_progress+expected.progression_rewards.cultivation),"configured cultivation")
			check(map.event_state.completed.has(event.id) and map.loadout.encounter_cooldowns.has(event.id),"victory persists cooldown")
		else:
			check(map.player_status.experience==before_xp and not map.event_state.completed.has(event.id),"non-victory preserves encounter and gives no reward")
	var snapshot: Dictionary = map.loadout.snapshot()
	check(map._save_loadout().is_empty(),"save postbattle shrine")
	var clone: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(clone,saved).is_empty() and clone.snapshot().battle_rewards==snapshot.battle_rewards and clone.encounter_cooldowns==map.loadout.encounter_cooldowns,"reward and cooldown survive reload")
	map.queue_free()
	await settle()
	print("SHRINE ENCOUNTERS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
