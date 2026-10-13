extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560, 1440)
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	assert(model.bag_capacity == 25 and model.storage_capacity_limit() == 99)
	var count := model.storage_used_slots()
	assert(count > 99)
	var original := model.snapshot()
	var extra := original.duplicate(true)
	var existing: String = model.storage.entries()[0].item_id
	for i in 20: extra.owned_units["capacity.test.%d" % i] = existing
	assert(model.restore(extra).is_empty())
	assert(model.storage_used_slots() == count)
	assert(model.restore(original).is_empty())
	assert(model.set_bag_capacity(150).is_empty())
	var candidate := MapLoadoutStore.candidate(model)
	assert(candidate.error.is_empty() and candidate.state.bag_capacity == 150)
	model.storage_capacity_rules.test_capacity_override = 0
	assert(model.storage_capacity_limit() == 150)
	var legacy := original.duplicate(true)
	legacy.erase("bag_capacity")
	assert(model.restore(legacy).is_empty() and model.storage_capacity_limit() == 25)
	var invalid := model.snapshot()
	invalid.bag_capacity = -1
	assert(not model.restore(invalid).is_empty() and model.bag_capacity == 25)
	model.storage_capacity_rules.test_capacity_override = 99
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	assert(catalog.replace_entries(model.storage_records()).is_empty())
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	assert(ui.find_child("ItemSearch", true, false) == null)
	assert(ui.storage_capacity.text == "%d/99" % count)
	assert(is_equal_approx(ui.storage_capacity.size.y,ui.board_capacity.size.y))
	var title: Control = ui.storage_panel.find_child("StorageTitleArtwork", true, false)
	assert(is_equal_approx(title.get_global_rect().get_center().y, ui.storage_capacity.get_global_rect().get_center().y))
	assert(ui.storage_panel.get_global_rect().end.x - ui.storage_capacity.get_global_rect().end.x >= 16)
	catalog.set_filter("collection", "material")
	assert(ui.storage_capacity.text == "%d/99" % count)
	catalog.reset_filters()
	# Direct state commands only; no mouse, drag simulation or real save.
	for entry: Dictionary in model.storage.entries():
		var item := registry.get_item(entry.item_id)
		if item.category != "weapon" or item.grid_size != Vector2i.ONE or entry.units.size() != 1: continue
		assert(model.place(model.drag_data("storage", entry.instance_id), Vector2i.ZERO))
		assert(model.storage_used_slots() == count - 1)
		assert(ui.storage_capacity.text == "%d/99" % (count - 1))
		break
	assert(model.restore(original).is_empty())
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/storage-capacity.png")
		root.get_texture().get_image().get_region(Rect2i(ui.storage_heading.global_position - Vector2(0, 16), Vector2(ui.storage_heading.get_global_rect().size.x, 85))).save_png("res://artifacts/storage-capacity-heading.png")
	ui.queue_free()
	await settle()
	# Battle panel reads the same durable storage state and uses the same artwork.
	var manager := GameManager.new()
	manager._durable_loadout = model
	var battle := BattleStoragePanel.new()
	battle.configure_battle(manager)
	root.add_child(battle)
	assert(battle.storage_capacity.text == "%d/99" % count)
	assert(battle.find_child("CloseBattleStorage", true, false) != null)
	battle.queue_free()
	manager.free()
	await settle()
	print("STORAGE CAPACITY: unique kinds, overflow retained, 99 override/25 default, upgrade snapshot, invalid save, filter independence, live equipment refresh, shared battle header passed; no mouse/real save")
	quit()
