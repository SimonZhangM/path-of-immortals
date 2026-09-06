class_name GameManager
extends Node

signal battle_restarted
signal presentation_events(events: Array[Dictionary])

const ITEM_ID := "base.test.fire_sword"
const ENEMY_ID := "base.test.dummy"
var registry := ContentRegistry.new()
var simulation: BattleSimulation
var startup_error: String = ""

func _ready() -> void:
	if not registry.load_base_content():
		startup_error = "\n".join(registry.errors)
	elif registry.get_item(ITEM_ID) == null or registry.get_enemy(ENEMY_ID).is_empty():
		startup_error = "缺少原型所需的法器或敌人 ID。"
	if not startup_error.is_empty():
		DebugLogger.error(startup_error)
		set_process(false)
		return
	DebugLogger.content("Base content validated and registered.")
	restart()

func _process(delta: float) -> void:
	if simulation == null:
		return
	simulation.advance(delta)
	var events := simulation.drain_events()
	if not events.is_empty():
		presentation_events.emit(events)

func restart() -> void:
	simulation = BattleSimulation.new(registry.get_item(ITEM_ID), registry.get_enemy(ENEMY_ID))
	battle_restarted.emit()

func set_speed(speed: int) -> void:
	if simulation != null:
		simulation.clock.set_speed(speed)

func toggle_pause() -> void:
	if simulation != null:
		simulation.clock.paused = not simulation.clock.paused
