class_name MapBattleReturn
extends Node

# Scene orchestration only. The simulation owns the result; the map event state
# owns whether this encounter is alive. Reward receipts persist separately from
# the test-only runtime enemy respawn state, in the inventory's atomic save.
var manager: GameManager
var player_status: MapPlayerStatus
var _resources_recorded := false
var events: MapEventState
var event_id := ""
var map_scene_path := ""
var point_id := ""
var facing := ""
var save_path := ""
var _recorded := false
var _returning := false
var _battle_id := Crypto.new().generate_random_bytes(16).hex_encode()
var _loot_rolls: Array = []
var reward_error := ""

func _ready() -> void:
	manager.presentation_events.connect(_on_battle_events)

func _on_battle_events(batch: Array[Dictionary]) -> void:
	if not _recorded and batch.any(func(event: Dictionary): return event.kind == "finished"):
		_record_result()

func _record_result() -> void:
	if not _recorded and manager.simulation != null and manager.simulation.state.is_finished():
		# Capture the final resources once. Only an actual zero-HP defeat grants
		# one post-battle HP; withdrawal retains its actual surviving resources.
		if not _resources_recorded and player_status != null:
			var defeated := manager.simulation.state.finish_reason == "defeat" and manager.party[0].hp <= 0
			player_status.apply_battle_resources(manager.party[0],defeated)
			_resources_recorded = true
		if manager.simulation.state.result == "victory":
			reward_error = _award_victory()
			if not reward_error.is_empty():
				manager.loot_summary = reward_error + " 点击返回地图重试。"
				return
		_recorded = events.resolve_encounter(event_id, manager.simulation.state.result)

func _award_victory() -> String:
	if manager.simulation == null or manager.simulation.state.result != "victory": return "仅战斗胜利后可结算掉落。"
	var enemy: Dictionary = manager.enemies[0].definition
	if enemy.get("loot", []).is_empty(): return ""
	if manager._durable_loadout == null: return "缺少战利品库存。"
	if not manager.persist_consumption(): return "消耗记录保存失败。"
	if _loot_rolls.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for row in enemy.loot: _loot_rolls.append(float(rng.randi()) / 4294967296.0)
	var state := MapLoadoutState.new()
	state.registry = manager.registry
	state.board = manager._durable_loadout.board
	state.records = manager._durable_loadout.records
	state.cultivation_rank_id = manager._durable_loadout.cultivation_rank_id
	state.formation_icons = manager._durable_loadout.formation_icons
	var error := state.restore(manager._durable_snapshot)
	if not error.is_empty(): return error
	var prepared := BattleLoot.candidate(state, enemy, _battle_id, _loot_rolls)
	if not prepared.error.is_empty(): return prepared.error
	error = state.restore(prepared.snapshot)
	if error.is_empty(): error = MapLoadoutStore.save(state, save_path)
	if not error.is_empty(): return error
	# Publish ownership only after the inventory and first-victory receipt save.
	for entry: Dictionary in state.storage.entries():
		var gained: Array = entry.units.filter(func(unit: Dictionary): return not manager._durable_snapshot.owned_units.has(unit.id))
		if not gained.is_empty(): manager.storage.put({"instance_id": gained[0].id, "item_id": entry.item_id, "units": gained})
	manager._durable_snapshot = state.snapshot()
	var names: PackedStringArray = []
	for item_id: String in prepared.drops: names.append(manager.registry.get_item(item_id).display_name + " ×1")
	manager.loot_summary = "获得材料：\n" + "\n".join(names) if not names.is_empty() else "本次未掉落材料。"
	return ""

func return_to_map() -> String:
	if _returning:
		return ""
	if manager.simulation == null or not manager.simulation.state.is_finished():
		return "战斗尚未结束。"
	_record_result()
	if not reward_error.is_empty(): return reward_error
	if not manager.persist_consumption():
		return "消耗记录保存失败，请重试。"
	var scene := load(map_scene_path) as PackedScene
	if scene == null:
		return "原地图暂时无法载入，请重试。"
	_returning = true
	var destination = scene.instantiate()
	destination.player_status = player_status
	destination.defer_map_music = true
	destination.hide()
	destination.process_mode = Node.PROCESS_MODE_DISABLED
	destination.inventory_save_path = save_path
	destination.arrival_point_id = point_id
	destination.arrival_facing = facing
	get_tree().root.add_child(destination)
	if not destination.startup_error.is_empty():
		destination.queue_free()
		_returning = false
		return "返回地图失败，请重试。"
	var battle := get_parent()
	var ui := battle.get_node("MainUI")
	await MapPresentation.change_battle_scene(battle, destination, ui, destination, false, ui.game_audio)
	get_parent().queue_free()
	return ""
