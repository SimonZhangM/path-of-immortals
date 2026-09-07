class_name GameManager
extends Node

signal battle_restarted
signal battle_started
signal inventory_changed
signal formation_changed
signal adjustment_changed
signal selection_changed
signal feedback(message: String)
signal presentation_events(events: Array[Dictionary])

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
var formation := FormationRules.Kind.FRONT_ONE
var simulation: BattleSimulation
var startup_error: String = ""
var storage := SharedStorage.new()
var adjustment_open: bool = false
var selected_member_index: int = 0
var interaction_epoch: int = 0
var _placement_rng := RandomNumberGenerator.new()

func _ready() -> void:
	if not registry.load_base_content():
		startup_error = "\n".join(registry.errors)
	elif registry.get_item(ITEM_ID) == null or registry.get_item(ARMOR_ID) == null or registry.get_item(CLAW_ID) == null or registry.get_enemy(ENEMY_ID).is_empty():
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
	for index in PARTY_IDS.size():
		var member := PartyMemberState.new(registry.get_character(PARTY_IDS[index]), registry)
		member.inventory.add_item(sword_instance(index), ITEM_ID, Vector2i.ZERO)
		member.inventory.add_item(armor_instance(index), ARMOR_ID, Vector2i(1, 1))
		party.append(member)
	var dog := PartyMemberState.new(registry.get_enemy(ENEMY_ID), registry)
	dog.inventory.add_item(CLAW_INSTANCE, CLAW_ID, Vector2i(1, 1))
	enemies.append(dog)
	_seed_storage()
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

func set_formation(value: FormationRules.Kind) -> bool:
	if simulation == null or simulation.state.phase != GameState.Phase.PREPARATION or party.size() != 3 or value not in [FormationRules.Kind.FRONT_ONE, FormationRules.Kind.FRONT_TWO]:
		return false
	formation = value
	simulation.state.formations[0] = value
	formation_changed.emit()
	return true

func _process(delta: float) -> void:
	if simulation == null:
		return
	simulation.advance(delta)
	var events := simulation.drain_events()
	if not events.is_empty():
		presentation_events.emit(events)
		inventory_changed.emit()

func restart() -> void:
	if not startup_error.is_empty() or party.is_empty():
		return
	for member in party + enemies:
		member.reset_resources()
		member.inventory.locked = member in enemies
	adjustment_open = false
	interaction_epoch += 1
	simulation = BattleSimulation.new(party, enemies, registry, formation)
	battle_restarted.emit()
	adjustment_changed.emit()

func start_battle() -> void:
	if simulation != null and simulation.start():
		adjustment_open = false
		interaction_epoch += 1
		for member in party + enemies:
			member.inventory.locked = true
		battle_started.emit()
		adjustment_changed.emit()

func move_item(member_index: int, instance_id: String, cell: Vector2i) -> bool:
	if not can_edit_inventory() or member_index < 0 or member_index >= party.size():
		return false
	var before := party[member_index].inventory.get_instance(instance_id)
	if party[member_index].inventory.move_item(instance_id, cell):
		if before["cell"] != cell:
			simulation.attach(party[member_index], 0, instance_id, simulation.state.phase == GameState.Phase.BATTLE)
		inventory_changed.emit()
		return true
	return false

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

func can_equip(storage_id: String, member_index: int, cell: Vector2i) -> bool:
	if not can_edit_inventory() or member_index < 0 or member_index >= party.size() or party[member_index].hp <= 0:
		return false
	var entry := storage.peek_one(storage_id)
	if entry.is_empty():
		return false
	var bag := party[member_index].inventory
	return not bag.matching_stack(entry["item_id"]).is_empty() or cell in bag.available_cells(entry["item_id"])

func equip(storage_id: String, member_index: int, cell: Vector2i) -> bool:
	if not can_equip(storage_id, member_index, cell):
		return false
	var entry := storage.peek_one(storage_id)
	var bag := party[member_index].inventory
	var stacking := not bag.matching_stack(entry["item_id"]).is_empty()
	var placed := bag.put(entry, cell)
	if placed.is_empty():
		return false
	storage.take_one(storage_id)
	if not stacking:
		simulation.attach(party[member_index], 0, placed, simulation.state.phase == GameState.Phase.BATTLE)
	inventory_changed.emit()
	return true

func equip_random(storage_id: String) -> bool:
	if not can_edit_inventory():
		return false
	var entry := storage.peek_one(storage_id)
	if entry.is_empty():
		return false
	var bag := party[selected_member_index].inventory
	if not bag.matching_stack(entry["item_id"]).is_empty():
		return equip(storage_id, selected_member_index, Vector2i.ZERO)
	var cells := bag.available_cells(entry["item_id"])
	if cells.is_empty():
		feedback.emit("阵盘空间不足，物品仍保留在储物袋中")
		return false
	return equip(storage_id, selected_member_index, cells[_placement_rng.randi_range(0, cells.size() - 1)])

func unequip(member_index: int, id: String) -> bool:
	if not can_edit_inventory() or member_index < 0 or member_index >= party.size():
		return false
	var entry := party[member_index].inventory.take(id)
	if entry.is_empty():
		return false
	simulation.detach(id)
	storage.put(entry)
	inventory_changed.emit()
	return true

func set_speed(speed: float) -> void:
	if simulation != null:
		simulation.clock.set_speed(speed)

func toggle_pause() -> void:
	if simulation != null and simulation.state.phase == GameState.Phase.BATTLE:
		simulation.clock.paused = not simulation.clock.paused
		if not simulation.clock.paused:
			set_adjustment(false)

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
