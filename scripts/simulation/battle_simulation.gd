class_name BattleSimulation
extends RefCounted

const INSERTION_COOLDOWN_USEC := 3_000_000
var insertion_cooldown_usec: int = INSERTION_COOLDOWN_USEC
var clock := SimulationClock.new()
var queue := EventQueue.new()
var state: GameState
var _definitions: Dictionary = {}
var _owners: Dictionary = {}
var _versions: Dictionary = {}
var _registry: ContentRegistry
var _effects := EffectSystem.new()
var _pending_events: Array[Dictionary] = []
var _pending_restores: int = 0
var _unit_entry_until: Dictionary = {}

func _init(allies: Array, enemies: Array, registry: ContentRegistry, ally_formation: FormationRules.Kind = FormationRules.Kind.FRONT_ONE, enemy_formation: FormationRules.Kind = FormationRules.Kind.FRONT_ONE) -> void:
	state = GameState.new(allies, enemies, ally_formation, enemy_formation)
	_registry = registry
	for side in 2:
		for member in state.teams[side]:
			member.defense_sources.clear()
			for instance in member.inventory.get_instances():
				assert(not _definitions.has(instance["instance_id"]), "Combat instance IDs must be unique across teams")
				attach(member, side, instance["instance_id"], false)

func attach(member: PartyMemberState, side: int, id: String, inserted_during_battle: bool) -> void:
	var entry := member.inventory.get_instance(id)
	assert(not entry.is_empty())
	if _owners.has(id):
		_owners[id].defense_sources.erase(id)
	_versions[id] = int(_versions.get(id, 0)) + 1
	var item := _registry.get_item(entry["item_id"])
	_definitions[id] = item
	_owners[id] = member
	var frozen_until := state.time_usec + insertion_cooldown_usec if inserted_during_battle else 0
	if inserted_during_battle:
		register_inserted_units(entry["units"])
	state.item_runtime[id] = {"item_id": item.id, "owner_id": member.id, "side": side, "next_activation_usec": 0, "activation_count": 0, "frozen_until_usec": frozen_until, "ready_at_usec": frozen_until + item.cooldown_usec, "entered": false}
	if state.phase == GameState.Phase.BATTLE:
		# Cooldown completion becomes authoritative before attacks at the same timestamp.
		queue.schedule(frozen_until, "enter", {"instance_id": id, "version": _versions[id]}, -1)
		_wake_items(state.time_usec)
	state.revision += 1

func register_inserted_units(units: Array) -> void:
	for unit in units:
		_unit_entry_until[unit["id"]] = state.time_usec + insertion_cooldown_usec

func _entry_deadline(id: String) -> int:
	var deadline: int = state.item_runtime[id]["frozen_until_usec"]
	var entry: Dictionary = _owners[id].inventory.get_instance(id)
	if not entry.is_empty():
		deadline = maxi(deadline, int(_unit_entry_until.get(entry["units"][0]["id"], 0)))
	return deadline

func detach(id: String) -> void:
	if _owners.has(id):
		_owners[id].defense_sources.erase(id)
	_versions[id] = int(_versions.get(id, 0)) + 1
	_definitions.erase(id)
	_owners.erase(id)
	state.item_runtime.erase(id)
	state.revision += 1

func start() -> bool:
	if state.phase != GameState.Phase.PREPARATION:
		return false
	state.phase = GameState.Phase.BATTLE
	for id in _definitions:
		_enter({"instance_id": id, "version": _versions[id]}, 0)
	_wake_items(0)
	_check_result(0)
	return true

func _can_activate(id: String) -> bool:
	if not _definitions.has(id):
		return false
	var owner: PartyMemberState = _owners[id]
	var item: ItemData = _definitions[id]
	if owner.hp <= 0 or item.effects_for("on_activate").is_empty() or owner.stamina < item.stamina_cost:
		return false
	if item.is_consumable():
		var entry := owner.inventory.get_instance(id)
		if entry.is_empty():
			return false
		var opened: bool = int(entry["units"][0]["uses_left"]) < item.uses_per_unit
		var resource: String = item.effects[0]["resource"]
		return opened or int(owner.get(resource)) < int(owner.definition["max_" + resource])
	return true

# Wake on commands/resource events, never poll items each rendered frame.
func _wake_items(at_usec: int) -> void:
	for id in _definitions:
		var runtime: Dictionary = state.item_runtime[id]
		if int(runtime["next_activation_usec"]) != 0 or not _can_activate(id):
			continue
		var item: ItemData = _definitions[id]
		var ready: int = runtime["ready_at_usec"]
		if ready == 0:
			ready = at_usec + item.cooldown_usec
		_schedule(id, maxi(at_usec, ready))

func _schedule(id: String, at_usec: int) -> void:
	at_usec = maxi(at_usec, _entry_deadline(id) + _definitions[id].cooldown_usec)
	state.item_runtime[id]["next_activation_usec"] = at_usec
	queue.schedule(at_usec, "activate", {"instance_id": id, "version": _versions[id]})

func cooling_remaining_usec(id: String) -> int:
	if state.phase != GameState.Phase.BATTLE or not state.item_runtime.has(id):
		return 0
	return maxi(0, _entry_deadline(id) - state.time_usec)

func activation_progress(id: String) -> float:
	if state.phase != GameState.Phase.BATTLE or not _definitions.has(id):
		return 1.0
	if cooling_remaining_usec(id) > 0:
		return 0.0
	var item: ItemData = _definitions[id]
	if item.cooldown_usec == 0:
		return 1.0
	var runtime: Dictionary = state.item_runtime[id]
	var next: int = runtime["next_activation_usec"]
	if next == 0:
		next = runtime["ready_at_usec"]
	return clampf(1.0 - float(next - state.time_usec) / item.cooldown_usec, 0.0, 1.0) if next > 0 else 1.0

func advance(real_delta: float) -> void:
	if state.phase != GameState.Phase.BATTLE or clock.paused:
		return
	_check_result(state.time_usec)
	if state.is_finished():
		return
	var target_usec := clock.advance(real_delta)
	while queue.has_due(target_usec) and not state.is_finished():
		var event := queue.pop_next()
		var at_usec: int = event["due_usec"]
		state.time_usec = at_usec
		if event["kind"] == "restore":
			_apply_restore(event["payload"], at_usec)
		elif event["kind"] == "enter":
			_enter(event["payload"], at_usec)
		else:
			_activate(event["payload"], at_usec)
		_wake_items(at_usec)
		_check_result(at_usec)
	state.time_usec = state.finished_at_usec if state.is_finished() else target_usec

func _activate(payload: Dictionary, at_usec: int) -> void:
	var id: String = payload["instance_id"]
	if not _definitions.has(id) or payload["version"] != _versions[id]:
		return
	var runtime: Dictionary = state.item_runtime[id]
	runtime["next_activation_usec"] = 0
	if not _can_activate(id):
		if not _definitions[id].is_consumable():
			runtime["ready_at_usec"] = 0
		return
	var owner: PartyMemberState = _owners[id]
	var item: ItemData = _definitions[id]
	var side: int = runtime["side"]
	owner.stamina -= item.stamina_cost
	runtime["activation_count"] += 1
	state.revision += 1
	var source := {"item_id": item.id, "instance_id": id, "owner_id": owner.id, "owner_name": owner.definition["name"], "side": side, "stamina_cost": item.stamina_cost, "stamina_after": owner.stamina}
	_pending_events.append({"kind": "item_activated", "at_usec": at_usec, "owner_id": owner.id, "side": side, "entry": owner.inventory.get_instance(id)})
	if item.is_consumable():
		var effect: Dictionary = item.effects[0]
		var duration: int = effect["duration"]
		for tick in range(1, duration + 1):
			# Integer ticks conserve totals: 5 over 3 seconds -> 1,2,2.
			var amount := int(effect["value"]) * tick / duration - int(effect["value"]) * (tick - 1) / duration
			queue.schedule(at_usec + tick * 1_000_000, "restore", {"owner": owner, "resource": effect["resource"], "amount": amount, "source": source})
			_pending_restores += 1
		var consumed := owner.inventory.use_consumable(id)
		_pending_events.append({"kind": "pill_used", "at_usec": at_usec, "owner_name": owner.definition["name"], "item_id": item.id, "consumed": consumed})
		if owner.inventory.get_instance(id).is_empty():
			detach(id)
			return
	else:
		var target := state.target_for(side)
		if target == null:
			return
		state.activation_counts[side] += 1
		for effect in item.effects_for("on_activate"):
			var result := _effects.apply(effect, state, target, at_usec, source)
			if not result.is_empty():
				_pending_events.append(result)
		if target.hp == 0:
			_pending_events.append({"kind": "fallen", "at_usec": at_usec, "target_name": target.definition["name"], "target_id": target.id})
		else:
			_counterattack(target, owner, 1 - side, at_usec)
	runtime["ready_at_usec"] = at_usec + item.cooldown_usec
	if _can_activate(id):
		_schedule(id, runtime["ready_at_usec"])

func _apply_restore(payload: Dictionary, at_usec: int) -> void:
	_pending_restores -= 1
	var result := _effects.restore(payload["owner"], payload["resource"], payload["amount"], at_usec, payload["source"])
	if not result.is_empty():
		state.revision += 1
		_pending_events.append(result)

func _enter(payload: Dictionary, at_usec: int) -> void:
	var id: String = payload["instance_id"]
	if not _definitions.has(id) or payload["version"] != _versions[id] or state.item_runtime[id]["entered"]:
		return
	var owner: PartyMemberState = _owners[id]
	if owner.hp <= 0:
		return
	var item: ItemData = _definitions[id]
	state.item_runtime[id]["entered"] = true
	var defense := item.defense
	for effect in item.effects_for("on_enter"):
		defense += int(effect["value"])
		_pending_events.append({"kind": "entered", "at_usec": at_usec, "owner_name": owner.definition["name"], "item_id": item.id, "defense": int(effect["value"])})
	if defense > 0:
		owner.defense_sources[id] = defense
	state.revision += 1

func _counterattack(defender: PartyMemberState, attacker: PartyMemberState, side: int, at_usec: int) -> void:
	# A bounded reaction pass: counters do not enter this method recursively.
	for id in _definitions:
		if attacker.hp <= 0:
			break
		if _owners[id] != defender or not state.item_runtime[id]["entered"]:
			continue
		var item: ItemData = _definitions[id]
		for effect in item.effects_for("on_attacked"):
			var source := {"item_id": item.id, "instance_id": id, "owner_id": defender.id, "owner_name": defender.definition["name"], "side": side, "stamina_cost": 0}
			var result := _effects.apply(effect, state, attacker, at_usec, source)
			if not result.is_empty():
				_pending_events.append(result)
				if attacker.hp == 0:
					_pending_events.append({"kind": "fallen", "at_usec": at_usec, "target_name": attacker.definition["name"], "target_id": attacker.id})

func _check_result(at_usec: int) -> void:
	if not state.has_survivor(0):
		_finish("defeat", at_usec)
	elif not state.has_survivor(1):
		_finish("victory", at_usec)
	else:
		if _pending_restores > 0:
			return
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
	_pending_restores = 0
	for runtime in state.item_runtime.values():
		runtime["next_activation_usec"] = 0
	_pending_events.append({"kind": "finished", "at_usec": at_usec, "result": result})

func drain_events() -> Array[Dictionary]:
	var events := _pending_events
	_pending_events = []
	return events
