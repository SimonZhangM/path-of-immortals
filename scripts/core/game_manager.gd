class_name GameManager
extends Node

signal battle_restarted
signal battle_started
signal inventory_changed
signal formation_changed
signal presentation_events(events: Array[Dictionary])

const ITEM_ID := "base.test.fire_sword"
const ENEMY_ID := "base.enemy.wild_dog"
const CLAW_ID := "base.weapon.dog_claw"
const ARMOR_ID := "base.armor.iron_armor"
const SWORD_INSTANCE := "run.item.001"
const ARMOR_INSTANCE := "run.item.002"
const CLAW_INSTANCE := "run.enemy.0.claw"
const PARTY_IDS := ["base.character.chen_yu", "base.character.role_2", "base.character.role_3"]
var registry := ContentRegistry.new()
var party: Array[PartyMemberState] = []
var enemies: Array[PartyMemberState] = []
var formation := FormationRules.Kind.FRONT_ONE
var simulation: BattleSimulation
var startup_error: String = ""

func _ready() -> void:
	if not registry.load_base_content():
		startup_error = "\n".join(registry.errors)
	elif registry.get_item(ITEM_ID) == null or registry.get_item(ARMOR_ID) == null or registry.get_item(CLAW_ID) == null or registry.get_enemy(ENEMY_ID).is_empty():
		startup_error = "缺少原型所需的装备或敌人配置。"
	for id in PARTY_IDS:
		if registry.get_character(id).is_empty():
			startup_error += "\n缺少角色配置：" + id
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
	restart()

static func sword_instance(index: int) -> String:
	return SWORD_INSTANCE if index == 0 else "run.party.%d.sword" % index

static func armor_instance(index: int) -> String:
	return ARMOR_INSTANCE if index == 0 else "run.party.%d.armor" % index

func set_formation(value: FormationRules.Kind) -> bool:
	if not can_edit_inventory() or party.size() != 3 or value not in [FormationRules.Kind.FRONT_ONE, FormationRules.Kind.FRONT_TWO]:
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

func restart() -> void:
	if not startup_error.is_empty() or party.is_empty():
		return
	for member in party + enemies:
		member.reset_resources()
		member.inventory.locked = member in enemies
	simulation = BattleSimulation.new(party, enemies, registry, formation)
	battle_restarted.emit()

func start_battle() -> void:
	if simulation != null and simulation.start():
		for member in party + enemies:
			member.inventory.locked = true
		battle_started.emit()

func move_item(member_index: int, instance_id: String, cell: Vector2i) -> bool:
	if not can_edit_inventory() or member_index < 0 or member_index >= party.size():
		return false
	if party[member_index].inventory.move_item(instance_id, cell):
		inventory_changed.emit()
		return true
	return false

func can_edit_inventory() -> bool:
	return simulation != null and simulation.state.phase == GameState.Phase.PREPARATION

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
		if can_edit_inventory():
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
