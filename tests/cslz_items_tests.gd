extends SceneTree

const ENEMY := "base.enemy.chisong_liaozhu"
const EVENT := "base.map_event.qingshihewan.cliff_encounter"
const SAVE := "res://artifacts/cslz-items-test.json"
var registry := ContentRegistry.new()
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

func fixture() -> BattleSimulation:
	var player := PartyMemberState.new(registry.get_character("base.character.chen_yu"), registry)
	player.definition.max_hp = 10000
	player.hp = 10000
	var enemy := PartyMemberState.new(registry.get_enemy(ENEMY), registry)
	enemy.equip_definition_loadout()
	var sim := BattleSimulation.new([player], [enemy], registry)
	for index in 200: sim.t01.forced_rolls.append(0.5)
	return sim

func organ(sim: BattleSimulation, suffix: String) -> String:
	for id: String in sim._definitions:
		if sim._definitions[id].id == "base.organ.cslz_" + suffix: return id
	return ""

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	check(registry.load_base_content(), "registry validates organs and footprint: " + str(registry.errors))
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "material catalog validates: " + created.error)
	if not created.error.is_empty() or not registry.errors.is_empty(): quit(1); return
	var loadout: MapLoadoutState = created.state
	check(loadout.storage_records().size() == 115 and loadout.records.size() == 120, "new materials are not granted for free")
	var sim := fixture()
	var enemy: PartyMemberState = sim.state.teams[1][0]
	check(enemy.inventory.get_instances().size() == 5 and enemy.inventory.occupied_cells() == 9, "five organs fill nine cells")
	check(enemy.maximum("armor") == 6 and enemy.armor_type == "轻甲", "hide supplies six armor without double counting")
	check(sim.start() and enemy.armor == 0, "starts with zero armor")
	sim.drain_events()
	sim.advance(6)
	check(enemy.armor == 2 and enemy.stamina == 87, "six seconds: hide restores two, hoof twice and tusk once cost eleven")
	var events := sim.drain_events()
	var damage: Array = events.filter(func(e: Dictionary): return e.kind == "damage")
	check(damage.size() == 3 and is_equal_approx(sim.state.teams[0][0].hp, 9987), "three attacks deal 3+7+3 against unarmored target")
	sim.advance(4)
	check(is_equal_approx(sim.state.teams[0][0].hp, 9974), "t9 hoof3 and t10 primed tusk10")
	check(enemy.pending_item_attacks.is_empty(), "enhancement consumed once")
	check(enemy.stamina == 77, "mane2 hoof3 tusk5 exact costs")
	sim.t01.activate(organ(sim,"mane"), sim.state.time_usec)
	sim.t01.activate(organ(sim,"mane"), sim.state.time_usec)
	check(enemy.pending_item_attacks.get("base.organ.cslz_tusk") == 3, "two primes retain one +3, never +6")
	enemy.stamina = 0
	sim.advance(5)
	check(enemy.pending_item_attacks.get("base.organ.cslz_tusk") == 3 and sim.timeline.remaining(organ(sim,"tusk")) == 5000000, "unaffordable tusk wastes cycle without consuming prime")
	var heart_sim := fixture()
	var heart_owner: PartyMemberState = heart_sim.state.teams[1][0]
	for id: String in heart_sim.timeline.timers:
		if id != organ(heart_sim,"heart"): heart_sim.timeline.set_mode(id,false)
	heart_sim.start()
	check(not heart_sim.timeline.timers[organ(heart_sim,"heart")].threshold_active, "heart sleeps above threshold")
	heart_owner.stamina = 60
	heart_sim.timeline.wake(0)
	heart_sim.advance(1.999)
	check(heart_owner.stamina == 60, "heart waits full two seconds")
	heart_sim.advance(.001)
	check(heart_owner.stamina == 62, "heart restores two without cost")
	heart_sim.advance(4)
	check(heart_owner.stamina == 66 and not heart_sim.timeline.timers[organ(heart_sim,"heart")].threshold_active, "heart stops after crossing two-thirds")
	heart_owner.stamina = 60
	heart_sim.timeline.wake(heart_sim.state.time_usec)
	check(heart_sim.timeline.remaining(organ(heart_sim,"heart")) == 2000000, "heart restarts full delay on re-entry")
	var defs := registry.get_enemy(ENEMY)
	var first := BattleLoot.candidate(loadout,defs,"first",[.99,.99,.99,.99,.99])
	check(first.error.is_empty() and first.drops == ["base.material.cslz_heart"], "first victory guarantees only heart when all random rolls miss")
	check(loadout.restore(first.snapshot).is_empty(), "reward and receipt restore")
	check(MapLoadoutStore.save(loadout,SAVE).is_empty(), "reward persisted to isolated save")
	var reload_registry := ContentRegistry.new()
	check(reload_registry.load_base_content(), "reload registry")
	var second_state: MapLoadoutState = MapLoadoutStore.create_state(reload_registry, reload_registry.get_board("base.board.bag")).state
	check(MapLoadoutStore.load_into(second_state,SAVE).is_empty(), "saved first victory reloads")
	var material_entry: Dictionary = second_state.storage.entries().filter(func(e: Dictionary): return e.item_id == "base.material.cslz_heart")[0]
	var material_drag := second_state.drag_data("storage",material_entry.instance_id)
	var owned_before := second_state.snapshot()
	check(not second_state.can_place(material_drag,Vector2i.ZERO) and not second_state.place(material_drag,Vector2i.ZERO), "material map placement rejected before transfer")
	check(second_state.snapshot() == owned_before, "rejected material placement preserves inventory")
	var duplicate := BattleLoot.candidate(second_state,defs,"first",[0,0,0,0,0])
	check(duplicate.snapshot == second_state.snapshot(), "same battle cannot reroll or grant twice")
	var none := BattleLoot.candidate(second_state,defs,"second",[.25,.25,.25,.25,.10])
	check(none.drops.is_empty(), "later battle can drop nothing, probability boundaries excluded")
	var all := BattleLoot.candidate(second_state,defs,"third",[.249,.249,.249,.249,.099])
	check(all.drops.size() == 5, "four independent25% rolls plus independent10% heart")
	for mask in 16:
		var rolls: Array = []
		var count := 0
		for bit in 4:
			var hit := (mask & (1 << bit)) != 0
			rolls.append(.1 if hit else .9)
			if hit: count += 1
		rolls.append(.9)
		check(BattleLoot.candidate(second_state,defs,"mask%d"%mask,rolls).drops.size() == count, "independent combination %d"%mask)
	for key: String in ["hide","tusk","hoof","mane","heart"]:
		var item := registry.get_item("base.organ.cslz_"+key)
		check(not ItemTooltip.effect_text(item).contains("暂无"), "organ has effects " + key)
		check((load(item.icon_path) as Texture2D).get_image().has_mipmaps(), "organ mipmaps " + key)
		check(not second_state.inventory.add_item("illegal", "base.material.cslz_"+key, Vector2i.ZERO), "material cannot enter board " + key)
		check(ItemTooltip.effect_text(registry.get_item("base.material.cslz_"+key)).contains("仅作材料"), "material explanation " + key)
	await live_entry()
	print("CSLZ ITEMS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)

func live_entry() -> void:
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var manager: GameManager = scene.get_node("GameManager")
	manager.loadout_save_path = ""
	manager.enemy_id = ENEMY
	root.add_child(scene)
	manager.set_process(false)
	await settle()
	check(manager.startup_error.is_empty() and manager.enemies[0].inventory.get_instances().size() == 5, "real battle uses five organs, no old claw")
	var flow = load("res://scripts/map/map_battle_return.gd").new()
	flow.manager = manager
	flow.save_path = SAVE
	flow._loot_rolls = [.99,.99,.99,.99,.99]
	check(not flow._award_victory().is_empty(), "cannot award materials before victory")
	manager.simulation._finish("victory",0)
	check(flow._award_victory().is_empty(), "real reward settlement saves material")
	check(manager.loot_summary.contains("赤鬃兽心") and manager._durable_snapshot.battle_rewards.size() == 1, "reward summary and persisted receipt")
	var before: Dictionary = manager._durable_snapshot.duplicate(true)
	check(flow._award_victory().is_empty() and manager._durable_snapshot == before, "settlement retry is idempotent")
	flow._battle_id = "failed-save"
	flow.save_path = "res://artifacts/missing-cslz-directory/save.json"
	flow._loot_rolls = [0,0,0,0,0]
	check(not flow._award_victory().is_empty() and manager._durable_snapshot == before, "save failure cannot publish ownership or first-win receipt")
	flow.save_path = SAVE
	check(flow._award_victory().is_empty() and manager._durable_snapshot.owned_units.size() == before.owned_units.size()+5, "same cached rolls save on retry")
	check(manager.persist_consumption() and manager._durable_snapshot.battle_rewards.size() == 2, "consumption persistence preserves victory receipts")
	var content := MapEventRegistry.new()
	var raw_event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	check(content.configure([raw_event],[raw_event.point_id]).is_empty(), "encounter configured")
	flow.events = MapEventState.new(content,{})
	flow.event_id = EVENT
	var settled := manager._durable_snapshot.duplicate(true)
	for outcome in ["defeat","draw","retreat"]:
		manager.simulation._finish(outcome,0)
		flow._recorded = false
		flow._battle_id = "no-loot-" + outcome
		flow._record_result()
		check(manager._durable_snapshot == settled and not flow.events.completed.has(EVENT), "no loot or victory receipt on " + outcome)
	manager.restart()
	var sword: Dictionary = manager.storage.entries().filter(func(e: Dictionary): return e.item_id == "base.map_item.qingshi_short_sword")[0]
	check(manager.equip(sword.instance_id,0,Vector2i.ZERO), "real victory test sword equipped")
	flow._recorded = false
	flow._battle_id = "real-victory"
	flow._loot_rolls = [.99,.99,.99,.99,.99]
	root.add_child(flow)
	manager.start_battle()
	manager.enemies[0].hp = 1
	manager._process(6)
	check(manager.simulation.state.result == "victory" and flow.events.completed.has(EVENT) and manager._durable_snapshot.battle_rewards.has("real-victory"), "actual finished signal saves loot before encounter completion")
	var after_battle_registry := ContentRegistry.new()
	after_battle_registry.load_base_content()
	var after_battle: MapLoadoutState = MapLoadoutStore.create_state(after_battle_registry,after_battle_registry.get_board("base.board.bag")).state
	check(MapLoadoutStore.load_into(after_battle,SAVE).is_empty() and after_battle.battle_rewards.size() == 3, "actual map inventory reload preserves all victories")
	check(after_battle.storage_records().filter(func(r: Dictionary): return r.category == "beast").size() == 5, "all five materials display in storage after reload")
	# Reset only the isolated scene for a clear preparation screenshot.
	manager.restart()
	flow.free()
	var ui = scene.get_node("MainUI")
	ui._refresh()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/cslz-items-board.png")
	var dialog := MapEncounterDialog.new()
	root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	dialog.present(event,manager.enemies[0])
	await settle()
	var row = dialog.enemy_summary.get_child(3).get_child(1)
	check(row.get_child_count() == 2 and row.get_child(1).text == "高气血·蓄势爆发", "trait caption and value on same row")
	check(row.get_child(0).global_position.y == row.get_child(1).global_position.y, "trait is one line")
	check(row.get_child(1).get_global_rect().end.x <= dialog.canvas.global_position.x + 676*dialog.canvas.scale.x, "one-line traits fit inside frame")
	check(dialog.item_slots.filter(func(slot): return slot.item != null).size() == 5, "encounter displays five item images")
	var tooltip: ItemTooltip = dialog.item_slots[0]._make_custom_tooltip("")
	check(tooltip.description.contains("护甲"), "slot uses shared effect tooltip")
	tooltip.free()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/cslz-items-encounter.png")
	dialog.queue_free()
	scene.queue_free()
	await settle()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = SAVE
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "real map reloads rewarded inventory")
	check(map._encounter_enemies[EVENT].maximum("armor") == 6 and map._encounter_enemies[EVENT].inventory.get_instances().size() == 5, "map preview builds same five organs and armor")
	check(map.loadout.battle_rewards.size() == 3 and map.loadout.storage_records().filter(func(r: Dictionary): return r.category == "beast").size() == 5, "real map preserves receipts and material cards")
	map.queue_free()
	await settle()
