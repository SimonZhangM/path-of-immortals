class_name CombatTimeline
extends RefCounted

const CONTROL_NAMES := {"freeze":"冻结", "root":"定身", "disable":"禁用", "silence":"沉默", "disrupt":"扰乱", "weakness":"虚弱"}

# All values are simulation microseconds of remaining work. Speed changes settle
# the old interval first; stale heap entries are rejected by timer generations.
var _simulation: WeakRef
var sim: BattleSimulation:
	get: return _simulation.get_ref()
var timers: Dictionary = {}
var controls: Dictionary = {}
var serial := 0
var error := ""

func _init(battle: BattleSimulation) -> void:
	_simulation = weakref(battle)

func full_cd(id: String) -> int:
	var item: ItemData = sim._definitions[id]
	var p := sim.cultivation.data(sim._owners[id], item)
	return roundi(floorf(item.cooldown_usec / 10000.0 * (1 + float(p.get("cd_pct", 0))) + .5) * 10000)

func attach(id: String, inserted: bool) -> void:
	var item: ItemData = sim._definitions[id]
	timers[id] = {"reactive": 9_000_000.0, "entry": float(sim.insertion_cooldown_usec if inserted else 0), "cd": float(0 if item.combat.get("first_ready", false) else full_cd(id)), "at": sim.state.time_usec, "speed": 1.0, "token": 0, "auto": true, "enabled": true, "request": false, "selection": "", "speed_modifiers": {}}

func settle(id: String, at: int) -> void:
	var t: Dictionary = timers[id]
	var work := maxf(0, at - int(t.at)) * float(t.speed)
	var entry_work := minf(work, t.entry)
	t.reactive=maxf(0,float(t.reactive)-work)
	t.entry -= entry_work
	t.cd = maxf(0, float(t.cd) - (work - entry_work))
	t.at = at

func matches(id: String, scope: String) -> bool:
	var item: ItemData = sim._definitions[id]
	return scope == "all" or scope == id or scope == "spells" and item.category == "spell" or scope == "items" and item.category != "spell" or scope == "weapons" and item.category == "weapon"

func blocked(id: String, at: int, listener := false) -> bool:
	if not timers.has(id): return true
	var member: PartyMemberState = sim._owners[id]
	for c: Dictionary in controls.values():
		if c.member == member and int(c.until) > at and matches(id, c.scope) and c.kind in ["freeze", "root", "disable", "silence"]:
			return true
	return listener and not sim.state.item_runtime[id].entered

func speed(id: String, at: int) -> float:
	if blocked(id, at) or sim.state.item_runtime[id].get("barrier_stopped", false): return 0
	var value := 1.0
	for modifier: float in timers[id].speed_modifiers.values(): value += modifier
	for c: Dictionary in controls.values():
		if c.member == sim._owners[id] and int(c.until) > at and matches(id, c.scope) and c.kind == "disrupt": value -= 0.25
	return maxf(0, value)

func sync(id: String, at: int) -> void:
	if not timers.has(id) or not sim._definitions.has(id): return
	settle(id, at)
	var t: Dictionary = timers[id]
	var rt: Dictionary = sim.state.item_runtime[id]
	t.speed = speed(id, at)
	serial += 1
	t.token = serial
	rt.reactive_ready=at+ceili(t.reactive/t.speed) if t.speed>0 else at+ceili(t.reactive)
	rt.next_activation_usec = 0
	if t.entry <= 0 and not blocked(id, at): rt.entered = true
	var remaining := float(t.entry) + float(t.cd)
	rt.ready_at_usec = at + ceili(remaining / t.speed) if t.speed > 0 else at + ceili(remaining)
	rt.frozen_until_usec = at + ceili(t.entry / t.speed) if t.speed > 0 else at + ceili(t.entry)
	if t.speed > 0 and remaining > 0:
		var next_work := float(t.entry) if t.entry > 0 else float(t.cd)
		var due := at + maxi(1, ceili(next_work / t.speed))
		rt.next_activation_usec = rt.ready_at_usec
		sim.queue.schedule(due, "timeline", {"id": id, "token": t.token}, -1)

func wake(at: int) -> void:
	if sim.state.phase != GameState.Phase.BATTLE or sim.clock.paused: return
	for team: Array in sim.state.teams: sim.cultivation.flush_delays(team[0],at)
	var ids: Array = []
	for side in 2:
		for entry: Dictionary in sim.cultivation.ordered(sim.state.teams[side][0]):
			if timers.has(entry.instance_id): ids.append(entry.instance_id)
	for id: String in ids:
		if not sim._definitions.has(id):
			timers.erase(id)
			continue
		settle(id, at)
		sim.state.item_runtime[id].reactive_ready=at+ceili(timers[id].reactive)
		var t: Dictionary = timers[id]
		var rt: Dictionary = sim.state.item_runtime[id]
		var item: ItemData = sim._definitions[id]
		var member: PartyMemberState = sim._owners[id]
		if item.combat.get("barrier_full_stop", false) and member.barrier >= T01CombatRules.barrier_capacity(member):
			rt.barrier_stopped = true
		if t.speed != speed(id, at): sync(id, at)
		if blocked(id, at) or rt.get("barrier_stopped", false) or t.entry > 0 or t.cd > 0: continue
		rt.entered = true
		if item.cooldown_usec <= 0: continue
		if item.combat.get("prepared", false):
			rt.prepared = t.enabled
			continue
		if not t.auto and not t.request: continue
		if member.paralyzed_until > at or not sim._can_activate(id): continue
		t.request = false
		if consume_block(id, at): continue
		sim._activate({"instance_id": id, "version": sim._versions[id]}, at)

func event(payload: Dictionary, at: int) -> void:
	var id: String = payload.id
	if not timers.has(id) or timers[id].token != payload.token: return
	settle(id, at)
	if timers[id].entry <= 0 and timers[id].cd <= 0 and timers[id].get("block_at_zero", false) and consume_block(id, at): return
	if timers[id].entry <= 0 and timers[id].cd <= 0 and sim._owners[id].paralyzed_until > at:
		restart(id, at)
	else: sync(id, at)

func restart(id: String, at: int) -> void:
	if not timers.has(id): return
	settle(id, at)
	timers[id].cd = float(full_cd(id)) + int(sim.state.item_runtime[id].get("next_cd_extra",0))
	sim.state.item_runtime[id].erase("next_cd_extra")
	sim.state.item_runtime[id].prepared = false
	sync(id, at)

func set_mode(id: String, automatic: bool) -> bool:
	if not timers.has(id) or sim._definitions[id].combat.get("prepared", false): return false
	timers[id].auto = automatic
	timers[id].request = false
	if sim.state.phase == GameState.Phase.BATTLE: wake(sim.state.time_usec)
	return true

func set_all(member: PartyMemberState, automatic: bool) -> void:
	for id: String in timers:
		if sim._owners[id]==member and not sim._definitions[id].combat.get("prepared",false):
			timers[id].auto=automatic
			timers[id].request=false
	if sim.state.phase==GameState.Phase.BATTLE: wake(sim.state.time_usec)

func set_enabled(id: String, enabled: bool) -> bool:
	if not timers.has(id) or not sim._definitions[id].combat.get("prepared", false): return false
	timers[id].enabled = enabled
	sim.state.item_runtime[id].prepared = enabled and timers[id].cd <= 0
	return true

func request(id: String, target_id := "") -> bool:
	if sim.state.phase != GameState.Phase.BATTLE or sim.clock.paused or not timers.has(id) or timers[id].auto or sim._definitions[id].combat.get("prepared", false): return false
	settle(id, sim.state.time_usec)
	if timers[id].entry > 0 or timers[id].cd > 0 or blocked(id,sim.state.time_usec) or sim._owners[id].paralyzed_until>sim.state.time_usec: return false
	timers[id].selection=target_id
	if not sim._can_activate(id): return false
	timers[id].request = true
	wake(sim.state.time_usec)
	return not timers[id].request

func apply_control(member: PartyMemberState, kind: String, scope: String, duration: int, source: String, at: int) -> bool:
	error = ""
	if kind not in CONTROL_NAMES or duration <= 0: return reject("未知控制或无效时长：" + kind)
	if scope not in ["all", "items", "spells", "weapons"] and (not timers.has(scope) or sim._owners[scope] != member): return reject("无效控制目标：" + scope)
	if kind == "disable" and scope != "items" or kind == "silence" and scope != "spells": return reject("禁用只作用全盘道具，沉默只作用全盘法术")
	if kind in ["disrupt", "weakness"] and scope != "all": return reject("该控制必须作用角色全盘")
	if kind == "root" and scope != "weapons": return reject("当前定身只开放地脉震的武器范围")
	var key := member.id + ":" + kind + ":" + scope
	for id: String in timers:
		if sim._owners[id] == member: settle(id, at)
	var until := at + duration
	if kind == "freeze": until = maxi(at, int(controls.get(key, {}).get("until", 0))) + duration
	if kind == "weakness": until = maxi(until, int(controls.get(key, {}).get("until", 0)))
	controls[key] = {"member": member, "kind": kind, "scope": scope, "until": until, "source": source}
	if kind == "freeze" and scope == "all": member.frozen_until = until
	if kind == "weakness": member.temporary_effects.weakness = {"until": until}
	sim.queue.schedule(until, "control_end", {"key": key, "until": until}, -4)
	for id: String in timers:
		if sim._owners[id] == member: sync(id, at)
	sim.t01.emit("control", at, {"target_name": member.definition.name, "status": CONTROL_NAMES[kind], "until": until, "source": source})
	return true

func end_control(payload: Dictionary, at: int) -> void:
	if not controls.has(payload.key) or controls[payload.key].until != payload.until: return
	var c: Dictionary = controls[payload.key]
	for id: String in timers:
		if sim._owners[id] == c.member: settle(id, at)
	controls.erase(payload.key)
	if c.kind == "freeze" and c.scope == "all": c.member.frozen_until = at
	if c.kind == "weakness": c.member.temporary_effects.erase("weakness")
	for id: String in timers:
		if sim._owners[id] != c.member: continue
		if c.kind in ["disable", "silence"] and matches(id, c.scope):
			timers[id].cd = float(full_cd(id))
			timers[id].reactive=9_000_000.0
		sync(id, at)

func clear_control(member: PartyMemberState, scope: String, kinds: Array, at: int) -> void:
	for key: String in controls.keys():
		var c: Dictionary = controls[key]
		if c.member == member and c.kind in kinds and (scope == "all" or scope == c.scope): end_control({"key": key, "until": c.until}, at)
	wake(at)

func cleanse(member: PartyMemberState, at: int) -> void:
	member.paralyzed_until = at
	clear_control(member, "all", ["weakness"], at)

func change_cd(id: String, delta: int, at: int) -> bool:
	if not timers.has(id) or full_cd(id) <= 0 or blocked(id, at): return false
	settle(id, at)
	if timers[id].entry > 0: return false
	timers[id].cd = maxf(0, float(timers[id].cd) + delta)
	sync(id, at)
	return true

func set_speed(id: String, source: String, value: float, at: int) -> bool:
	if not timers.has(id) or not is_finite(value): return false
	settle(id, at)
	timers[id].speed_modifiers[source] = value
	sync(id, at)
	return true

func remaining(id: String, entry := false) -> int:
	if not timers.has(id): return 0
	settle(id, sim.state.time_usec)
	return ceili(timers[id].entry if entry else timers[id].cd)

# Waiting for an affordable manual cast is meaningful; an exhausted board with
# no pending resource recovery must still terminate as a draw.
func has_future_action(id: String, at: int) -> bool:
	if not timers.has(id) or full_cd(id) <= 0: return false
	var member: PartyMemberState = sim._owners[id]
	var item: ItemData = sim._definitions[id]
	if member.hp <= 0 or item.combat.get("prepared", false): return false
	if item.effects_for("on_activate").is_empty(): return false
	var meaningful := false
	for effect: Dictionary in item.effects_for("on_activate"):
		if effect.effect in ["damage","apply_toxin"]: meaningful = true
		if effect.effect in ["restore_capped","restore_instant","restore_ticks"] and effect.get("resource") in ["stamina","spirit"] and member.get(effect.resource) < member.maximum(effect.resource): meaningful = true
		if effect.effect == "apply_status" and effect.status in ["流血","灼烧","毒蚀","润脉"]: meaningful = true
	if item.category == "spell":
		var p := sim.cultivation.data(member,item)
		meaningful = p.damage > 0 or p.opcode in ["command_weapon","weapon_union"]
		for status: Dictionary in p.get("statuses",[]):
			if status.status in ["流血","灼烧","毒蚀","润脉"]: meaningful = true
	if not meaningful: return false
	var cost := sim.t01.costs(member, item, at)
	cost += sim.cultivation.participant_cost(member,id,at)
	if member.stamina < cost.x or member.spirit < cost.y:
		return sim.t01.layers(member, "重伤") > 0 and member.stamina >= item.stamina_cost and member.spirit >= item.spirit_cost
	return true

func reject(message: String) -> bool:
	error = message
	return false

# Only the confirmed single-voucher case is exposed. Multi-voucher stacking and
# external calls remain rejected until their rules have been decided.
func block_next_round(id: String, at: int) -> bool:
	error = ""
	if not timers.has(id) or full_cd(id) <= 0 or sim._definitions[id].category in ["spell", "book"]: return reject("下一轮封锁需要有CD的道具")
	if timers[id].get("block_next", false): return reject("多凭证叠加尚未定案")
	settle(id, at)
	if timers[id].entry > 0: return reject("入阵期间的封锁凭证尚未定案")
	timers[id].block_next = true
	timers[id].block_at_zero = timers[id].cd > 0
	return true

func consume_block(id: String, at: int) -> bool:
	if not timers[id].get("block_next", false): return false
	timers[id].erase("block_next")
	timers[id].erase("block_at_zero")
	restart(id, at)
	sim.t01.emit("cast_interrupted", at, {"item_id":sim._definitions[id].id, "label":"下一轮封锁", "target_name":sim._owners[id].definition.name})
	return true
