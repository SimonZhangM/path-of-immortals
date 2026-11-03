extends SceneTree
const Session = preload("res://scripts/entry/game_save_session.gd")
const POINT := "base.map.qingshihewan.point.n02"
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 5: await process_frame
func place(map: Node, point: String) -> void:
	map.travel.current_node_id=point
	map.travel.map_position=map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	map.travel.paused=false
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	Session.index_path="res://artifacts/shrine-exit-click/unused.index.json"
	Session.clear_selection()
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	map.defer_optional_views=true
	map.defer_location_save=true
	root.add_child(map)
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"river starts")
	check(map.exits_by_point[POINT].trigger=="arrival","shrine gate uses arrival")
	# Approach from N03; N01 has an unrelated automatic encounter on departure.
	var from := "base.map.qingshihewan.point.n03"
	map.travel.exploration_enabled=false
	place(map,from)
	check(map.travel.request_destination(POINT),"request gate destination")
	check(not map._try_open_exit(POINT),"gate cannot open before arrival")
	map.travel.advance(1000)
	check(map.travel.current_node_id==POINT and map.travel.mode=="idle","stops at chosen gate")
	check(map.is_exit_open() and map.travel.paused,"arrival automatically opens confirmation and pauses movement")
	check(map._active_exit.scene=="res://scenes/maps/wumingjiuci.tscn" and map._active_exit.target_point=="base.map.wumingjiuci.point.n01","arrival confirmation retains destination")
	check(map.definition.id=="base.map.qingshihewan","arrival only asks for confirmation without switching maps")
	map._cancel_exit()
	check(not map.is_exit_open() and not map.travel.paused,"cancel restores movement")
	map.travel.advance(1000)
	check(not map.is_exit_open(),"remaining stationary after cancel does not reopen confirmation")
	check(map._try_open_exit(POINT) and map.is_exit_open(),"stationary manual activation can reopen confirmation")
	map._cancel_exit()
	check(map.travel.request_destination(from) and map.travel.mode!="idle","can depart gate normally after cancellation")
	map.travel.advance(1000)
	check(map.travel.current_node_id==from and not map.is_exit_open(),"departure does not reopen gate confirmation")
	check(map.travel.request_destination(POINT),"can approach gate again")
	map.travel.advance(1000)
	check(map.is_exit_open() and map._active_exit.point_id==POINT,"returning to gate automatically reopens confirmation")
	map._cancel_exit()
	# The river's original town exit retains the default automatic trigger.
	var other := "base.map.qingshihewan.point.east_exit"
	place(map,other)
	map._on_node_arrived(other)
	check(map.is_exit_open() and map._active_exit.point_id==other,"other exit still auto-opens")
	map._cancel_exit()
	var invalid: Array=map.definition.exits.duplicate(true)
	invalid[0].trigger="invalid"
	check(not map._configure_exits(invalid).is_empty(),"invalid trigger rejected")
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("SHRINE EXIT ARRIVAL: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
