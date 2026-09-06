class_name GameManager
extends Node

signal battle_restarted
signal battle_started
signal inventory_changed
signal member_selected(index: int)
signal presentation_events(events: Array[Dictionary])

const ITEM_ID := "base.test.fire_sword"
const ENEMY_ID := "base.test.dummy"
const ARMOR_ID := "base.armor.iron_armor"
const SWORD_INSTANCE := "run.item.001"
const ARMOR_INSTANCE := "run.item.002"
const PARTY_IDS := ["base.character.chen_yu", "base.character.role_2", "base.character.role_3"]
var registry := ContentRegistry.new()
var party: Array[PartyMemberState] = []
var selected_member_index: int = 0
var inventory: InventoryState:
	get:
		return party[selected_member_index].inventory if not party.is_empty() else null
var simulation: BattleSimulation
var startup_error: String = ""

func _ready() -> void:
	if not registry.load_base_content():
		startup_error = "\n".join(registry.errors)
	elif registry.get_item(ITEM_ID) == null or registry.get_item(ARMOR_ID) == null or registry.get_enemy(ENEMY_ID).is_empty():
		startup_error = "缺少原型所需的法器或敌人 ID。"
	for id in PARTY_IDS:
		if registry.get_character(id).is_empty():
			startup_error += "\n缺少角色配置：" + id
	if not startup_error.is_empty():
		DebugLogger.error(startup_error)
		set_process(false)
		return
	DebugLogger.content("Base content validated and registered.")
	for index in PARTY_IDS.size():
		var member := PartyMemberState.new(registry.get_character(PARTY_IDS[index]), registry)
		member.inventory.add_item(sword_instance(index), ITEM_ID, Vector2i(0, 0))
		member.inventory.add_item(armor_instance(index), ARMOR_ID, Vector2i(1, 1))
		party.append(member)
	restart()

static func sword_instance(index: int) -> String:
	return SWORD_INSTANCE if index == 0 else "run.party.%d.sword" % index

static func armor_instance(index: int) -> String:
	return ARMOR_INSTANCE if index == 0 else "run.party.%d.armor" % index

func can_select_member() -> bool:
	return simulation != null and (simulation.state.phase != GameState.Phase.BATTLE or simulation.clock.paused)

func select_member(index: int) -> bool:
	if not can_select_member() or index < 0 or index >= party.size():
		return false
	if selected_member_index != index:
		selected_member_index = index
		member_selected.emit(index)
	return true

func preview_member_indices() -> Array[int]:
	var result: Array[int] = []
	for index in party.size():
		if index != selected_member_index:
			result.append(index)
	return result

func _process(delta: float) -> void:
	if simulation == null:
		return
	simulation.advance(delta)
	var events := simulation.drain_events()
	if not events.is_empty():
		presentation_events.emit(events)

func restart() -> void:
	if not startup_error.is_empty() or inventory == null:
		return
	var loadout: Array = []
	for member in party:
		member.reset_resources()
		member.inventory.locked = false
		for instance in member.inventory.get_instances():
			loadout.append({"item": registry.get_item(instance["item_id"]), "instance_id": instance["instance_id"], "owner_id": member.id})
	simulation = BattleSimulation.new(registry.get_item(ITEM_ID), registry.get_enemy(ENEMY_ID), loadout)
	battle_restarted.emit()

func start_battle() -> void:
	if simulation != null and simulation.start():
		for member in party:
			member.inventory.locked = true
		battle_started.emit()

func move_item(instance_id: String, cell: Vector2i) -> bool:
	if simulation == null or simulation.state.phase != GameState.Phase.PREPARATION:
		return false
	if inventory.move_item(instance_id, cell):
		inventory_changed.emit()
		return true
	return false

func set_speed(speed: float) -> void:
	if simulation != null:
		simulation.clock.set_speed(speed)

func toggle_pause() -> void:
	if simulation != null and simulation.state.phase == GameState.Phase.BATTLE:
		simulation.clock.paused = not simulation.clock.paused

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("battle_pause"):
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
