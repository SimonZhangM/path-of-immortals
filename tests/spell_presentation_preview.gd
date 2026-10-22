extends "res://tests/item_selection_tooltip_tests.gd"
const SpellGrant = preload("res://tools/grant_test_combat_spells.gd")
const BookGrant = preload("res://tools/grant_test_cultivation_books.gd")

# Static presentation only: no mouse input, battle progression, or save writes.
func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry: " + str(registry.errors))
	if not registry.errors.is_empty(): quit(1); return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	check(catalog.replace_entries(registry.library.inventory_records()).is_empty(), "91 cultivation entries")
	catalog.set_filter("collection", "cultivation")
	check(catalog.visible_entries().size()==91, "shared parent has 35 books and 56 spells")
	catalog.set_filter("category", "book")
	check(catalog.visible_entries().size()==35, "book subtype")
	catalog.set_filter("category", "spell")
	check(catalog.visible_entries().size()==56, "spell subtype")
	for element: String in catalog.book_elements:
		catalog.set_filter("category", element)
		check(catalog.visible_entries().size()==13, "element includes 5 books and 8 spells: "+element)
	for item: ItemData in registry.library.book_items.values():
		var tags := ItemTooltip.classification_tags(item)
		check(tags.size()==4 and tags[0]=="功法" and tags[1]=="书籍" and tags[2].ends_with("系"), "book tag order: "+item.id)
	for item: ItemData in registry.library.spell_items.values():
		var tags := ItemTooltip.classification_tags(item)
		check(tags.size()==4 and tags.slice(0,2)==["功法","法术"] and tags[2].ends_with("系") and tags[3].begins_with("占格"), "spell tag order: "+item.id)
		var description := ItemTooltip.effect_text(item)
		check(description.split("\n")[0]=="《%s》第%d重。" % [item.combat.presentation.book_name,item.combat.learned_at_book_level], "short source line: "+item.id)
		for removed in ["上阵生效", "原书第", "独立占", "CD完成进入待发", "支持手动／自动", "无需同时上阵原书"]:
			check(removed not in description, "removed redundant instruction: "+item.id)
		var art := MapItemArtwork.new()
		art.configure(MapItemArtwork.item_record(item))
		var footprint := Rect2(Vector2(20,30), Vector2(item.grid_size)*160)
		art.place_on_board(footprint)
		check(art.get_rect().is_equal_approx(footprint.grow(-3)), "frame covers placement area: "+item.id)
		check(art.material.get_shader_parameter("corner_radius_px")==3.0 and art.stretch_mode==TextureRect.STRETCH_SCALE, "rounded full footprint: "+item.id)
		art.free()
	var made := MapLoadoutStore.create_state(registry, registry.get_board("base.board.qinglan_1"))
	check(made.error.is_empty(), "preview state")
	var state: MapLoadoutState = made.state
	check(state.restore(state.snapshot()).is_empty(), "normalize preview")
	check(state.restore(BookGrant.prepare(state).snapshot).is_empty(), "preview books")
	check(state.restore(SpellGrant.prepare(state).snapshot).is_empty(), "preview spells")
	var placements := {"base.spell.metal_01":Vector2i(0,0), "base.spell.water_01":Vector2i(1,0), "base.spell.fire_04":Vector2i(3,0), "base.spell.wind_06":Vector2i(0,1), "base.spell.wind_08":Vector2i(0,2)}
	for id: String in placements:
		var row: Dictionary = state.storage_records().filter(func(r): return r.id==id)[0]
		check(state.place(state.drag_data("storage",row.storage_id),placements[id]), "preview placement "+id)
	check(catalog.replace_entries(state.storage_records()).is_empty(), "preview catalog")
	var screen := MapInventoryScreen.new()
	screen.configure(catalog,config,state.board,state)
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.show()
	catalog.set_filter("collection","cultivation")
	catalog.set_filter("category","wind")
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle(12)
		for entry: Dictionary in state.inventory.get_instances():
			var art: MapItemArtwork = screen.loadout_board._items[entry.instance_id]
			var footprint := state.board.footprint_rect(entry.cell,registry.get_item(entry.item_id).grid_size,screen.loadout_board.size)
			check(art.get_rect().is_equal_approx(footprint.grow(-3)), "live board fits at "+str(resolution))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/spell-presentation-%d.png" % resolution.x)
	screen.hide()
	for id: String in ["base.spell.wind_06","base.spell.metal_01","base.cultivation_book.wood_02"]:
		var item := registry.get_item(id)
		var tip := ItemTooltip.new()
		tip.configure(item,CultivationDescription.tooltip_context(state.knowledge,id,item))
		root.add_child(tip)
		tip.position = Vector2(920,120)
		await settle(8)
		tip.reset_size()
		await settle(4)
		check(root.get_visible_rect().encloses(tip.get_global_rect()), "tooltip fits "+id)
		if id=="base.spell.metal_01":
			check(state.knowledge.record_achievement(registry.library,item.combat.book_id,1,5), "preview first rank")
			check(state.knowledge.record_achievement(registry.library,item.combat.book_id,2,5), "preview upgrade rank")
			check(state.knowledge.choose(registry.library,item.combat.book_id,2,"剑锋"), "preview upgrade choice")
			check("造成15点法术伤害" in tip.description, "natural wording still reflects live upgrade")
			await settle(8)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(tip.get_global_rect())).save_png("res://artifacts/spell-presentation-tooltip-%s.png" % id.get_slice(".",2))
		tip.queue_free()
		await settle()
	screen.queue_free()
	await settle()
	print("SPELL PRESENTATION: %d checks, %d failures; static render only, no save IO" % [checks,failures])
	quit(1 if failures else 0)
