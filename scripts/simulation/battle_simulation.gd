class_name BattleSimulation
extends RefCounted

var clock := SimulationClock.new()
var queue := EventQueue.new()
var state: GameState
var _item: ItemData
var _effects := EffectSystem.new()
var _pending_events: Array[Dictionary] = []

func _init(item: ItemData, enemy: Dictionary) -> void:
	_item = item
	state = GameState.new(item, enemy)
	queue.schedule(state.next_activation_usec, "activate", {"instance_id": state.item_instance_id})

func advance(real_delta: float) -> void:
	var target_usec := clock.advance(real_delta)
	while queue.has_due(target_usec):
		var event := queue.pop_next()
		var due_usec := int(event["due_usec"])
		if state.is_finished():
			queue.clear()
			break
		state.activation_count += 1
		state.revision += 1
		for effect in _item.effects:
			var result := _effects.apply(effect, state, due_usec)
			if not result.is_empty():
				_pending_events.append(result)
		DebugLogger.simulation("%.3f %s activated; HP=%d" % [due_usec / 1_000_000.0, _item.id, state.enemy_hp])
		if state.is_finished():
			state.next_activation_usec = 0
			queue.clear()
			_pending_events.append({"kind": "defeated", "at_usec": due_usec, "target_id": state.enemy_id})
		else:
			# Reschedule from the exact due time, never from frame end; no cooldown drift.
			state.next_activation_usec = due_usec + _item.cooldown_usec
			queue.schedule(state.next_activation_usec, "activate", event["payload"])
	state.time_usec = target_usec

func drain_events() -> Array[Dictionary]:
	var events := _pending_events
	_pending_events = []
	return events
