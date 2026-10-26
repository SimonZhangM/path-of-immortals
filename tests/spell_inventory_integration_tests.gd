extends "res://tests/item_selection_tooltip_tests.gd"
const Grant = preload("res://tools/grant_test_combat_spells.gd")
const SAVE := "res://artifacts/spell-inventory-test.json"
const Transfer = preload("res://scripts/map/map_warehouse_transfer.gd")

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry with spell art: " + str(registry.errors))
	if not registry.errors.is_empty(): quit(1); return
	var made := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(made.error.is_empty(), "catalog accepts all registered spells")
	if not made.error.is_empty(): quit(1); return
	var state: MapLoadoutState = made.state
	check(state.restore(state.snapshot()).is_empty(), "normalize fixture")
	check(not state.can_use_item("base.spell.metal_01"), "normal unlearned save has no spell bypass")
	var knowledge_before := state.knowledge.snapshot()
	var before := state.snapshot()
	var occupied_before := state.storage_used_slots()
	state.storage_capacity_rules.test_capacity_override = occupied_before
	var grant := Grant.prepare(state)
	check(grant.added==56 and grant.error.is_empty(), "explicit test grant 56")
	check(state.restore(grant.snapshot, true).is_empty(), "grant spells into a full bag")
	check(state.storage_used_slots()==occupied_before and not state.storage_over_capacity(), "56 spells consume no bag capacity and do not disable running")
	check(Grant.prepare(state).snapshot==state.snapshot(), "grant idempotent")
	check(state.knowledge.snapshot()==knowledge_before, "test access never learns or picks branches")
	for field in before:
		if field not in ["owned_units","content_grants"]: check(before[field]==state.snapshot()[field], "grant preserves "+field)
	var physical := SharedStorage.new()
	physical.put(state._unit("physical.book", "base.cultivation_book.metal_04"))
	var with_spell := MapLoadoutState.projected_storage(physical, [state._unit("free.spell", "base.spell.metal_01")])
	check(MapLoadoutState.bag_used_slots(with_spell, registry)==1, "book counts, spell does not")
	check(MapLoadoutState.capacity_error(physical, with_spell, 1, registry).is_empty(), "full bag accepts spell")
	var with_sword := MapLoadoutState.projected_storage(with_spell, [state._unit("physical.sword", "base.map_item.qingshi_short_sword")])
	check(not MapLoadoutState.capacity_error(with_spell, with_sword, 1, registry).is_empty(), "spell exemption does not permit extra physical item")
	var home := "base.warehouse.qingshizhen.home"
	check(Transfer.execute(state, home, "base.spell.metal_01", false, "").is_empty(), "store spell without changing bag slots")
	var transfer_preview := Transfer.preview(state, home, "base.spell.metal_01", true)
	check(not transfer_preview.blocked and transfer_preview.projected==occupied_before, "withdraw preview exempts spell at capacity")
	check(Transfer.execute(state, home, "base.spell.metal_01", true, "").is_empty(), "withdraw spell into full bag")
	check(state.storage_used_slots()==occupied_before, "spell transfer preserves bag occupancy")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	check(catalog.replace_entries(state.storage_records()).is_empty(), "inventory validates framed spell records")
	catalog.set_filter("collection","cultivation")
	catalog.set_filter("category","spell")
	check(catalog.visible_entries().size()==56, "spell category contains 56")
	check(config.collections.cultivation=="功法" and config.category_groups.cultivation==["book","spell"], "shared cultivation parent")
	for element: String in catalog.book_elements:
		catalog.set_filter("category",element)
		check(catalog.visible_entries().size()==8, element+" filter 8")
	for item: ItemData in registry.library.book_items.values(): check("书籍" in ItemTooltip.classification_tags(item), "book tag "+item.id)
	var gallery := Control.new()
	root.add_child(gallery)
	var index := 0
	for item: ItemData in registry.library.spell_items.values():
		check(state.can_use_item(item.id), "test spell available "+item.id)
		check("法术" in ItemTooltip.classification_tags(item), "spell tag")
		var p: Dictionary = item.combat.presentation
		check(p.icon.ends_with(".webp") and p.frame.ends_with(".webp"), "webp")
		check(load(p.icon).get_image().has_mipmaps() and load(p.frame).get_image().has_mipmaps(), "mipmaps")
		check(item.quality=={1:"凡品",3:"良品",5:"上品",7:"灵品"}[int(item.combat.learned_at_book_level)], "spell tier background")
		check(("-board-" in item.icon_path)==(int(item.combat.learned_at_book_level)==7), "rank 7 uses new rectangular art")
		var art := MapItemArtwork.new()
		art.configure(MapItemArtwork.item_record(item))
		art.position=Vector2(30+(index%8)*312,35+(index/8)*190)
		art.size=Vector2(260,145)
		gallery.add_child(art)
		check(art.material is ShaderMaterial, "layered frame shader")
		var caption := Label.new()
		caption.text=item.display_name
		caption.position=art.position+Vector2(0,145)
		gallery.add_child(caption)
		index+=1
	await settle(8)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/spell-inventory-gallery.png")
	gallery.queue_free(); await settle()
	var screen := MapInventoryScreen.new()
	screen.configure(catalog,config,state.board,state)
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.show()
	catalog.set_filter("collection","cultivation")
	catalog.set_filter("category","metal")
	await settle(12)
	check(catalog.visible_entries().size()==8, "actual inventory screen spell filter")
	check(screen.storage_capacity.occupied==occupied_before, "filtered spell tab shows capacity excluding spells")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/spell-inventory-metal.png")
	screen.hide(); await settle()
	var item := registry.get_item("base.spell.metal_01")
	var tip := ItemTooltip.new()
	tip.configure(item,CultivationDescription.tooltip_context(state.knowledge,item.id,item))
	root.add_child(tip)
	check("造成12点法术伤害" in tip.description, "base tooltip damage")
	check(state.knowledge.record_achievement(registry.library,item.combat.book_id,1,5), "fixture rank 1")
	check(state.knowledge.record_achievement(registry.library,item.combat.book_id,2,5), "fixture rank 2")
	check(state.knowledge.choose(registry.library,item.combat.book_id,2,"剑锋"), "fixture branch")
	check("造成15点法术伤害" in tip.description and "已选强化【剑锋】" in tip.description, "open tooltip updates immediately")
	check(item.combat.damage==12 and not item.combat.has("damage_pct"), "canonical definition not mutated")
	await settle(5)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/spell-tooltip-upgraded.png")
	tip.queue_free(); await settle()
	check(state.knowledge.restore(knowledge_before,registry.library,5), "restore fixture knowledge")
	for id: String in ["base.spell.metal_01","base.spell.metal_04","base.spell.metal_08"]:
		var record: Dictionary = state.storage_records().filter(func(r): return r.id==id)[0]
		check(state.equip_random(record.storage_id), "map deploy "+id)
		var inst: Dictionary = state.inventory.get_instances().filter(func(e): return e.item_id==id)[0]
		var copy: MapLoadoutState = MapLoadoutStore.candidate(state).state
		var restore_error := copy.restore(state.snapshot())
		check(restore_error.is_empty(), "restore test spell board: " + restore_error)
		check(copy.inventory.get_instances().any(func(e): return e.item_id==id), "test spell survives reload")
		check(state.take_back(state.drag_data("board",inst.instance_id)), "map return "+id)
		check(state.storage_used_slots()==occupied_before, "spell equip/return preserves full-bag occupancy")
	check(MapLoadoutStore.save(state,SAVE).is_empty(), "isolated save")
	var manager := GameManager.new()
	manager.use_saved_loadout=true; manager.loadout_save_path=SAVE
	root.add_child(manager); manager.set_process(false)
	check(manager.startup_error.is_empty(), "actual game entry")
	check(manager.party[0].test_spell_access and manager.party[0].knowledge.learned.is_empty(), "battle test access without learning")
	manager._durable_loadout.storage_capacity_rules.test_capacity_override = manager._durable_loadout.storage_used_slots()
	var entry: Dictionary = manager.storage.entries().filter(func(e): return e.item_id=="base.spell.metal_01")[0]
	check(manager.equip_random(entry.instance_id), "battle deploy")
	var inst: Dictionary = manager.party[0].inventory.get_instances().filter(func(e): return e.item_id=="base.spell.metal_01")[0]
	check(manager.unequip(0,inst.instance_id), "battle return")
	check(manager.storage.entries().filter(func(e): return e.item_id=="base.spell.metal_01").size()==1, "returned spell retained exactly once")
	check(manager._durable_loadout.storage_used_slots()==occupied_before, "battle return exempts spell at capacity")
	check(manager.equip_random(entry.instance_id), "test spell redeploy for simulation")
	manager.start_battle()
	check(manager.simulation.state.phase==GameState.Phase.BATTLE, "test access supports actual battle start")
	manager.simulation.advance(5.0)
	check(manager.party[0].spirit < manager.party[0].maximum("spirit"), "test spell actually casts and spends spirit")
	manager.queue_free(); await settle()
	screen.queue_free(); await settle()
	print("Spell inventory: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
