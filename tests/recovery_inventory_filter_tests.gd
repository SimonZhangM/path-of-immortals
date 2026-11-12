extends "res://tests/save_actions_tests.gd"

const RECOVERY_IDS := [
	"base.map_item.warm_jade", "base.map_item.t01_0019", "base.map_item.t01_0020",
	"base.map_item.t01_0021", "base.map_item.t01_0083", "base.map_item.t01_0084",
	"base.map_item.t01_0085", "base.map_item.t01_0086", "base.map_item.t01_0088"
]

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	directory = "res://artifacts/recovery-filter-20261105/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory + "auto.json"
	Session.index_path = directory + "session.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560, 1440)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/inventory_items.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	check(catalog.replace_entries(records).is_empty(), "current catalog validates")
	var equipment_count := catalog.collection_count("equipment")
	catalog.set_filter("collection", "equipment")
	check(catalog.subcategories() == ["weapon","armor","artifact","board","talisman","recovery"], "recovery tab follows existing equipment filters")
	catalog.set_filter("category", "recovery")
	var found: Array = catalog.visible_entries().map(func(record): return record.id)
	found.sort()
	var expected := RECOVERY_IDS.duplicate()
	expected.sort()
	check(found == expected, "recovery filter matches exactly nine artifacts")
	check(catalog.visible_entries().all(func(record): return record.category == "artifact"), "armor cannot enter recovery filter")
	check(catalog.collection_count("equipment") == equipment_count, "additional filter does not double count items")
	catalog.set_filter("quality", "下品")
	check(catalog.visible_entries().size() == 4, "quality intersects recovery")
	catalog.set_filter("search", "聚灵珠")
	check(catalog.visible_entries().size() == 1, "search intersects recovery")
	var invalid := records.duplicate(true)
	for record: Dictionary in invalid:
		if record.category == "armor":
			record.recovery = true
			break
	check(not catalog.replace_entries(invalid).is_empty(), "armor recovery classification rejected atomically")
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(), "isolated map startup")
	if not map.startup_error.is_empty(): quit(1); return
	map.set_inventory_open(true)
	await settle()
	var state: MapLoadoutState = map.loadout
	var saved := state.snapshot()
	check(state.restore(saved).is_empty(), "existing save shape reloads with current classifications")
	for id: String in RECOVERY_IDS:
		check(ItemTooltip.classification_tags(state.registry.get_item(id)).count("恢复") == 1, "shared tooltip exposes one recovery tag for " + id)
	var ui: MapInventoryScreen = map.inventory_screen
	await click(ui._collections.equipment)
	check(ui._categories.recovery.visible, "normal equipment entry exposes recovery tab")
	check(ui.catalog.replace_entries(records).is_empty(), "all catalog fixture for classification preview")
	await click(ui._categories.recovery)
	await settle()
	check(ui.catalog.category == "recovery" and ui.grid.get_child_count() == 9, "real category click displays nine recovery cards")
	var all_tooltips_tagged := true
	for card: MapInventoryItemCard in ui.grid.get_children():
		var tooltip := card.build_item_tooltip("") as ItemTooltip
		var labels: Array = tooltip.find_child("CategoryTags", true, false).get_children()
		all_tooltips_tagged = all_tooltips_tagged and labels.any(func(label): return label.text == "恢复")
		tooltip.free()
	check(all_tooltips_tagged, "every filtered card tooltip displays recovery label")
	await click(ui._categories.recovery)
	check(ui.catalog.category == "all", "clicking selected recovery tab clears filter")
	await click(ui._categories.recovery)
	for resolution in [Vector2i(2560,1440), Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		check(ui._categories.recovery.get_global_rect().end.x <= root.size.x, "recovery filter fits " + str(resolution))
		if DisplayServer.get_name() != "headless": await capture("recovery-%d" % resolution.x)
	ui.hide()
	var armor_ring := state.registry.get_item("base.map_item.t01_0095")
	check(not "恢复" in ItemTooltip.classification_tags(armor_ring), "armor ring has no recovery label")
	check(ItemTooltip.effect_text(armor_ring).contains("回复7点护甲。"), "armor ring uses 回复")
	var artifact_tip := ItemTooltip.new()
	artifact_tip.configure(state.registry.get_item("base.map_item.t01_0019"))
	artifact_tip.position = Vector2(50,170)
	root.add_child(artifact_tip)
	if DisplayServer.get_name() != "headless": await capture("recovery-tooltip")
	artifact_tip.queue_free()
	await settle()
	for id: String in ["base.map_item.coarse_cloth_armor", "base.map_item.t01_0011"]:
		var item := state.registry.get_item(id)
		check(not "恢复" in ItemTooltip.classification_tags(item), "armor has no recovery tag")
		check(item.combat.equipment_note.contains("冷却完成，护甲回复+2。") if id.ends_with("t01_0011") else item.combat.equipment_note.contains("护甲回复+2，且额外恢复2点体力。"), "armor set wording uses 回复")
		var styled := ItemTooltip._colored(item.combat.equipment_note, ItemTooltip.highlighted_keywords())
		check(styled.count("player-status-armor.webp[/img]") == 2, "set note preserves two armor icons")
		var tip := ItemTooltip.new()
		tip.configure(item)
		tip.position = Vector2(50,170)
		root.add_child(tip)
		if DisplayServer.get_name() != "headless": await capture("set-" + id.get_slice(".", 2))
		tip.queue_free()
		await settle()
	map.queue_free()
	await settle()
	print("Recovery filter: ", checks, " checks, ", failures, " failures; artifacts ", directory)
	quit(1 if failures else 0)
