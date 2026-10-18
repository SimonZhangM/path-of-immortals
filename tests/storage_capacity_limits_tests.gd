extends SceneTree

const HOME := "base.warehouse.qingshizhen.home"
const SWORD := "base.map_item.qingshi_short_sword"
const Transfer := preload("res://scripts/map/map_warehouse_transfer.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func fixture(source: MapLoadoutState, count: int, exclude: Array = []) -> MapLoadoutState:
	var state: MapLoadoutState = MapLoadoutStore.candidate(source).state
	var next := state.snapshot()
	next.board_id = "base.board.bag"
	next.placements = []
	next.formations = []
	next.owned_units = {}
	next.warehouses = {}
	next.bag_capacity = 100
	next.spirit_stones = 10000
	var ids := state.records.keys()
	ids.sort()
	for id: String in ids:
		if id in exclude: continue
		next.owned_units["capacity."+id] = id
		if next.owned_units.size() == count: break
	check(state.restore(next).is_empty(), "isolated fixture hydration")
	return state

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	check(map.startup_error.is_empty(), "map starts with new capacity rules")
	var source: MapLoadoutState = map.loadout
	check(source.storage_capacity_limit()==100, "configured capacity is 100")
	var state := fixture(source,100,[SWORD])
	check(not state.storage_over_capacity(), "100 is not overcapacity")
	var next := state.snapshot()
	next.owned_units["warehouse.sword"] = SWORD
	next.warehouses = {HOME:{"warehouse.sword":SWORD}}
	check(state.restore(next).is_empty(), "warehouse fixture")
	var before := state.snapshot()
	check(not Transfer.execute(state,HOME,SWORD,true,"").is_empty(), "new kind withdrawal rejected at 100")
	check(state.snapshot()==before, "rejected withdrawal preserves both sides")
	check(not Transfer.execute(state,HOME,"",true,"",true).is_empty(), "withdraw all cannot bypass capacity")
	check(state.snapshot()==before, "bulk rejection is atomic")
	check(Transfer.preview(state,HOME,SWORD,true).blocked, "warehouse preview blocks new kind")
	var shop := MapShop.new()
	check(shop.load_catalog("res://data/shops/qingshizhen_shop.json",state).is_empty(), "shop loads")
	check(not shop.purchase(state,SWORD,1,"").is_empty(), "purchase rejects a new kind at capacity")
	check(state.snapshot()==before, "purchase rejection preserves money and serial")
	check(not MapLoadoutStore.claim_reward(state,{"id":"base.map_reward.capacity_test","item_id":SWORD,"quantity":1},"").is_empty(), "claim awaits free space")
	check(state.snapshot()==before, "rejected reward preserves claim receipt")
	var existing: String = state.storage.entries()[0].item_id
	next = state.snapshot()
	next.owned_units["warehouse.same"] = existing
	next.warehouses[HOME]["warehouse.same"] = existing
	check(state.restore(next).is_empty(), "same-kind warehouse fixture")
	check(Transfer.execute(state,HOME,existing,true,"",false,1).is_empty(), "existing kind stacks at capacity")
	check(state.storage_used_slots()==100, "stack counts only once")
	var result := Transfer.perform(state,HOME,existing,false,"")
	check(result.error.is_empty() and state.storage_used_slots()==99, "deposit frees one kind")
	check(Transfer.execute(state,HOME,SWORD,true,"").is_empty() and state.storage_used_slots()==100, "withdraw into freed slot")
	before = state.snapshot()
	check(not Transfer.undo(state,result.receipt,"").is_empty(), "undo cannot overfill freed slot")
	check(state.snapshot()==before, "failed undo retains exact units")
	check(not Transfer.undo_error(state,result.receipt).is_empty(), "history explains capacity block")
	state = fixture(source,105)
	var owned: Dictionary = state.snapshot().owned_units.duplicate()
	for index in 5:
		var item: String = state.storage.entries()[0].item_id
		check(Transfer.execute(state,HOME,item,false,"").is_empty(), "legacy overflow can be deposited")
	check(state.storage_used_slots()==100 and state.snapshot().owned_units==owned, "legacy cleanup loses no units")
	check(MapLoadoutStore.save(state,"res://artifacts/capacity-isolated.json").is_empty(), "save organized state")
	var reloaded: MapLoadoutState = MapLoadoutStore.candidate(source).state
	check(MapLoadoutStore.load_into(reloaded,"res://artifacts/capacity-isolated.json").is_empty(), "reload organized state")
	check(not Transfer.execute(reloaded,HOME,"",true,"",true).is_empty(), "restriction survives reload")

	# A fully equipped kind is absent from the bag; returning it needs a slot.
	state = fixture(source,100,[SWORD])
	check(state.save_formation("空阵型",state.formation_icons[0],"",false,false).is_empty(), "empty formation")
	var empty_id: String = state.formations[0].id
	next = state.snapshot()
	next.owned_units["equipped.sword"] = SWORD
	next.placements = [{"instance_id":"equipped.sword","item_id":SWORD,"unit_ids":["equipped.sword"],"cell":[0,0]}]
	check(state.restore(next).is_empty(), "equipped fixture")
	before = state.snapshot()
	check(not state.take_back(state.drag_data("board","equipped.sword")), "unequip rejected when bag full")
	check(state.snapshot()==before, "unequip keeps board and bag unchanged")
	check(state.apply_formation(empty_id).contains("容量不足"), "formation cannot overflow bag")
	check(state.snapshot()==before, "formation failure atomic")
	var knife := "base.map_item.t01_0002"
	next = state.snapshot()
	next.owned_units["extra.knife"] = knife
	check(state.restore(next).is_empty(), "swap stack fixture")
	var knife_entry: Dictionary = state.storage.entries().filter(func(row: Dictionary): return row.item_id==knife)[0]
	before = state.snapshot()
	check(not state.place(state.drag_data("storage",knife_entry.instance_id),Vector2i.ZERO), "swap cannot add displaced kind while incoming stack remains")
	check(state.snapshot()==before, "swap failure atomic")
	check(state.select_board("base.map_item.qinglan_board_1").is_empty(), "larger board retains layout")
	check(state.place(state.drag_data("board","equipped.sword"),Vector2i(3,0)), "place sword beyond small board")
	before = state.snapshot()
	check(state.select_board("base.map_item.bag_board").contains("容量不足"), "smaller board cannot overflow bag")
	check(state.snapshot()==before, "board change failure atomic")
	var battle_path := "res://artifacts/capacity-battle.json"
	check(MapLoadoutStore.save(state,battle_path).is_empty(), "isolated battle fixture saved")
	var game := GameManager.new()
	game.use_saved_loadout = true
	game.loadout_save_path = battle_path
	root.add_child(game)
	game.set_process(false)
	check(game.startup_error.is_empty(), "battle manager starts")
	check(not game.unequip(0,"equipped.sword"), "battle unequip obeys capacity")
	check(not game.equip(knife_entry.instance_id,0,Vector2i(3,0)), "battle swap obeys capacity")
	check(not game.change_board("capacity.base.map_item.bag_board"), "battle board change obeys capacity")
	check(game.storage.entries().size()==100 and not game.party[0].inventory.get_instance("equipped.sword").is_empty(), "failed battle commands preserve inventory")
	game.queue_free()
	await process_frame

	# Victory drops are explicitly exempt, but the loaded map must disable running.
	var enemy := source.registry.get_enemy("base.enemy.grey_ridge_wolf")
	if enemy.is_empty():
		for row: Dictionary in source.registry._enemies.values():
			if not row.get("loot",[]).is_empty(): enemy = row; break
	var loot_ids: Array = []
	var rolls: Array = []
	for row: Dictionary in enemy.loot: loot_ids.append(row.item_id); rolls.append(0.0)
	state = fixture(source,100,loot_ids)
	var loot := BattleLoot.candidate(state,enemy,"capacity.battle",rolls)
	check(loot.error.is_empty() and not loot.drops.is_empty(), "victory prepares all earned drops")
	check(state.restore(loot.snapshot).is_empty() and state.storage_over_capacity(), "victory can exceed capacity without losing loot")
	var count: int = state.snapshot().owned_units.size()
	var retry := BattleLoot.candidate(state,enemy,"capacity.battle",rolls)
	check(retry.snapshot.owned_units.size()==count, "victory retry never duplicates loot")
	var before_victory := fixture(source,100,loot_ids)
	check(MapLoadoutStore.save(before_victory,battle_path).is_empty(), "full bag victory fixture")
	game = GameManager.new()
	game.use_saved_loadout = true
	game.enemy_id = enemy.id
	game.loadout_save_path = battle_path
	root.add_child(game)
	game.set_process(false)
	check(game.startup_error.is_empty(), "full bag battle starts")
	game.simulation.state.result = "victory"
	var flow = load("res://scripts/map/map_battle_return.gd").new()
	flow.manager = game
	flow._loot_rolls = rolls
	flow.event_id = "base.map_event.capacity.encounter"
	flow.save_path = battle_path
	var event_registry := MapEventRegistry.new()
	event_registry.events[flow.event_id] = {"respawn_days":20}
	flow.events = MapEventState.new(event_registry,{}, {})
	check(flow._award_victory().is_empty(), "full bag victory completes without blocking result")
	check(game.loot_summary.contains("只能行走"), "victory explains overloaded movement")
	check(game._durable_snapshot.encounter_cooldowns.has(flow.event_id), "victory still records respawn deadline")
	var earned: Dictionary = game._durable_snapshot.owned_units.duplicate()
	check(game.persist_consumption() and game._durable_snapshot.owned_units==earned, "return persistence retains overflow loot")
	flow.free()
	game.queue_free()
	await process_frame
	check(map.loadout.restore(state.snapshot()).is_empty(), "map accepts overfull battle return")
	check(not map.travel.running_allowed, "loaded overfull bag disables map running")
	for row: String in loot_ids: map.loadout.transfer_warehouse(HOME,row,false)
	check(map.loadout.storage_used_slots()==100 and map.travel.running_allowed, "organizing to exactly 100 restores running immediately")
	map.inventory_screen.set_warehouse(HOME)
	map.inventory_screen.show()
	for index in 8: await process_frame
	var ui: MapInventoryScreen = map.inventory_screen
	check(ui.storage_capacity.displayed_capacity()==Vector2i(100,100), "bag shows actual count and limit")
	check(ui.warehouse_pane.storage_capacity.displayed_capacity()==Vector2i(loot_ids.size(),99), "warehouse shows actual count")
	ui.catalog.set_filter("search","不存在的物品")
	for index in 4: await process_frame
	check(ui.storage_capacity.displayed_capacity()==Vector2i(100,100), "filter does not affect occupancy")
	ui.catalog.set_filter("search","")
	if DisplayServer.get_name() != "headless":
		for index in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/storage-capacity-actual.png")
	map.queue_free()
	for index in 8: await process_frame
	print("STORAGE CAPACITY: %d checks, %d failures; isolated state" % [checks,failures])
	quit(1 if failures else 0)
