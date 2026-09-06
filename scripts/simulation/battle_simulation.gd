class_name BattleSimulation
extends RefCounted

var clock := SimulationClock.new()
var queue := EventQueue.new()
var state: GameState
var _definitions: Dictionary = {}
var _owners: Dictionary = {}
var _effects := EffectSystem.new()
var _pending_events: Array[Dictionary] = []

func _init(allies: Array, enemies: Array, registry: ContentRegistry, ally_formation: FormationRules.Kind = FormationRules.Kind.FRONT_ONE, enemy_formation: FormationRules.Kind = FormationRules.Kind.FRONT_ONE) -> void:
	state = GameState.new(allies, enemies, ally_formation, enemy_formation)
	# Stable ties: allied roster/item order, then enemy roster/item order.
	for side in 2:
		for member in state.teams[side]:
			for instance in member.inventory.get_instances():
				var item := registry.get_item(instance["item_id"])
				if item.effects.is_empty():
					continue
				var id: String = instance["instance_id"]
				assert(not _definitions.has(id), "Combat instance IDs must be unique across teams")
				_definitions[id] = item
				_owners[id] = member
				state.item_runtime[id] = {"item_id": item.id, "owner_id": member.id, "side": side, "next_activation_usec": 0, "activation_count": 0}

func start() -> bool:
	if state.phase != GameState.Phase.PREPARATION:
		return false
	state.phase = GameState.Phase.BATTLE
	for id in _definitions:
		if _can_activate(id):
			_schedule(id, _definitions[id].cooldown_usec)
	_check_result(0)
	return true

func _can_activate(id: String) -> bool:
	var owner: PartyMemberState = _owners[id]
	var item: ItemData = _definitions[id]
	return owner.hp > 0 and owner.stamina >= item.stamina_cost

func _schedule(id: String, at_usec: int) -> void:
	state.item_runtime[id]["next_activation_usec"] = at_usec
	queue.schedule(at_usec, "activate", {"instance_id": id})

func activation_progress(id: String) -> float:
	if state.phase != GameState.Phase.BATTLE or not _definitions.has(id) or not _can_activate(id):
		return 1.0
	var next: int = state.item_runtime[id]["next_activation_usec"]
	if next == 0:
		return 1.0
	return clampf(1.0 - float(next - state.time_usec) / _definitions[id].cooldown_usec, 0.0, 1.0)

func advance(real_delta: float) -> void:
	if state.phase != GameState.Phase.BATTLE or clock.paused:
		return
	var target_usec := clock.advance(real_delta)
	while queue.has_due(target_usec) and not state.is_finished():
		var event := queue.pop_next()
		var at_usec: int = event["due_usec"]
		var id: String = event["payload"]["instance_id"]
		var runtime: Dictionary = state.item_runtime[id]
		runtime["next_activation_usec"] = 0
		if not _can_activate(id):
			_check_result(at_usec)
			continue
		var side: int = runtime["side"]
		var target := state.target_for(side)
		if target == null:
			_check_result(at_usec)
			continue
		var owner: PartyMemberState = _owners[id]
		var item: ItemData = _definitions[id]
		owner.stamina -= item.stamina_cost
		runtime["activation_count"] += 1
		state.activation_counts[side] += 1
		state.revision += 1
		var source := {"item_id": item.id, "instance_id": id, "owner_id": owner.id, "owner_name": owner.definition["name"], "side": side, "stamina_cost": item.stamina_cost, "stamina_after": owner.stamina}
		for effect in item.effects:
			var result := _effects.apply(effect, state, target, at_usec, source)
			if not result.is_empty():
				_pending_events.append(result)
		if target.hp == 0:
			_pending_events.append({"kind": "fallen", "at_usec": at_usec, "target_name": target.definition["name"], "target_id": target.id})
		_check_result(at_usec)
		if not state.is_finished() and _can_activate(id):
			_schedule(id, at_usec + item.cooldown_usec)
	state.time_usec = state.finished_at_usec if state.is_finished() else target_usec

func _check_result(at_usec: int) -> void:
	if not state.has_survivor(0):
		_finish("defeat", at_usec)
	elif not state.has_survivor(1):
		_finish("victory", at_usec)
	else:
		for id in _definitions:
			if _can_activate(id):
				return
		_finish("draw", at_usec)

func _finish(result: String, at_usec: int) -> void:
	state.result = result
	state.phase = GameState.Phase.FINISHED
	state.finished_at_usec = at_usec
	state.time_usec = at_usec
	clock.time_usec = at_usec
	state.revision += 1
	queue.clear()
	for runtime in state.item_runtime.values():
		runtime["next_activation_usec"] = 0
	_pending_events.append({"kind": "finished", "at_usec": at_usec, "result": result})

func drain_events() -> Array[Dictionary]:
	var events := _pending_events
	_pending_events = []
	return events
