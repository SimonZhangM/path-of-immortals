class_name GameManager
extends Node

signal battle_restarted
signal battle_started
signal inventory_changed
signal adjustment_changed
signal selection_changed
signal feedback(message: String)
signal presentation_events(events: Array[Dictionary])
signal inventory_interaction(kind: String)
signal battle_review_requested
signal battle_exit_requested

const ITEM_ID := "base.test.fire_sword"
const ENEMY_ID := "base.enemy.wild_dog"
const CLAW_ID := "base.weapon.dog_claw"
const ARMOR_ID := "base.armor.iron_armor"
const SWORD_INSTANCE := "run.item.001"
const ARMOR_INSTANCE := "run.item.002"
const CLAW_INSTANCE := "run.enemy.0.claw"
const PARTY_IDS := ["base.character.chen_yu", "base.character.role_2", "base.character.role_3"]
const STORAGE_IDS := ["base.weapon.qingfeng", "base.weapon.chixiao", "base.armor.xuantie", "base.armor.qinglin", "base.pill.huichun", "base.pill.yunling", "base.pill.yiqi"]
var registry := ContentRegistry.new()
var party: Array[PartyMemberState] = []
var enemies: Array[PartyMemberState] = []
var companions: Array[CompanionState] = []
var enemy_companions: Array[CompanionState] = []
var simulation: BattleSimulation
var startup_error: String = ""
var storage := SharedStorage.new()
var adjustment_open: bool = false
var selected_member_index: int = 0
var interaction_epoch: int = 0
var _placement_rng := RandomNumberGenerator.new()
var _durable_loadout: MapLoadoutState
var _durable_snapshot: Dictionary = {}
@export var use_saved_loadout := false
@export var enemy_id := ENEMY_ID
@export var cultivation_preview := false
@export var preview_spell_id := "base.spell.metal_01"
@export var preview_branch := ""
var legacy_fixed_defense := false
@export var loadout_save_path := MapLoadoutStore.DEFAULT_PATH

func _ready() -> void:
	if not registry.load_base_content():
		startup_error = "\n".join(registry.errors)
	elif registry.get_item(ITEM_ID) == null or registry.get_item(ARMOR_ID) == null or registry.get_item(CLAW_ID) == null or registry.get_enemy(enemy_id).is_empty():
		startup_error = "缺少原型所需的装备或敌人配置。"
	for id in PARTY_IDS:
		if registry.get_character(id).is_empty():
			startup_error += "\n缺少角色配置：" + id
	for id in STORAGE_IDS:
		if registry.get_item(id) == null:
			startup_error += "\n缺少储物袋物品配置：" + id
	if not startup_error.is_empty():
		DebugLogger.error(startup_error)
		set_process(false)
		return
	for index in 1:
		var member := PartyMemberState.new(registry.get_character(PARTY_IDS[index]), registry)
		member.inventory.add_item(sword_instance(index), ITEM_ID, Vector2i.ZERO)
		member.inventory.add_item(armor_instance(index), ARMOR_ID, Vector2i(1, 1))
		party.append(member)
	for id in PARTY_IDS.slice(1):
		companions.append(CompanionState.new(registry.get_character(id), registry))
	var enemy := PartyMemberState.new(registry.get_enemy(enemy_id), registry)
	enemy.inventory.add_item(CLAW_INSTANCE, CLAW_ID, Vector2i(1, 1))
	enemies.append(enemy)
	if use_saved_loadout:
		loadout_save_path = MapLoadoutStore.session_path(loadout_save_path)
		var created := MapLoadoutStore.create_state(registry, registry.get_board(party[0].definition.board_layout))
		startup_error = created.error
		if startup_error.is_empty():
			var loadout: MapLoadoutState = created.state
			startup_error = MapLoadoutStore.load_into(loadout, loadout_save_path)
			if startup_error.is_empty():
				_durable_loadout = loadout
				_durable_snapshot = loadout.snapshot()
				party[0].inventory = loadout.inventory
				storage = loadout.storage
		if not startup_error.is_empty():
			DebugLogger.error(startup_error)
			set_process(false)
			return
	else:
		_seed_storage()
	if use_saved_loadout:
		startup_error = CultivationStore.load_into(party[0].knowledge,registry.library,T01CombatRules.rank(party[0]),loadout_save_path+".cultivation.json")
		if not startup_error.is_empty():
			push_error(startup_error)
			return
	if cultivation_preview:
		_setup_cultivation_preview()
	_placement_rng.randomize()
	restart()

func _seed_storage() -> void:
	for id in STORAGE_IDS:
		var item := registry.get_item(id)
		var units: Array = []
		for index in (10 if item.is_consumable() else 1):
			units.append({"id": "run.storage.%s.%d" % [id, index], "uses_left": item.uses_per_unit})
		storage.put({"instance_id": units[0]["id"], "item_id": id, "units": units})

static func sword_instance(index: int) -> String:
	return SWORD_INSTANCE if index == 0 else "run.party.%d.sword" % index

static func armor_instance(index: int) -> String:
	return ARMOR_INSTANCE if index == 0 else "run.party.%d.armor" % index

func _process(delta: float) -> void:
	if simulation == null:
		return
	simulation.advance(delta)
	var events := simulation.drain_events()
	if not events.is_empty():
		if use_saved_loadout and events.any(func(event: Dictionary): return event.kind == "pill_used" and event.get("consumed", false)):
			persist_consumption()
		if simulation.state.is_finished():
			set_adjustment(false)
		presentation_events.emit(events)
		inventory_changed.emit()

func persist_consumption() -> bool:
	if _durable_loadout == null:
		return true
	var surviving := {}
	for entry: Dictionary in storage.entries() + party[0].inventory.get_instances():
		for unit: Dictionary in entry.units:
			surviving[unit.id] = true
	var next := _durable_snapshot.duplicate(true)
	var removed := false
	for unit_id: String in next.owned_units.keys():
		if not surviving.has(unit_id):
			next.owned_units.erase(unit_id)
			removed = true
	if not removed:
		return true
	var placements: Array = []
	for placement: Dictionary in next.placements:
		placement.unit_ids = placement.get("unit_ids", [placement.instance_id]).filter(func(id: String): return next.owned_units.has(id))
		if not placement.unit_ids.is_empty():
			placement.instance_id = placement.unit_ids[0]
			placements.append(placement)
	next.placements = placements
	# Do not replace the live simulation inventory with the saved layout.
	var candidate := MapLoadoutState.new()
	candidate.registry = registry
	candidate.board = _durable_loadout.board
	candidate.records = _durable_loadout.records
	candidate.cultivation_rank_id = _durable_loadout.cultivation_rank_id
	candidate.formation_icons = _durable_loadout.formation_icons
	var error := candidate.restore(next)
	if error.is_empty():
		error = MapLoadoutStore.save(candidate, loadout_save_path)
	if not error.is_empty():
		simulation.clock.paused = true
		feedback.emit("消耗存档未完成，战斗已暂停：" + error)
		push_error(error)
		return false
	_durable_snapshot = candidate.snapshot()
	return true

func restart() -> void:
	if not startup_error.is_empty() or party.is_empty():
		return
	for member in party + enemies:
		member.reset_resources()
		member.inventory.locked = member in enemies
	adjustment_open = false
	interaction_epoch += 1
	simulation = BattleSimulation.new(party, enemies, registry, companions, enemy_companions, legacy_fixed_defense)
	battle_restarted.emit()
	adjustment_changed.emit()

func start_battle() -> void:
	if simulation != null and simulation.start():
		if cultivation_preview: _prepare_preview_conditions()
		adjustment_open = false
		interaction_epoch += 1
		for member in party + enemies:
			member.inventory.locked = true
		battle_started.emit()
		adjustment_changed.emit()
	elif simulation != null and not simulation.configuration_error.is_empty():
		feedback.emit(simulation.configuration_error)

func move_item(member_index: int, instance_id: String, cell: Vector2i) -> bool:
	if not can_edit_inventory() or member_index < 0 or member_index >= party.size():
		return _inventory_result(false)
	if party[member_index].inventory.move_item(instance_id, cell):
		if simulation.t01 != null:
			simulation.t01.refresh_equipment(party[member_index])
		inventory_changed.emit()
		return _inventory_result(true)
	return _inventory_result(false)

func _inventory_result(success: bool) -> bool:
	inventory_interaction.emit("place" if success else "invalid")
	return success

func can_edit_inventory() -> bool:
	return can_adjust() and (simulation.state.phase == GameState.Phase.PREPARATION or adjustment_open)

func can_adjust() -> bool:
	return simulation != null and (simulation.state.phase == GameState.Phase.PREPARATION or (simulation.state.phase == GameState.Phase.BATTLE and simulation.clock.paused))

func set_adjustment(open: bool) -> bool:
	if open and not can_adjust():
		return false
	adjustment_open = open
	interaction_epoch += 1
	for member in party:
		member.inventory.locked = not can_edit_inventory()
	adjustment_changed.emit()
	return true

func select_member(index: int) -> bool:
	if not can_adjust() or index < 0 or index >= party.size():
		return false
	selected_member_index = index
	selection_changed.emit()
	return true

func can_equip(storage_id: String, member_index: int, cell: Vector2i, quantity: int = 1) -> bool:
	if not can_edit_inventory() or member_index < 0 or member_index >= party.size() or party[member_index].hp <= 0:
		return false
	var entry := storage.peek_units(storage_id, quantity)
	if entry.is_empty():
		return false
	if not party[member_index].can_use_item(registry.get_item(entry.item_id)):
		return false
	var bag := party[member_index].inventory
	var item := registry.get_item(entry.item_id)
	var matching := bag.matching_stack(entry.item_id)
	if item.rule_version == 1 and item.is_consumable() and quantity + (0 if matching.is_empty() else bag.get_instance(matching).units.size()) > 10:
		return false
	return not matching.is_empty() or bag.equipment_allowed(item) and cell in bag.available_cells(entry["item_id"])

func equip(storage_id: String, member_index: int, cell: Vector2i, quantity: int = 1) -> bool:
	if not can_equip(storage_id, member_index, cell, quantity):
		return _inventory_result(false)
	var entry := storage.peek_units(storage_id, quantity)
	var bag := party[member_index].inventory
	var stacking := not bag.matching_stack(entry["item_id"]).is_empty()
	var placed := bag.put(entry, cell)
	if placed.is_empty():
		return _inventory_result(false)
	storage.take_units(storage_id, quantity)
	if not stacking:
		simulation.attach(party[member_index], 0, placed, simulation.state.phase == GameState.Phase.BATTLE)
	elif simulation.state.phase == GameState.Phase.BATTLE:
		simulation.register_inserted_units(entry["units"])
	inventory_changed.emit()
	return _inventory_result(true)

func equip_random(storage_id: String, quantity: int = 1) -> bool:
	if not can_edit_inventory():
		return _inventory_result(false)
	var entry := storage.peek_one(storage_id)
	if entry.is_empty():
		return _inventory_result(false)
	var bag := party[selected_member_index].inventory
	if not bag.matching_stack(entry["item_id"]).is_empty():
		return equip(storage_id, selected_member_index, Vector2i.ZERO, quantity)
	var cells := bag.available_cells(entry["item_id"])
	if cells.is_empty():
		feedback.emit("阵盘空间不足，物品仍保留在储物袋中")
		return _inventory_result(false)
	return equip(storage_id, selected_member_index, cells[_placement_rng.randi_range(0, cells.size() - 1)], quantity)

func can_unequip(member_index: int, id: String) -> bool:
	return can_edit_inventory() and member_index >= 0 and member_index < party.size() and party[member_index].inventory.returnable_count(id) > 0

func unequip(member_index: int, id: String, single: bool = false) -> bool:
	if not can_edit_inventory() or member_index < 0 or member_index >= party.size():
		return _inventory_result(false)
	var bag := party[member_index].inventory
	var entry := bag.take_returnable(id, single)
	if entry.is_empty():
		feedback.emit("已开启的丹药需留在阵盘用完，不能收回")
		return _inventory_result(false)
	if bag.get_instance(id).is_empty():
		simulation.detach(id)
	if registry.get_item(entry.item_id).category not in ["spell","book"]: storage.put(entry)
	inventory_changed.emit()
	return _inventory_result(true)

func set_speed(speed: float) -> void:
	if simulation != null:
		simulation.clock.set_speed(speed)

func play_normal() -> void:
	if simulation == null or simulation.state.is_finished():
		return
	set_speed(1.0)
	if simulation.state.phase == GameState.Phase.PREPARATION:
		start_battle()
	elif simulation.clock.paused:
		toggle_pause()

func pause_battle() -> void:
	if simulation != null and simulation.state.phase == GameState.Phase.BATTLE and not simulation.clock.paused:
		toggle_pause()

func request_retreat() -> bool:
	return simulation != null and simulation.request_retreat()

func request_battle_review() -> void:
	if simulation != null and simulation.state.is_finished():
		battle_review_requested.emit()

func request_battle_exit() -> void:
	if simulation != null and simulation.state.is_finished():
		battle_exit_requested.emit()

func toggle_pause() -> void:
	if simulation != null and simulation.state.phase == GameState.Phase.BATTLE:
		simulation.clock.paused = not simulation.clock.paused
		if not simulation.clock.paused:
			set_adjustment(false)
			simulation._wake_items(simulation.state.time_usec)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") and adjustment_open:
		set_adjustment(false)
	elif event.is_action_pressed("battle_pause"):
		if simulation != null and simulation.state.phase == GameState.Phase.PREPARATION:
			start_battle()
		else:
			toggle_pause()
	elif event.is_action_pressed("speed_half"):
		set_speed(0.5)
	elif event.is_action_pressed("speed_normal"):
		set_speed(1.0)
	elif event.is_action_pressed("speed_double"):
		set_speed(2.0)
	else:
		return
	get_viewport().set_input_as_handled()

# Progression supplies achieved stages; this command deliberately does not invent
# an XP price or claim that books have been earned through a growth system.
func record_cultivation_achievement(book_id: String, stage: int) -> bool:
	if not can_adjust() or simulation.state.phase != GameState.Phase.PREPARATION: return false
	var old := party[0].knowledge.snapshot()
	if not party[0].knowledge.record_achievement(registry.library,book_id,stage,T01CombatRules.rank(party[0])):
		feedback.emit(party[0].knowledge.error)
		return false
	return _save_knowledge(old)

func choose_cultivation_branch(book_id: String, stage: int, choice: String) -> bool:
	if not can_adjust() or simulation.state.phase != GameState.Phase.PREPARATION: return false
	var old := party[0].knowledge.snapshot()
	if not party[0].knowledge.choose(registry.library,book_id,stage,choice):
		feedback.emit(party[0].knowledge.error)
		return false
	if not _save_knowledge(old): return false
	for id: String in simulation.timeline.timers:
		if simulation._owners[id]==party[0]: simulation.timeline.restart(id,0)
	return true

func _save_knowledge(old: Dictionary) -> bool:
	var error := CultivationStore.save(party[0].knowledge,loadout_save_path+".cultivation.json" if use_saved_loadout else "")
	if not error.is_empty():
		party[0].knowledge.restore(old,registry.library,T01CombatRules.rank(party[0]))
		feedback.emit(error)
		return false
	inventory_changed.emit()
	return true

func record_book_acquired(book_id: String) -> bool:
	if not can_edit_inventory() or simulation.state.phase != GameState.Phase.PREPARATION: return false
	var old := party[0].knowledge.snapshot()
	if not party[0].knowledge.acquire(registry.library,book_id): return false
	return _save_knowledge(old)

func equip_known_book(book_id: String, cell: Vector2i, vertical := false) -> bool:
	if not can_edit_inventory() or not party[0].knowledge.learned.has(book_id): return false
	var id := "run."+book_id
	if not party[0].inventory.add_item(id,book_id,cell,vertical): return false
	simulation.attach(party[0],0,id,simulation.state.phase==GameState.Phase.BATTLE)
	inventory_changed.emit()
	return true

func equip_learned_spell(spell_id: String, cell: Vector2i) -> bool:
	var item := registry.get_item(spell_id)
	if not can_edit_inventory() or item==null or item.category!="spell" or not party[0].can_use_item(item): return false
	var id := "run."+spell_id
	if not party[0].inventory.add_item(id,spell_id,cell): return false
	simulation.attach(party[0],0,id,simulation.state.phase==GameState.Phase.BATTLE)
	inventory_changed.emit()
	return true

func set_item_automatic(id: String, automatic: bool) -> bool:
	return simulation!=null and simulation.timeline!=null and simulation._owners.get(id)==party[0] and simulation.timeline.set_mode(id,automatic)

func choose_armor_type(armor_type: String) -> bool:
	if not can_adjust() or armor_type not in party[0].armor_candidates: return false
	party[0].armor_choice = armor_type
	simulation.t01.refresh_equipment(party[0])
	simulation.configuration_error = simulation.t01.configuration_issue()
	inventory_changed.emit()
	return true

func set_all_automatic(automatic: bool) -> void:
	if simulation!=null and simulation.timeline!=null: simulation.timeline.set_all(party[0],automatic)

func set_prepared_enabled(id: String, enabled: bool) -> bool:
	return simulation!=null and simulation.timeline!=null and simulation._owners.get(id)==party[0] and simulation.timeline.set_enabled(id,enabled)

func activate_manual(id: String, target_id := "") -> bool:
	if simulation==null or simulation.timeline==null or simulation._owners.get(id)!=party[0]: return false
	var result := simulation.timeline.request(id,target_id)
	if result:
		presentation_events.emit(simulation.drain_events())
		inventory_changed.emit()
	return result

func _setup_cultivation_preview() -> void:
	# This separate scene has no durable inventory/learning store.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-spell="): preview_spell_id=argument.trim_prefix("--preview-spell=")
		if argument.begins_with("--preview-branch="): preview_branch=argument.trim_prefix("--preview-branch=")
	var created := MapLoadoutStore.create_state(registry,registry.get_board(party[0].definition.board_layout))
	if not created.error.is_empty(): startup_error=created.error; return
	if not registry.library.spells.has(preview_spell_id): startup_error="未知预览法术："+preview_spell_id; return
	var spell: Dictionary = registry.library.spells[preview_spell_id]
	for stage in range(1,int(spell.learned_at_book_level)+2):
		if not party[0].knowledge.record_achievement(registry.library,spell.book_id,stage,T01CombatRules.rank(party[0])): startup_error=party[0].knowledge.error; return
	if not preview_branch.is_empty() and not party[0].knowledge.choose(registry.library,spell.book_id,int(spell.learned_at_book_level)+1,preview_branch): startup_error=party[0].knowledge.error; return
	party[0].inventory=InventoryState.new(registry,party[0].board.grid_size)
	party[0].inventory.add_item("preview.spell",preview_spell_id,Vector2i.ZERO)
	party[0].inventory.add_item("preview.weapon","base.map_item.qingshi_short_sword",Vector2i(0,1))
	party[0].inventory.add_item("preview.book",spell.book_id,Vector2i(1,1))
	storage=SharedStorage.new()
	enemies[0].definition.max_hp=5000
	enemies[0].definition.name="法术观察用木桩"
	enemies[0].definition.combat_rank=T01CombatRules.rank(party[0])

func _prepare_preview_conditions() -> void:
	var p := party[0]
	var e := enemies[0]
	var spell := registry.library.resolved(p,preview_spell_id)
	# Temporary fixtures make reactive spells observable without changing any
	# player save or formal growth values.
	simulation.timeline.timers[CLAW_INSTANCE].cd = 12_000_000.0
	simulation.timeline.sync(CLAW_INSTANCE,0)
	match spell.opcode:
		"heal": p.hp = 20
		"armor_counter":
			p.armor_capacity_sources.preview = 30
			p.armor = 30
		"thunder_counter": p.thunder_shields.assign([2.0])
		"guard_critical":
			simulation.t01.forced_rolls.assign([0.0,0.0,0.0,0.0,0.0,0.0])
		"change_cd":
			simulation.timeline.timers["preview.weapon"].cd = 20_000_000.0
			simulation.timeline.sync("preview.weapon",0)
