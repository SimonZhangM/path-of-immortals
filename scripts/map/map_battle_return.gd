class_name MapBattleReturn
extends Node

# Scene orchestration only. The simulation owns the result; the map event state
# owns whether this encounter is alive. No map completion is written to disk.
var manager: GameManager
var events: MapEventState
var event_id := ""
var map_scene_path := ""
var point_id := ""
var facing := ""
var save_path := ""
var _recorded := false
var _returning := false

func _ready() -> void:
	manager.presentation_events.connect(_on_battle_events)

func _on_battle_events(batch: Array[Dictionary]) -> void:
	if not _recorded and batch.any(func(event: Dictionary): return event.kind == "finished"):
		_record_result()

func _record_result() -> void:
	if not _recorded and manager.simulation != null and manager.simulation.state.is_finished():
		_recorded = events.resolve_encounter(event_id, manager.simulation.state.result)

func return_to_map() -> String:
	if _returning:
		return ""
	if manager.simulation == null or not manager.simulation.state.is_finished():
		return "战斗尚未结束。"
	_record_result()
	if not manager.persist_consumption():
		return "消耗记录保存失败，请重试。"
	var scene := load(map_scene_path) as PackedScene
	if scene == null:
		return "原地图暂时无法载入，请重试。"
	_returning = true
	var destination = scene.instantiate()
	destination.inventory_save_path = save_path
	destination.arrival_point_id = point_id
	destination.arrival_facing = facing
	get_tree().root.add_child(destination)
	if not destination.startup_error.is_empty():
		destination.queue_free()
		_returning = false
		return "返回地图失败，请重试。"
	get_tree().current_scene = destination
	get_parent().queue_free()
	return ""
