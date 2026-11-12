extends "res://tests/save_actions_tests.gd"

func board_matches(map: Control, label: String) -> void:
	var screen: Control = map.breakthrough_screen
	var view: MapLoadoutBoard = screen.board_view
	var entries: Array = map.loadout.inventory.get_instances()
	check(view.state==map.loadout and view.layout==map.loadout.board and screen.board_art.texture.resource_path==map.loadout.board.texture_path,label+" uses actual board and inventory")
	check(view._items.size()==entries.size(),label+" has exact live item count")
	for entry: Dictionary in entries:
		check(view._items.has(entry.instance_id),label+" has actual instance "+entry.instance_id)
		if not view._items.has(entry.instance_id): continue
		var art: MapItemArtwork = view._items[entry.instance_id]
		var dimensions: Vector2i = map.loadout.registry.get_item(entry.item_id).grid_size
		var target := view.get_global_transform()*view.layout.footprint_rect(entry.cell,dimensions,view.size).get_center()
		var actual := art.get_global_transform()*art._visible_local_center(true)
		check(actual.distance_to(target)<0.2,label+" maps actual footprint to matching image center")

func equip_one(map: Control) -> String:
	for entry: Dictionary in map.loadout.storage.entries():
		var item: ItemData = map.loadout.registry.get_item(entry.item_id)
		if item.category not in ["weapon","armor","artifact","pill","throwable"]: continue
		if not map.loadout.inventory.matching_stack(item.id).is_empty(): continue
		var cells: Array = map.loadout.inventory.available_cells(item.id)
		if cells.is_empty(): continue
		if map.loadout.place(map.loadout.drag_data("storage",entry.instance_id),cells[0]): return String(entry.units[0].id)
	return ""

func run() -> void:
	create_timer(58).timeout.connect(func(): quit(2))
	directory = "res://artifacts/breakthrough-layout-sync-20261104/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts")
	var before: Dictionary = map.loadout.snapshot()
	map.set_breakthrough_open(true)
	await settle()
	var screen: Control = map.breakthrough_screen
	check(map.loadout.snapshot()==before,"display binding does not mutate gameplay")
	board_matches(map,"initial display")
	check(map.loadout.select_board("base.map_item.qinglan_board_1").is_empty(),"fixture selects actual Xiaolan board")
	var first := equip_one(map)
	var second := equip_one(map)
	check(not first.is_empty() and not second.is_empty(),"fixture equips two real owned items")
	await settle()
	board_matches(map,"equipped Xiaolan")
	check(not screen.board_reference.get_meta("provisional_layout") and screen.board_reference.get_rect()==Rect2(928,335,705,705),"confirmed Xiaolan profile is retained")
	check(screen.board_view.mouse_filter==Control.MOUSE_FILTER_STOP and screen.board_view.has_meta(ItemTooltipHost.SOURCE_META) and not screen.board_view._can_drop_data(Vector2.ZERO,map.loadout.drag_data("board",first)),"breakthrough board supports hover but cannot accept drops")
	var after_seed: Dictionary = map.loadout.snapshot()
	screen.board_view._drop_data(Vector2.ZERO,map.loadout.drag_data("board",first))
	check(map.loadout.snapshot()==after_seed,"read-only preview cannot mutate construction")
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		var factor: float = screen.stage.scale.x
		check(screen.primary_start_art.visible and not screen.primary_running_art.visible,"default visibility is start only")
		check(screen.primary_start_art.get_global_rect()==screen.primary_running_art.get_global_rect(),"both pictures have identical rectangles")
		check(screen.primary_start_art.get_global_rect().size.distance_to(Vector2(650.4,217.2)*1.08*factor)<0.1,"both pictures enlarge by exactly eight percent")
		check(screen.primary_start_art.get_global_rect().get_center().distance_to(Vector2(1283,1331)*factor)<0.1,"button center shifts left three design pixels")
		var cards: VBoxContainer = screen.assistance_view
		for index in 3:
			var divider: float = screen.layout_reference.assistance.divider_ys[index]
			var upper: float = (cards.names[index].global_position.y-screen.stage.global_position.y)/factor+cards._ink_bounds(cards.names[index].text,28).y
			var lower: float = (cards.descriptions[index].global_position.y-screen.stage.global_position.y)/factor+cards._ink_bounds(cards.descriptions[index].text,22).x-float(screen.layout_reference.assistance.description_baseline_correction)
			check(absf(divider-upper-10)<0.1 and absf(lower-divider-10)<0.1,"all assistance ink gaps equal ten design pixels")
		board_matches(map,"scaled preview")
		if DisplayServer.get_name()!="headless": await capture("ready-items-%d" % resolution.x)
	map.breakthrough_session.start()
	check(not screen.primary_start_art.visible and screen.primary_running_art.visible,"begin hides start and shows running")
	map.breakthrough_session.set_paused(true)
	check(not screen.primary_start_art.visible and screen.primary_running_art.visible,"pause retains running picture only")
	screen.change_requested.emit()
	check(map.is_inventory_open() and not map.is_breakthrough_open(),"paused adjustment opens actual bag")
	var moved: Dictionary = map.loadout.inventory.get_instance(first)
	var available: Array = map.loadout.inventory.available_cells(moved.item_id)
	check(not available.is_empty() and map.loadout.place(map.loadout.drag_data("board",first),available[0]),"bag adjustment moves a real item")
	check(map.loadout.take_back(map.loadout.drag_data("board",second)),"bag adjustment removes a real item")
	map.set_inventory_open(false)
	await settle()
	check(map.is_breakthrough_open() and map.breakthrough_session.phase=="paused","return keeps breakthrough paused")
	board_matches(map,"returned adjustment")
	check(not screen.board_view._items.has(second),"removed item is not left on the preview")
	var xiaolan: Dictionary = map.loadout.snapshot()
	check(map.loadout.select_board("base.map_item.qinglan_board_6").is_empty(),"fixture selects a different actual board")
	await settle()
	board_matches(map,"changed actual board")
	check(screen.board_reference.get_meta("provisional_layout") and screen.board_layout_for("base.board.qinglan_6").is_empty(),"unconfirmed position is fitted provisionally without inventing a saved profile")
	check(map.loadout.restore(xiaolan).is_empty(),"fixture restores saved construction")
	await settle()
	board_matches(map,"snapshot restored")
	root.size = Vector2i(2560,1440)
	map.breakthrough_session.set_paused(false)
	await settle()
	check(not screen.primary_start_art.visible and screen.primary_running_art.visible,"resume retains mutual exclusion")
	if DisplayServer.get_name()!="headless": await capture("running-items-2560")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("BREAKTHROUGH_LAYOUT_SYNC: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
