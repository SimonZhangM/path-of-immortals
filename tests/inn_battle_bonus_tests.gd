extends "res://tests/map_shop_tests.gd"

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	check(game.startup_error.is_empty(),"battle startup")
	if not game.startup_error.is_empty(): quit(1); return
	var status := MapPlayerStatus.new()
	status.configure(game.registry,JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json")))
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	var events := MapEventRegistry.new()
	check(events.configure([event],[event.point_id]).is_empty(),"battle event")
	for percent in [10,20,0]:
		var model: MapLoadoutState = game._durable_loadout
		var day := WorldCalendar.current_day(model.calendar)
		model.lodging_bonus = {"source_id":"base.lodging.qingshizhen.standard","percent":percent if percent>0 else 10,"start_day":day,"expires_day":day+10}
		if percent==0: model.advance_days(10,"test.inn.expiry")
		game._durable_snapshot = model.snapshot()
		game.restart()
		var flow = load("res://scripts/map/map_battle_return.gd").new()
		flow.manager = game
		flow.player_status = status
		flow.events = MapEventState.new(events,{})
		flow.event_id = event.id
		flow._loot_rolls = [0.99,0.99,0.99,0.99,0.99]
		var before := status.cultivation_progress
		var experience := status.experience
		game.start_battle()
		game.simulation._finish("victory",0)
		flow.save_path = "res://artifacts/no-inn-battle-parent/save.json"
		flow._record_result()
		check(not flow.reward_error.is_empty() and status.cultivation_progress==before,"failed loot save grants no boosted progression")
		flow.save_path = ""
		flow._record_result()
		var expected := snappedf(before+5.0*(1.0+percent/100.0),0.1)
		check(flow.reward_error.is_empty() and is_equal_approx(status.cultivation_progress,expected),"actual victory boost percent "+str(percent))
		check(status.experience==experience+2,"experience never boosted")
		flow._recorded = false
		flow._record_result()
		check(is_equal_approx(status.cultivation_progress,expected),"retry never repeats boosted progression")
		flow.free()
	scene.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	print("INN BATTLE BONUS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
