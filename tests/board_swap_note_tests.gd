extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for frame in 8: await process_frame

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	await settle()
	check(game.startup_error.is_empty(), "actual battle loads")
	var registry := game.registry
	var grid := InventoryState.new(registry,Vector2i(4,4))
	check(grid.add_item("a","base.map_item.short_iron_hammer",Vector2i.ZERO), "first 1x2")
	check(grid.add_item("b","base.map_item.hunting_bow",Vector2i(2,0)), "second 1x2")
	var units: Array = grid.get_instance("a").units
	check(grid.move_item("a",Vector2i(2,0)) and grid.get_instance("b").cell == Vector2i.ZERO, "equal 1x2 swaps")
	check(grid.get_instance("a").units == units, "swap preserves unit identity")
	var before := grid.get_instances()
	check(not grid.move_item("a",Vector2i(0,1)) and grid.get_instances() == before, "partial footprint overlap rejected atomically")
	check(grid.add_item("c","base.map_item.t01_0016",Vector2i(3,2)), "1x1 beside large items")
	before = grid.get_instances()
	check(not grid.move_item("c",Vector2i.ZERO) and grid.get_instances() == before, "different dimensions rejected")
	check(not grid.move_item("a",Vector2i(3,3)), "out of bounds rejected")
	grid.locked = true
	check(not grid.move_item("a",Vector2i.ZERO), "running board lock still applies")
	var map_registry := ContentRegistry.new()
	map_registry.load_base_content()
	var created := MapLoadoutStore.create_state(map_registry,map_registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "isolated map inventory loads")
	var map_state: MapLoadoutState = created.state
	for id in ["base.map_item.t01_0016","base.map_item.t01_0017"]:
		var row: Dictionary = map_state.storage.entries().filter(func(e): return e.item_id == id)[0]
		check(map_state.place(map_state.drag_data("storage",row.instance_id),Vector2i(0,0) if id.ends_with("16") else Vector2i(1,0)), "map equips part")
	var first: Dictionary = map_state.inventory.get_instances()[0]
	var data := map_state.drag_data("board",first.instance_id)
	check(map_state.placement_kind(data,Vector2i(1,0)) == "swap" and map_state.place(data,Vector2i(1,0)), "map board path swaps exact 1x1 and marks valid preview")
	for id in ["base.map_item.t01_0011","base.map_item.t01_0016","base.map_item.t01_0017"]:
		var row: Dictionary = game.storage.entries().filter(func(e): return e.item_id == id)[0]
		var cell: Vector2i = {"base.map_item.t01_0011":Vector2i.ZERO,"base.map_item.t01_0016":Vector2i(1,0),"base.map_item.t01_0017":Vector2i(1,1)}[id]
		check(game.equip(row.instance_id,0,cell), "battle equips iron group")
	var body := game.party[0].inventory.item_at(Vector2i.ZERO)
	var arm := game.party[0].inventory.item_at(Vector2i(1,0))
	var leg := game.party[0].inventory.item_at(Vector2i(1,1))
	var bonus := game.simulation.t01.link_bonus(game.party[0])
	check(bonus.capacity == 3 and bonus.recovery[body] == 2 and game.party[0].maximum("armor") == 18, "iron group actual bonus +3/+2 and total capacity18")
	game.start_battle()
	game.simulation.advance(1)
	game.pause_battle()
	game.set_adjustment(true)
	var runtime := game.simulation.state.item_runtime.duplicate(true)
	var timers := game.simulation.timeline.timers.duplicate(true)
	var bag: InventoryView = scene.get_node("MainUI").ally_panel.bags[0]
	var drag := bag.drag_data_at(bag.cell_center(Vector2i(1,0)))
	check(bag._can_drop_data(bag.cell_center(Vector2i(1,1)),drag), "battle drop accepts exact 1x1 exchange")
	bag._drop_data(bag.cell_center(Vector2i(1,1)),drag)
	check(game.party[0].inventory.get_instance(arm).cell == Vector2i(1,1) and game.party[0].inventory.get_instance(leg).cell == Vector2i(1,0), "battle drop exchanges both cells")
	check(game.simulation.state.item_runtime == runtime and game.simulation.timeline.timers == timers, "both cooldowns and runtime unchanged")
	check(game.move_item(0,leg,Vector2i(2,2)) and game.simulation.t01.link_bonus(game.party[0]).capacity == 0, "breaking adjacency removes link bonus")
	game.set_adjustment(false)
	var item := registry.get_item("base.map_item.t01_0011")
	check(ItemTooltip.effect_text(item).contains("上限：护甲+10。") and ItemTooltip.effect_text(item).contains("套装：铁护臂和铁护腿同时与铁甲紧贴，铁甲护甲上限额外+3，铁甲恢复护甲额外+2。"), "iron tooltip uses concise capacity and set copy")
	var card := MapInventoryItemCard.new()
	card.configure(game._durable_loadout.records["base.material.cslz_heart"],"兽材")
	root.add_child(card)
	card.position = Vector2(900,400)
	check(card.canvas.get_node("CategoryTags").get_child_count() == 1, "duplicate beast category appears once")
	var tooltip := ItemTooltip.new()
	tooltip.configure(item,{},-1,0,true)
	root.add_child(tooltip)
	tooltip.position = Vector2(1150,350)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/board-swap-iron-note.png")
	tooltip.queue_free()
	card.queue_free()
	scene.queue_free()
	await settle()
	print("BOARD SWAP NOTE: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
