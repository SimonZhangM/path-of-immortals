class_name GameManager
extends Node

signal battle_restarted
signal battle_started
signal inventory_changed
signal presentation_events(events: Array[Dictionary])

const ITEM_ID := "base.test.fire_sword"
const ENEMY_ID := "base.test.dummy"
const ARMOR_ID := "base.armor.iron_armor"
const SWORD_INSTANCE := "run.item.001"
const ARMOR_INSTANCE := "run.item.002"
var registry := ContentRegistry.new()
var inventory: InventoryState
var simulation: BattleSimulation
var startup_error: String = ""

func _ready() -> void:
	if not registry.load_base_content():
		startup_error = "\n".join(registry.errors)
	elif registry.get_item(ITEM_ID) == null or registry.get_item(ARMOR_ID) == null or registry.get_enemy(ENEMY_ID).is_empty():
		startup_error = "缺少原型所需的法器或敌人 ID。"
	if not startup_error.is_empty():
		DebugLogger.error(startup_error)
		set_process(false)
		return
	DebugLogger.content("Base content validated and registered.")
	inventory = InventoryState.new(registry)
	inventory.add_item(SWORD_INSTANCE, ITEM_ID, Vector2i(0, 0))
	inventory.add_item(ARMOR_INSTANCE, ARMOR_ID, Vector2i(1, 1))
	restart()

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
	inventory.locked = false
	simulation = BattleSimulation.new(registry.get_item(ITEM_ID), registry.get_enemy(ENEMY_ID))
	battle_restarted.emit()

func start_battle() -> void:
	if simulation != null and simulation.start():
		inventory.locked = true
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
