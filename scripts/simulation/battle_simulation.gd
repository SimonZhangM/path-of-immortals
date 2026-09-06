class_name BattleSimulation
extends RefCounted

var clock := SimulationClock.new()
var queue := EventQueue.new()
var state: GameState
var _definitions: Dictionary = {}
var _effects := EffectSystem.new()
var _pending_events: Array[Dictionary] = []

# An omitted loadout keeps the single-item simulation fixture supported.
func _init(item: ItemData, enemy: Dictionary, loadout: Array = []) -> void:
	state = GameState.new(item, enemy)
	if loadout.is_empty():
		loadout = [{"item": item, "instance_id": state.item_instance_id, "owner_id": ""}]
	for entry in loadout:
		var definition: ItemData = entry["item"]
		if definition.effects.is_empty():
			continue
		var instance_id: String = entry["instance_id"]
		_definitions[instance_id] = definition
		state.item_runtime[instance_id] = {"item_id": definition.id, "owner_id": entry["owner_id"], "next_activation_usec": definition.cooldown_usec, "activation_count": 0}

func start() -> bool:
	if state.phase != GameState.Phase.PREPARATION or _definitions.is_empty():
		return false
	state.phase = GameState.Phase.BATTLE
	for instance_id in _definitions:
		queue.schedule(state.item_runtime[instance_id]["next_activation_usec"], "activate", {"instance_id": instance_id})
	return true

func activation_progress(instance_id: String) -> float:
	if state.phase != GameState.Phase.BATTLE or not _definitions.has(instance_id):
		return 1.0
	var runtime: Dictionary = state.item_runtime[instance_id]
	var remaining := int(runtime["next_activation_usec"]) - state.time_usec
	return clampf(1.0 - float(remaining) / _definitions[instance_id].cooldown_usec, 0.0, 1.0)

func advance(real_delta: float) -> void:
	if state.phase != GameState.Phase.BATTLE:
		return
	var target_usec := clock.advance(real_delta)
	while queue.has_due(target_usec):
		var event := queue.pop_next()
		var due_usec := int(event["due_usec"])
		var instance_id: String = event["payload"]["instance_id"]
		var item: ItemData = _definitions[instance_id]
		var runtime: Dictionary = state.item_runtime[instance_id]
		state.activation_count += 1
		runtime["activation_count"] += 1
		state.revision += 1
		var source := {"item_id": item.id, "instance_id": instance_id, "owner_id": runtime["owner_id"]}
		for effect in item.effects:
			var result := _effects.apply(effect, state, due_usec, source)
			if not result.is_empty():
				_pending_events.append(result)
		DebugLogger.simulation("%.3f %s activated; HP=%d" % [due_usec / 1_000_000.0, instance_id, state.enemy_hp])
		if state.is_finished():
			state.phase = GameState.Phase.FINISHED
			clock.time_usec = due_usec
			target_usec = due_usec
			state.next_activation_usec = 0
			for remaining_runtime in state.item_runtime.values():
				remaining_runtime["next_activation_usec"] = 0
			queue.clear()
			_pending_events.append({"kind": "defeated", "at_usec": due_usec, "target_id": state.enemy_id})
		else:
			runtime["next_activation_usec"] = due_usec + item.cooldown_usec
			if instance_id == state.item_instance_id:
				state.next_activation_usec = runtime["next_activation_usec"]
			queue.schedule(runtime["next_activation_usec"], "activate", event["payload"])
	state.time_usec = target_usec

func drain_events() -> Array[Dictionary]:
	var events := _pending_events
	_pending_events = []
	return events
