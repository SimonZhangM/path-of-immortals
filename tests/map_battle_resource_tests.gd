extends SceneTree
var checks := 0
var failures := 0
const POINT := "base.map.qingshihewan.point.n12"
const EVENT := "base.map_event.qingshihewan.cliff_encounter"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in 8: await process_frame
func enter_battle(map: Node) -> Node:
	map.event_state.respawn_encounter(EVENT)
	map.travel.current_node_id = POINT
	map.travel.mode = "idle"
	check(map._try_start_event(POINT,"click",true),"encounter opens")
	map._confirm_encounter()
	var presentation := root.get_node("MapPresentation")
	while current_scene == map or presentation.transitioning: await process_frame
	var battle := current_scene
	battle.get_node("GameManager").set_process(false)
	battle.get_node("GameManager").start_battle()
	return battle
func return_from(battle: Node) -> Node:
	var error: String = await battle.get_node("MapBattleReturn").return_to_map()
	check(error.is_empty(),"return succeeds: " + error)
	await settle()
	return current_scene
func check_resources(map: Node, values: Dictionary, message: String) -> void:
	for key: String in values:
		check(is_equal_approx(float(map.player_status.resources[key]),float(values[key])),message + " " + key)
		check(map.status_header.values[key].text == "%s/%d" % [EffectSystem.number_text(values[key]),map.player_status.maxima[key]],"header keeps decimal: " + key)
		check(is_equal_approx(map.status_header.bars[key].value,float(values[key])),"bar keeps decimal: " + key)
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	MapEventState.session_completed.clear()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.arrival_point_id = POINT
	root.add_child(map)
	current_scene = map
	await settle()
	check(map.startup_error.is_empty(),"map startup")
	var status: MapPlayerStatus = map.player_status
	status.cultivation_progress = 27
	status.spirit_stones = 123
	status.experience = 45
	status.set_resource("hp",37.4)
	status.set_resource("stamina",22.6)
	status.set_resource("spirit",14.7)
	status.set_resource("hp",NAN)
	check_resources(map,{"hp":37.4,"stamina":22.6,"spirit":14.7},"prebattle")
	var battle := await enter_battle(map)
	var game: GameManager = battle.get_node("GameManager")
	check(game.party[0].hp == 37.4 and game.party[0].stamina == 22.6 and game.party[0].spirit == 14.7,"actual map-to-battle decimal resources")
	game.party[0].hp = 28.3
	game.party[0].stamina = 11.2
	game.party[0].spirit = 7.8
	game.simulation._finish("victory",12_000_000)
	game._process(0)
	check(status.resources == {"hp":28.3,"stamina":11.2,"spirit":7.8},"finish event commits authoritative result immediately")
	var flow = battle.get_node("MapBattleReturn")
	game.party[0].hp = 1 # A later UI/retry must not overwrite the recorded final snapshot.
	flow._record_result()
	check(status.resources.hp == 28.3,"finished snapshot recorded once")
	map = await return_from(battle)
	check(map.player_status == status,"return reuses current model")
	check_resources(map,{"hp":28.3,"stamina":11.2,"spirit":7.8},"victory return")
	check(status.cultivation_progress == 27 and status.spirit_stones == 123 and status.experience == 45,"noncombat progress retained without fabricated rewards")
	# The normal map-exit command must carry the same state too.
	map.travel.current_node_id = "base.map.qingshihewan.point.east_exit"
	map.travel.mode = "idle"
	check(map._try_open_exit(map.travel.current_node_id),"map exit opens")
	await map._complete_exit()
	await settle()
	map = current_scene
	check(map.player_status == status and map.scene_file_path.ends_with("qingshizhen.tscn"),"map transition retains state")
	check_resources(map,{"hp":28.3,"stamina":11.2,"spirit":7.8},"other map")
	check(map._try_open_exit(map.travel.current_node_id),"return exit opens")
	await map._complete_exit()
	await settle()
	map = current_scene
	for outcome in ["retreat","draw","defeat"]:
		battle = await enter_battle(map)
		game = battle.get_node("GameManager")
		check(is_equal_approx(game.party[0].hp,status.resources.hp),"next encounter uses latest HP")
		game.party[0].stamina = 9.1
		game.party[0].spirit = 3.2
		if outcome == "retreat":
			game.request_retreat()
			game._process(3)
			check(game.simulation.state.finish_reason == "retreat","actual retreat resolved")
		elif outcome == "defeat":
			game.party[0].hp = 1
			for index in 20: game.simulation.t01.forced_rolls.append(0.5)
			game._process(3)
			check(game.simulation.state.finish_reason == "defeat" and game.party[0].hp == 0,"enemy damage triggers actual zero-HP defeat")
			var ui = battle.get_node("MainUI")
			ui._refresh()
			check(ui._retreat_dialog.visible and ui._result_heading.text == "战斗失败","defeat screen shown before map return")
			check(status.resources.hp == 1 and game.party[0].hp == 0,"postbattle recovery does not revive defeated combatant")
		else:
			game.party[0].hp = 10.5
			game.simulation._finish(outcome,game.simulation.state.time_usec)
			# Exercise return fallback without draining finished events.
		var expected := {"hp":game.party[0].hp,"stamina":game.party[0].stamina,"spirit":game.party[0].spirit}
		if outcome == "defeat": expected.hp = 1.0
		map = await return_from(battle)
		check_resources(map,expected,outcome + " return")
	check(status.resources.hp == 1 and status.resources.stamina == 9.1 and status.resources.spirit == 3.2,"defeat restores only one HP, retains final stamina/spirit")
	check(status.cultivation_progress == 27,"progress survives all returns")
	map.queue_free()
	await settle()
	print("MAP/BATTLE RESOURCE HANDOFF: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
