class_name BattleItemRules
extends RefCounted

# Per-unit battle history survives removal/reinsertion. No wall-clock polling.
var _simulation: WeakRef
var sim: BattleSimulation:
	get: return _simulation.get_ref()
var units: Dictionary = {}

func _init(battle: BattleSimulation) -> void:
	_simulation = weakref(battle)

func attach(id: String) -> void:
	var entry: Dictionary = sim._owners[id].inventory.get_instance(id)
	var key: String = entry.units[0].id
	if units.has(key):
		units[key].id = id
		return
	units[key] = {"id": id, "owner": sim._owners[id], "item": sim._definitions[id], "uses": 0, "triggered": false, "started": false}
	if sim.state.phase == GameState.Phase.BATTLE: start_unit(key, sim.state.time_usec)

func unit(id: String) -> Dictionary:
	if not sim._owners.has(id): return {}
	var entry: Dictionary = sim._owners[id].inventory.get_instance(id)
	return units.get(entry.units[0].id, {}) if not entry.is_empty() else {}

func available(id: String) -> bool:
	var record := unit(id)
	if record.is_empty(): return false
	var limit := int(record.item.combat.get("battle_use_limit", 0))
	return limit == 0 or record.uses < limit

static func conditions_met(member: PartyMemberState, item: ItemData) -> bool:
	var condition: Dictionary = item.combat.get("activation_threshold", {})
	if not condition.is_empty() and member.get(condition.resource) * condition.denominator > member.maximum(condition.resource) * condition.numerator: return false
	return not item.combat.get("requires_missing_armor", false) or member.armor < member.maximum("armor")

func activated(id: String) -> void:
	var record := unit(id)
	if not record.is_empty(): record.uses += 1

func start_unit(key: String, at: int) -> void:
	var record: Dictionary = units[key]
	if record.started: return
	record.started = true
	var periodic: Dictionary = record.item.combat.get("periodic_restore", {})
	if periodic.is_empty(): return
	record.next = at + roundi(periodic.interval * 1_000_000)
	# V2: simultaneous active fees settle before equipment's periodic recovery.
	sim.queue.schedule(record.next, "item_periodic", {"key": key}, 2)

func start() -> void:
	for key: String in units: start_unit(key, 0)

func periodic_tick(key: String, at: int) -> void:
	var record: Dictionary = units[key]
	var owner: PartyMemberState = record.owner
	if owner.hp <= 0: return
	var periodic: Dictionary = record.item.combat.periodic_restore
	if sim._owners.has(record.id) and unit(record.id) == record:
		sim.record_trace.begin(sim.t01.record_source(owner, sim.t01.item_source(record.id)), at, "periodic")
		for resource: String in periodic.resources:
			sim.t01.restore(owner, resource, periodic.resources[resource], at, -1.0, sim.t01.item_source(record.id))
		sim.record_trace.end()
	record.next = at + roundi(periodic.interval * 1_000_000)
	sim.queue.schedule(record.next, "item_periodic", {"key": key}, 2)

func wake(at: int) -> void:
	if not sim.state.has_survivor(0) or not sim.state.has_survivor(1): return
	for record: Dictionary in units.values():
		if record.triggered or not sim._owners.has(record.id) or unit(record.id) != record: continue
		var passive: Dictionary = record.item.combat.get("low_hp_physical_buff", {})
		var owner: PartyMemberState = record.owner
		if passive.is_empty() or owner.hp <= 0 or owner.hp * passive.denominator > owner.maximum("hp") * passive.numerator: continue
		record.triggered = true
		owner.temporary_effects[record.item.id] = {"until": at + roundi(passive.duration * 1_000_000), "physical_bonus": passive.bonus}
		sim.t01.emit("item_passive", at, sim.t01.record_source(owner, {"item_id": record.item.id, "target_id": owner.id, "target_name": owner.definition.name, "label": "物理攻击提高", "value": passive.bonus, "duration": passive.duration}))

func has_future_recovery() -> bool:
	for record: Dictionary in units.values():
		if record.owner.hp > 0 and sim._owners.has(record.id) and record.item.combat.has("periodic_restore"): return true
	return false

func followup(payload: Dictionary, at: int) -> void:
	if payload.owner.hp <= 0 or payload.target.hp <= 0: return
	sim.t01.attack_item(payload.owner, payload.target, payload.item, payload.attack, at, payload.source.duplicate(true))
