extends "res://tests/save_actions_tests.gd"

const SWORD := "base.map_item.t01_0033"
const UNIT := "test.half_second.sword"
var registry := ContentRegistry.new()

class FailingSaveManager extends GameManager:
	func persist_consumption() -> bool:
		simulation.clock.paused=true
		return false

func make_manager(cooldown: float, fail_save := false) -> GameManager:
	registry.get_item(SWORD).cooldown_usec = roundi(cooldown*1000000.0)
	var player_data := registry.get_character("base.character.chen_yu").duplicate(true)
	player_data.max_hp=10000; player_data.max_stamina=10000; player_data.max_spirit=10000
	var player := PartyMemberState.new(player_data,registry)
	check(player.inventory.add_item(UNIT,SWORD,Vector2i.ZERO),"equip actual red-flame blade")
	var enemy_data := registry.get_enemy("base.enemy.wild_dog").duplicate(true)
	enemy_data.max_hp=100000; enemy_data.max_stamina=10000; enemy_data.max_spirit=10000
	var enemy := PartyMemberState.new(enemy_data,registry)
	var game: GameManager = FailingSaveManager.new() if fail_save else GameManager.new()
	game.registry=registry; game.party=[player]; game.enemies=[enemy]
	game.restart()
	game.simulation.t01.rng.seed=7
	check(game.simulation.settlement_interval_usec==500000,"normal manager enables half-second batches")
	game.set_speed(1.0)
	game.start_battle()
	check(game.simulation.state.phase==GameState.Phase.BATTLE,"normal start entry")
	return game

func count(game: GameManager) -> int:
	return int(game.simulation.state.item_runtime[UNIT].activation_count)

func arm_enemy(game: GameManager) -> void:
	game.enemies[0].inventory.locked=false
	check(game.enemies[0].inventory.add_item("test.enemy.sword",SWORD,Vector2i.ZERO),"equip same-time enemy weapon")
	game.restart()
	game.simulation.t01.rng.seed=7
	game.set_speed(1.0)
	game.start_battle()

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	directory="res://artifacts/battle-half-second-20261107/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"; Session.index_path=directory+"session.json"
	root.get_node("SavePlaytime").set_process(false)
	AudioServer.set_bus_mute(0,true)
	check(registry.load_base_content(),"base content loads")
	check(MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).error.is_empty(),"real weapon registered")
	var game := make_manager(5.5)
	game._process(5.49)
	check(game.simulation.state.time_usec==5000000 and count(game)==0,"5.49 has no early activation")
	check(game.simulation.presentation_time_usec()==5490000 and game.simulation.activation_progress(UNIT)>0.99,"clock and cooldown interpolate pending time")
	var timers := game.simulation.timeline.timers.duplicate(true)
	game.simulation.activation_progress(UNIT)
	game.simulation.cooling_remaining_usec(UNIT)
	check(game.simulation.timeline.timers==timers,"presentation reads do not settle authoritative timers")
	game._process(0.01)
	check(game.simulation.state.time_usec==5500000 and count(game)==1,"5.5 second weapon settles in exact batch")
	game._process(5.5)
	check(count(game)==2,"next cycle remains 11.0")
	game.free()
	game=make_manager(5.7)
	var events: Array=[]
	game.presentation_events.connect(func(batch): events.append_array(batch))
	game._process(5.7)
	check(game.simulation.state.time_usec==5500000 and count(game)==0,"5.7 waits for 6.0 batch")
	check(is_equal_approx(game.simulation.activation_progress(UNIT),1.0),"ready can display before effect batch")
	game._process(0.3)
	check(game.simulation.state.time_usec==6000000 and count(game)==1,"6.0 batch publishes 5.7 action")
	check(events.any(func(event): return int(event.get("at_usec",-1))==5700000),"effect retains precise due timestamp")
	game._process(5.5)
	check(count(game)==2 and events.any(func(event): return int(event.get("at_usec",-1))==11400000),"second action remains 11.4 and publishes at 11.5")
	game.free()
	for speed in [0.5,2.0]:
		game=make_manager(5.7)
		game.set_speed(speed)
		game._process(5.7/speed)
		check(count(game)==0 and game.simulation.presentation_time_usec()==5700000,"speed scales simulation time")
		game._process(0.3/speed)
		check(count(game)==1 and game.simulation.state.time_usec==6000000,"speed retains half simulation-second batch")
		game.free()
	game=make_manager(5.7)
	game._process(5.8)
	game.pause_battle()
	check(game.simulation.clock.paused and count(game)==1 and game.simulation.state.time_usec==5800000,"pause flushes exact remainder before adjustment")
	game._process(10)
	check(game.simulation.presentation_time_usec()==5800000 and count(game)==1,"pause freezes clock and effects")
	game.toggle_pause()
	game._process(0.1)
	check(game.simulation.state.time_usec==5800000 and game.simulation.presentation_time_usec()==5900000,"resume cannot move authority backwards after fractional flush")
	game._process(0.1)
	check(game.simulation.state.time_usec==6000000 and count(game)==1,"resume rejoins next regular boundary")
	game.free()
	game=make_manager(5.7)
	game._process(0.7)
	check(game.request_retreat() and game.simulation.state.retreat_at_usec==3700000,"retreat deadline starts after exact pending-time flush")
	game._process(3.3)
	check(game.simulation.state.result=="defeat" and game.simulation.state.finished_at_usec==3700000 and game.simulation.presentation_time_usec()==3700000,"retreat ends at its actual due time inside the final batch")
	game.free()
	game=make_manager(5.7)
	game._process(5.8)
	check(game.set_item_automatic(UNIT,false) and count(game)==1 and game.simulation.state.time_usec==5800000,"mode command follows earlier queued effects")
	game.free()
	var batched := make_manager(5.7)
	arm_enemy(batched)
	var reference := make_manager(5.7)
	arm_enemy(reference)
	reference.simulation.settlement_interval_usec=0
	var batched_events: Array=[]
	var reference_events: Array=[]
	batched.presentation_events.connect(func(batch): batched_events.append_array(batch))
	reference.presentation_events.connect(func(batch): reference_events.append_array(batch))
	batched._process(11.5); reference._process(11.5)
	check(batched_events==reference_events,"same-time events retain exact ordering and results")
	for side in 2:
		var actual: PartyMemberState=batched.simulation.state.teams[side][0]
		var expected: PartyMemberState=reference.simulation.state.teams[side][0]
		check(actual.hp==expected.hp and actual.stamina==expected.stamina and actual.spirit==expected.spirit,"same-time resource results match precise simulation")
	batched.free(); reference.free()
	game=make_manager(5.7)
	game.enemies[0].hp=1
	game._process(6.0)
	check(game.simulation.state.result=="victory" and game.simulation.state.finished_at_usec==5700000,"victory keeps exact lethal event time inside batch")
	check(game.simulation.presentation_time_usec()==5700000,"finished clock stops at victory event")
	game.free()
	game=make_manager(5.7,true)
	game.use_saved_loadout=true
	game._process(0.2)
	game.simulation._pending_events.append({"kind":"pill_used","consumed":true})
	game.pause_battle()
	check(game.simulation.clock.paused,"failed consumption save during pause flush stays paused")
	game.free()
	game=make_manager(5.7,true)
	game.use_saved_loadout=true
	game._process(0.2)
	game.simulation._pending_events.append({"kind":"pill_used","consumed":true})
	check(not game.set_item_automatic(UNIT,false) and game.simulation.timeline.timers[UNIT].auto,"failed flush prevents the subsequent mode command")
	game.free()
	# Normal scene entry also uses the manager policy and the UI time reader.
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var live: GameManager=scene.get_node("GameManager")
	live.use_saved_loadout=false; live.loadout_save_path=""
	root.add_child(scene)
	live.set_process(false)
	await settle()
	check(live.startup_error.is_empty() and live.simulation.settlement_interval_usec==500000,"actual battle scene starts with half-second settlement")
	live.start_battle(); live.set_speed(1.0); live._process(0.2)
	var ui = scene.get_node("MainUI")
	ui._refresh()
	check(ui._time.text==ui.format_battle_time(live.simulation.presentation_time_usec()),"actual battle clock reads smooth presentation time")
	scene.queue_free()
	await settle()
	print("HALF-SECOND BATTLE: %d checks, %d failures; %s"%[checks,failures,directory])
	quit(1 if failures else 0)
