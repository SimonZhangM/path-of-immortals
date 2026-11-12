extends "res://tests/save_actions_tests.gd"

const LETTER := "base.map_item.yesongnian_letter"
const MIRROR := "base.map_item.broken_mirror"
const BOOK := "base.book.yinqijue"

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	directory = "res://artifacts/quest-item-inventory-20261106/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	root.get_node("SavePlaytime").set_process(false)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"content loads")
	var made := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(made.error.is_empty(),"ungraded quest definitions accepted")
	if not made.error.is_empty(): quit(1); return
	var state: MapLoadoutState = made.state
	state.growth = CultivationGrowth.initial(int(registry.get_cultivation(state.cultivation_rank_id).order))
	var fresh := state.snapshot()
	for item_id in [LETTER,MIRROR]:
		check(state.records[item_id].quality.is_empty() and state.records[item_id].card_frame.is_empty(),"plain quest card data: "+item_id)
		check(registry.get_item(item_id).quality.is_empty() and registry.get_item(item_id).effects.is_empty(),"ungraded shared item: "+item_id)
	var source := OS.get_environment("QUEST_ITEM_LEGACY_SOURCE")
	check(FileAccess.file_exists(source),"isolated old save supplied")
	if not FileAccess.file_exists(source): quit(1); return
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var untouched := old.duplicate(true)
	check(state.restore(old).is_empty(),"old completed mirror save restores")
	check(old==untouched,"migration leaves source dictionary intact")
	check(state.carried_owned().values().count(MIRROR)==1 and state.has_reward(RiverQuest.data.scenes.mirror.reward.id),"missing legacy mirror recovered once with reward receipt")
	check(state.content_grants.get("quest.mirror_item.v1",false),"content migration receipt recorded")
	check(MapLoadoutStore.save(state,directory+"recovered.json").is_empty(),"recovered mirror persists")
	check(MapLoadoutStore.load_into(state,directory+"recovered.json").is_empty() and state.carried_owned().values().count(MIRROR)==1,"reload cannot duplicate mirror")
	var recovered := state.snapshot()
	var receipt_only := recovered.duplicate(true)
	for unit: String in receipt_only.owned_units.keys():
		if receipt_only.owned_units[unit]==MIRROR: receipt_only.owned_units.erase(unit)
	check(state.restore(receipt_only).is_empty() and MIRROR not in state.carried_owned().values(),"existing award receipt prevents regrant")
	check(state.restore(fresh).is_empty() and MIRROR not in state.carried_owned().values(),"unplayed mirror scene grants nothing")
	check(state.restore(recovered).is_empty(),"restore recovered inventory")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	check(config.categories.key=="任务" and config.collections.key=="任务","both task labels renamed")
	check(catalog.replace_entries(state.storage_records()).is_empty(),"task storage records valid")
	catalog.set_filter("collection","key")
	for item_id in [LETTER,MIRROR,BOOK]:
		check(catalog.visible_entries().any(func(row): return row.id==item_id),"task filter contains "+item_id)
	var ui := MapInventoryScreen.new()
	ui.configure(catalog,config,state.board,state)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	var neutral_cards := 0
	for card in ui.grid.get_children():
		if not card is MapInventoryItemCard: continue
		if card.entry.id not in [LETTER,MIRROR,BOOK]: continue
		neutral_cards += 1
		check(card.frame==null and card.background.texture is GradientTexture2D,"matching neutral card layout: "+card.entry.id)
	check(neutral_cards==3,"letter, mirror and introductory book share actual framed cards")
	check(ui.board_capacity.displayed_capacity()==Vector2i(state.inventory.occupied_cells(),state.board.grid_size.x*state.board.grid_size.y),"equipped board shows authoritative occupancy")
	if DisplayServer.get_name()!="headless": await capture("task-items-and-occupancy")
	var empty_board := state.snapshot()
	empty_board.placements = []
	empty_board.owned_units["test.capacity.sword"] = "base.map_item.qingshi_short_sword"
	check(state.restore(empty_board).is_empty(),"clear board for occupancy fixture")
	check(state.select_board("base.map_item.bag_board").is_empty(),"equip basic bag")
	await settle()
	var slash_center := ui.board_capacity.get_global_transform_with_canvas()*ui.board_capacity.number_center()
	var unit := "test.capacity.sword"
	check(state.inventory.add_item(unit,"base.map_item.qingshi_short_sword",Vector2i.ZERO),"equip real two-cell sword")
	state.storage.take_one(unit)
	state.changed.emit()
	await settle()
	check(ui.board_capacity.displayed_capacity()==Vector2i(2,9),"two occupied cells in basic bag")
	check((ui.board_capacity.get_global_transform_with_canvas()*ui.board_capacity.number_center()).is_equal_approx(slash_center),"occupied digits keep slash position")
	check(state.select_board("base.map_item.qinglan_board_1").is_empty(),"equip owned Xiaolan")
	await settle()
	check(ui.board_capacity.displayed_capacity()==Vector2i(2,state.board.grid_size.x*state.board.grid_size.y),"switching board keeps fitting sword and updates total")
	check((ui.board_capacity.get_global_transform_with_canvas()*ui.board_capacity.number_center()).is_equal_approx(slash_center),"board switch keeps slash position")
	print("QUEST ITEM INVENTORY: %d checks, %d failures; %s" % [checks,failures,directory])
	ui.queue_free()
	await settle()
	quit(1 if failures else 0)
