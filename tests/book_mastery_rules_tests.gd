extends "res://tests/item_selection_tooltip_tests.gd"

const Grant = preload("res://tools/grant_test_cultivation_books.gd")
const HOME := "base.warehouse.qingshizhen.home"
const PATH := "res://artifacts/book-mastery-test-save.json"

func run() -> void:
	for suffix in [".cultivation.json", ".cultivation.json.bak"]:
		if FileAccess.file_exists(PATH+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH+suffix))
	create_timer(45).timeout.connect(func(): quit(2))
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry")
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "loadout")
	var state: MapLoadoutState = created.state
	state.cultivation_rank_id = "base.cultivation.spirit_transformation"
	check(state.restore(Grant.prepare(state).snapshot).is_empty(), "isolated 35-book fixture")
	var five := ["", "下品", "凡品", "上品", "灵品", "玄品"]
	var eight := ["", "下品", "下品", "凡品", "凡品", "上品", "上品", "灵品", "灵品"]
	var examples: Array[Dictionary] = []
	for id: String in registry.library.books:
		var book: Dictionary = registry.library.books[id]
		var item := registry.get_item(id)
		check(state.knowledge.level(id) == 0 and state.knowledge.practice_value(id) == 0, "all books begin at zero")
		check(not state.inventory.add_item("forbidden." + id, id, Vector2i.ZERO), "no original book may deploy")
		check(not state.inventory.add_item("rotated." + id, id, Vector2i.ZERO, true), "rotating cannot bypass prohibition")
		check(state.inventory.available_cells(id).is_empty(), "no book drop hints")
		var knowledge := CultivationKnowledge.new()
		check(knowledge.acquire(registry.library, id) and knowledge.learned_spells(registry.library).is_empty(), "ownership is not learning")
		for stage in range(int(book.max_level) + 1):
			if stage > 0: check(knowledge.record_achievement(registry.library, id, stage, 5), "sequential stage award")
			var expected: String = (eight if book.max_level == 8 else five)[stage]
			check(MapItemQuality.book_background_quality(book.max_level, stage) == expected, "authored mastery mapping")
			state.knowledge = knowledge
			var row: Dictionary = state.storage_records().filter(func(record): return record.id == id)[0]
			check(row.book_level == stage and row.quality.is_empty(), "mastery distinct from trade rarity")
			check(row.card_frame == ("" if expected.is_empty() else MapItemQuality.background_path(expected)), "unselected branch stage already changes card")
			if book.max_level == 8:
				check(knowledge.learned_spells(registry.library).size() == ceili(stage / 2.0), "odd stages automatically unlock spells; even stages add none")
			if id in ["base.cultivation_book.wood_02", "base.cultivation_book.wood_04"]: examples.append(row)
		check(item.category == "book", "registered identity unchanged")
	state.knowledge = CultivationKnowledge.new()
	var id := "base.cultivation_book.wood_04"
	var row: Dictionary = state.storage_records().filter(func(record): return record.id == id)[0]
	var before := state.snapshot()
	check(not state.equip_random(row.storage_id), "map right-click command cannot equip book")
	check(state.snapshot() == before, "failed deploy preserves all units")
	var legacy := before.duplicate(true)
	legacy.placements.append({"instance_id": row.storage_id, "item_id": id, "cell": [0, 0], "unit_ids": [row.storage_id]})
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(MapLoadoutStore.load_into(state, PATH).is_empty(), "legacy original book safely returned")
	check(state.snapshot().owned_units == before.owned_units and state.inventory.get_instances().is_empty(), "legacy migration conserves physical ownership")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(disk.placements.is_empty(), "legacy book removal saved once")
	check(state._validate_formation_layout({"placements": legacy.placements}).layout.placements.is_empty(), "saved formations also remove books")
	var site: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cultivation_n32.json"))
	check(not state.knowledge.add_site_practice(registry.library, id, 10, {"type":"battle", "id":site.id}), "battle cannot award book practice")
	check(state.knowledge.add_site_practice(registry.library, id, 10, site), "explicit site award interface")
	check(state.knowledge.practice_value(id) == 10 and state.knowledge.level(id) == 0, "no invented automatic upgrade threshold")
	check(not state.knowledge.add_site_practice(registry.library, id, INF, site), "invalid progress rejected")
	check(CultivationStore.save(state.knowledge, PATH + ".cultivation.json").is_empty(), "progress saved separately")
	var copy: MapLoadoutState = MapLoadoutStore.candidate(state).state
	copy.knowledge = CultivationKnowledge.new()
	copy.cultivation_rank_id = state.cultivation_rank_id
	check(MapLoadoutStore.load_into(copy, PATH).is_empty() and copy.knowledge.snapshot() == state.knowledge.snapshot(), "map and battle load same persistent knowledge")
	check(MapLoadoutStore.candidate(state).state.knowledge.snapshot() == state.knowledge.snapshot(), "transaction preserves knowledge")
	check(state.transfer_warehouse(HOME, id, false).is_empty(), "book still transfers to warehouse")
	check(state.warehouse_records(HOME)[0].card_frame.is_empty(), "warehouse zero book has no background")
	check(state.transfer_warehouse(HOME, id, true).is_empty(), "warehouse withdrawal unaffected")
	var session := MapCultivationSession.new()
	check(session.begin(site, "technique", 5, 0), "training session")
	var rows: Array[Dictionary] = []
	for record: Dictionary in state.storage_records():
		if record.category == "book": rows.append(record)
	session.set_available_techniques(rows)
	check(session.choose_technique(id), "training site offers carried books")
	check(session.technique_progress().target==600 and session.technique_progress().current==10, "formal first-stage target with retained practice")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	check(catalog.replace_entries(state.storage_records()).is_empty(), "display records validate")
	check("material" in catalog.subcategories() and not catalog.subcategories().any(func(key): return key in ["plant","beast","mineral","exotic"]), "four material buttons replaced by one")
	catalog.set_filter("category", "material")
	check(catalog.visible_entries().size() == catalog.collection_count("material"), "aggregate includes all material subtypes")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, state.board, state)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog.set_filter("collection", "cultivation")
	catalog.set_filter("category", "book")
	ui.show()
	await settle(12)
	var card: MapInventoryItemCard = ui.grid.get_child(0)
	check(card.frame == null and card.canvas.get_node_or_null("BookMastery") == null, "zero card has no rarity image or mastery text")
	if DisplayServer.get_name() == "headless":
		var point := card.get_global_rect().get_center()
		await click(point, MOUSE_BUTTON_RIGHT)
		check(state.inventory.get_instances().is_empty(), "actual right click cannot deploy book")
		button(point, MOUSE_BUTTON_LEFT, true)
		motion(point + Vector2(20,0), true)
		await settle()
		check(not root.gui_is_dragging(), "actual held movement does not start equipment drag")
		button(point, MOUSE_BUTTON_LEFT, false)
		card.configure_transfer(func(_id): return {"kind":"warehouse_transfer"}, func(_id): pass)
		check(card._storage_drag_data().get("kind") == "warehouse_transfer", "warehouse drag route remains available")
		var battle_card := BattleInventoryItemCard.new()
		battle_card.configure(row, "功法", true)
		check(battle_card.drag_data().is_empty(), "battle bag cannot start book drag")
		battle_card.free()
	ui.queue_free()
	await settle()
	if DisplayServer.get_name() != "headless": await render_examples(examples)
	# Test artifacts are deliberately isolated; remove sidecar to keep repeat runs independent.
	for suffix in [".cultivation.json", ".cultivation.json.bak"]:
		if FileAccess.file_exists(PATH + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	print("BOOK MASTERY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func render_examples(examples: Array[Dictionary]) -> void:
	var panel := ColorRect.new()
	panel.color = Color("12202a")
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var five_index := 0
	var eight_index := 0
	for record: Dictionary in examples:
		var is_eight: bool = record.id.ends_with("_04")
		var card := MapInventoryItemCard.new()
		card.configure(record, "功法", true)
		panel.add_child(card)
		card.position = Vector2(30 + (eight_index if is_eight else five_index) * 205, 520 if is_eight else 120)
		if is_eight: eight_index += 1
		else: five_index += 1
	await settle(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/book-mastery-stage-backgrounds.png")
	panel.queue_free()
	await settle()
