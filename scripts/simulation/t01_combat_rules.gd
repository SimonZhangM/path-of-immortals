class_name T01CombatRules
extends RefCounted

# Shared T01 settlement. Owns no nodes, wall clock or UI state. Every clock is
# scheduled through BattleSimulation's stable microsecond queue.
const COUNTERS := {"metal": ["wood", "wind"], "wood": ["wind", "water"], "water": ["fire", "earth"], "fire": ["metal", "wood"], "earth": ["thunder", "fire"], "wind": ["earth", "thunder"], "thunder": ["water", "metal"]}
var _simulation: WeakRef
var sim: BattleSimulation:
	get:
		return _simulation.get_ref()
var rng := RandomNumberGenerator.new()
var forced_rolls: Array[float] = []
var _serial := 0
var _tokens: Dictionary = {}
var defer_thunder := 0

func _init(battle: BattleSimulation) -> void:
	_simulation = weakref(battle)
	rng.seed = 29092026

static func q(value: float) -> float:
	return floorf(maxf(0, value) * 10.0 + 0.50000001) / 10.0

func roll() -> float:
	return forced_rolls.pop_front() if not forced_rolls.is_empty() else rng.randf()

static func rank(member: PartyMemberState) -> int:
	return int(member.cultivation.get("order", member.definition.get("combat_rank", 0)))

static func layers(member: PartyMemberState, status: String) -> int:
	var total := 0
	for batch: Dictionary in member.combat_statuses.get(status, {}).get("batches", []):
		total += int(batch.count)
	return total

static func capacity(member: PartyMemberState) -> int:
	return int(member.definition.get("status_capacity", rank(member) * 10))

static func barrier_capacity(member: PartyMemberState) -> float:
	return float((rank(member) + 1) * 10)

static func resonance_cap(member: PartyMemberState) -> int:
	return maxi(0, rank(member) - 2) * 10

func emit(kind: String, at: int, values: Dictionary = {}) -> void:
	values.merge({"kind": kind, "at_usec": at}, true)
	sim._pending_events.append(values)
	sim.state.revision += 1

func consume(member: PartyMemberState, status: String, amount: int) -> void:
	if not member.combat_statuses.has(status):
		return
	var pool: Dictionary = member.combat_statuses[status]
	while amount > 0 and not pool.batches.is_empty():
		var batch: Dictionary = pool.batches[0]
		var used := mini(amount, int(batch.count))
		batch.count -= used
		amount -= used
		if batch.count == 0:
			pool.batches.pop_front()
	if pool.batches.is_empty():
		member.combat_statuses.erase(status)
		_tokens.erase(member.id + status)

func half_consume(member: PartyMemberState, status: String) -> void:
	var source := member if T01Definition.is_buff(status) else sim.cultivation.status_source(member,status)
	var choices := {"坚韧":["earth","余韧"],"疲惫":["earth","疲势难消"],"轻灵":["wind","留影"],"失衡":["wind","留隙"]}
	var divisor := 3 if choices.has(status) and sim.cultivation.spec(source,choices[status][0],1,choices[status][1]) else 2
	consume(member,status,maxi(1,layers(member,status)/divisor))

func apply_status(member: PartyMemberState, status: String, amount: int, source: PartyMemberState, at: int, thunder_chunk := false, frost_attack := -1) -> bool:
	var element := T01Definition.status_element(status)
	if element.is_empty():
		push_error("Unknown T01 status: " + status)
		sim.configuration_error = "未知状态：" + status
		sim.clock.paused = true
		emit("effect_error", at, {"message": sim.configuration_error})
		return false
	if member == null:
		return false
	if status == "雷蕴" and amount > 1 and not thunder_chunk:
		var applied := false
		while amount > 0:
			var space := capacity(member) - layers(member, status)
			if space <= 0: break
			var chunk := mini(amount, mini(space, maxi(1, 10 - layers(member, status))))
			applied = apply_status(member, status, chunk, source, at, true) or applied
			amount -= chunk
		return applied
	if member.hp <= 0 or amount <= 0 or status == "毒蚀" and at < member.toxin_immune_until_usec:
		return false
	var original_amount := amount
	if status=="寒霜" and layers(member,status)==0 and sim.cultivation.spec(source,"water",1,"初霜"): amount+=1
	if status=="连环" and layers(member,status)==0 and sim.cultivation.spec(source,"thunder",1,"连势"): amount+=2
	if status=="缠绕" and layers(member,status)>0 and sim.cultivation.spec(source,"wood",1,"盘根"): amount+=1
	var accepted := mini(amount, maxi(0, capacity(member if T01Definition.is_buff(status) else source) - layers(member, status)))
	if accepted <= 0:
		return false
	var remaining := accepted
	var opponents: Array = []
	var ties := {}
	for opposite: String in T01Definition.STATUS_GROUPS[element]:
		if T01Definition.is_buff(opposite) == T01Definition.is_buff(status):
			continue
		for batch: Dictionary in member.combat_statuses.get(opposite, {}).get("batches", []):
			var group_key := opposite + str(batch.at)
			if not ties.has(group_key): ties[group_key] = roll()
			opponents.append({"status": opposite, "at": batch.at, "serial": batch.serial, "tie": ties[group_key], "count": batch.count})
	opponents.sort_custom(func(a: Dictionary, b: Dictionary): return a.at < b.at if a.at != b.at else a.tie < b.tie)
	for opposing: Dictionary in opponents:
		var count := mini(remaining, int(opposing.count))
		consume(member, opposing.status, count)
		remaining -= count
		if remaining == 0:
			break
	if remaining > 0:
		var fresh := not member.combat_statuses.has(status)
		if fresh:
			var delay := sim.cultivation.initial_delay(source,status)
			member.combat_statuses[status] = {"batches": [], "start": at + delay, "next": at + delay, "expires": 0, "source_id": source.id}
		var pool: Dictionary = member.combat_statuses[status]
		_serial += 1
		pool.batches.append({"at": at, "serial": _serial, "count": remaining, "source": source.id})
		if status == "寒霜" and frost_attack >= 0 and amount > original_amount:
			pool.batches[-1].frost_attack = frost_attack
			pool.batches[-1].fresh_bonus = mini(remaining,maxi(0,accepted-original_amount))
		pool.source_id = source.id
		if status=="流血" and not fresh and sim.cultivation.spec(source,"metal",1,"血沸"): direct_hp(member,remaining*sim.cultivation.status_strength(source,status),source,at,status)
		if status=="灼烧" and not fresh and sim.cultivation.spec(source,"fire",1,"复燃"): pool.revival_until=at+5_000_000
		if status in ["流血", "灼烧"]:
			pool.expires = (pool.start if fresh else at) + (5_000_000 if status == "流血" else 10_000_000)
		elif status == "破甲":
			pool.next = at + 10_000_000
		elif status == "驱散":
			# Core 4.105: only a fresh pool waits2s; stored remainder wakes1s.
			if not fresh and int(pool.expires) > 0:
				pool.next = at + 1_000_000
				pool.expires = 0
		if status == "雷蕴":
			convert_thunder(member, at)
		schedule_status(member, status)
	if T01Definition.is_buff(status) and layers(member, "驱散") > 0:
		var dispel: Dictionary = member.combat_statuses["驱散"]
		if int(dispel.expires) > 0:
			dispel.next = at + 1_000_000
			dispel.expires = 0
			schedule_status(member, "驱散")
	emit("status_applied", at, {"target_id": member.id, "target_name": member.definition.name, "status": status, "value": accepted, "layers": layers(member, status)})
	return true

func schedule_status(member: PartyMemberState, status: String) -> void:
	if status not in ["生机", "毒蚀", "润脉", "枯脉", "流血", "灼烧", "重伤", "破甲", "驱散"] or not member.combat_statuses.has(status):
		return
	var pool: Dictionary = member.combat_statuses[status]
	var due: int = pool.next
	if int(pool.expires) > 0:
		due = mini(due, int(pool.expires))
	var key := member.id + status
	if _tokens.get(key) == due:
		return
	_tokens[key] = due
	sim.queue.schedule(due, "t01_status", {"member": member, "status": status, "due": due}, -2)

func tick_status(payload: Dictionary, at: int) -> void:
	var member: PartyMemberState = payload.member
	var status: String = payload.status
	var key := member.id + status
	if _tokens.get(key) != at or not member.combat_statuses.has(status) or member.hp <= 0:
		return
	_tokens.erase(key)
	var pool: Dictionary = member.combat_statuses[status]
	if int(pool.expires) > 0 and at >= int(pool.expires):
		consume(member, status, layers(member, status))
		return
	var n := layers(member, status)
	var source: PartyMemberState = sim.state.teams[0][0] if sim.state.teams[0][0].id == pool.source_id else sim.state.teams[1][0]
	pool.next = at + 1_000_000
	sim.cultivation.status_tick(member,status,pool,n,source,at)
	schedule_status(member, status)
	sim.state.revision += 1

func convert_thunder(member: PartyMemberState, at: int) -> void:
	if defer_thunder>0: return
	var maximums := [1, 1, 2, 2, 3, 4]
	var values := [10, 20, 40, 60, 80, 100]
	while layers(member, "雷蕴") >= 10 and member.thunder_shields.size() < maximums[rank(member)]:
		consume(member, "雷蕴", 10)
		member.sword_screen.clear()
		var multiplier := 1+sim.cultivation.bonus(member,"thunder",2,"凝罡",.1)+sim.cultivation.bonus(member,"thunder",4,"雷罡凝实",.2)
		if sim.cultivation.general(member,"thunder",1,"雷罡"): multiplier+=.1
		member.thunder_shields.append(q(values[rank(member)]*multiplier))
		emit("shield_created", at, {"target_name": member.definition.name, "value": member.thunder_shields[-1]})

func active_injury(member: PartyMemberState, at: int) -> int:
	return layers(member, "重伤") if at >= int(member.combat_statuses.get("重伤", {}).get("start", 9223372036854775807)) else 0

func restore(member: PartyMemberState, resource: String, value: float, at: int, ceiling := -1.0) -> float:
	if member.hp <= 0:
		return 0
	if resource == "armor":
		var source := sim.cultivation.status_source(member,"破甲")
		if sim.cultivation.spec(source,"fire",5,"熔甲难复"): value*=maxf(0,1-(layers(member,"破甲")/10)*.1)
	if resource == "hp":
		var prevented := minf(value,active_injury(member,at)*sim.cultivation.injury_strength(member))
		value=maxf(0,value-prevented)
		var source := sim.cultivation.status_source(member,"重伤")
		if prevented>0:
			sim.cultivation.injury_event(source,at)
			if sim.cultivation.spec(source,"earth",5,"伤势反噬"): damage(source,member,prevented*.5,"法术型","base.element.earth",at,{"kind":"derived","label":"伤势反噬"},false,{"special":sim.cultivation.has_special(member)})
		if member.hp<=0: return 0
	var limit := float(member.maximum(resource)) if ceiling < 0 else minf(ceiling, member.maximum(resource))
	var actual := q(minf(value, maxf(0, limit - float(member.get(resource)))))
	member.set(resource, q(float(member.get(resource)) + actual))
	emit("restore", at, {"target_name": member.definition.name, "resource": resource, "value": actual})
	return actual

func costs(member: PartyMemberState, item: ItemData, at: int) -> Vector2:
	var weapons := 0
	for entry: Dictionary in member.inventory.get_instances():
		if sim._registry.get_item(entry.item_id).category == "weapon":
			weapons += 1
	var multiplier: float = 1.0 + maxi(0, weapons - 1) * 0.25
	var injury := active_injury(member, at) * sim.cultivation.injury_strength(member)
	var fee_scale := 1 + float(sim.cultivation.data(member, item).get("cost_pct", 0))
	return Vector2(q(item.stamina_cost * multiplier + injury) if item.stamina_cost > 0 else 0, q(item.spirit_cost * fee_scale + injury) if item.spirit_cost > 0 else 0)

func configuration_issue() -> String:
	var player: PartyMemberState = sim.state.teams[0][0]
	if player.armor_choice_required: return "甲型最高权重并列且不含身甲类型，请从候选中指定：" + "／".join(player.armor_candidates)
	for side in 2:
		var owner: PartyMemberState = sim.state.teams[side][0]
		var target: PartyMemberState = sim.state.teams[1-side][0]
		if rank(owner) == rank(target) or target.defense_element == "base.element.none": continue
		for entry: Dictionary in owner.inventory.get_instances():
			var item := sim._registry.get_item(entry.item_id)
			if item.element != "base.element.none" and (item.category == "spell" and sim.cultivation.data(owner,item).damage > 0 or item.effects.any(func(e: Dictionary): return e.effect == "damage")):
				return "跨境界属性克制尚未定案，此攻击／防御元素组合暂停：" + item.display_name
	return ""

func can_activate(member: PartyMemberState, item: ItemData, at: int) -> bool:
	if item.category == "spell":
		var id := sim.cultivation.instance(member, item.id)
		if id.is_empty() or not sim.cultivation.can_cast(id, at): return false
	var cost := costs(member, item, at)
	if member.hp <= 0 or member.stamina < cost.x or member.spirit < cost.y:
		return false
	if item.combat.get("barrier_full_stop", false) and member.barrier >= barrier_capacity(member):
		return false
	if not item.is_consumable() or item.category == "throwable":
		return true
	if member.temporary_effects.get(item.id, {}).get("until", 0) > at:
		return false
	for e: Dictionary in item.effects_for("on_activate"):
		match e.effect:
			"restore_ticks", "restore_instant":
				if member.get(e.resource) < member.maximum(e.resource):
					return true
			"apply_status":
				if layers(member, e.status) < capacity(member):
					return true
			"resistance":
				return true
			"cleanse_toxin":
				return layers(member, "毒蚀") > 0 or at >= member.toxin_immune_until_usec
	return false

func activate(id: String, at: int) -> void:
	var runtime: Dictionary = sim.state.item_runtime[id]
	var owner: PartyMemberState = sim._owners[id]
	var item: ItemData = sim._definitions[id]
	var side: int = runtime.side
	var cost: Vector2 = runtime.get("fee_override",costs(owner,item,at))
	runtime.erase("fee_override")
	if active_injury(owner,at)>0 and (cost.x>0 or cost.y>0): sim.cultivation.injury_event(sim.cultivation.status_source(owner,"重伤"),at)
	owner.stamina = q(owner.stamina - cost.x)
	owner.spirit = q(owner.spirit - cost.y)
	runtime.activation_count += 1
	var source := {"item_id": item.id, "instance_id": id, "owner_id": owner.id, "owner_name": owner.definition.name, "side": side, "stamina_cost": cost.x, "spirit_cost": cost.y, "kind": "active", "category": item.category}
	var activation := source.duplicate()
	activation.entry = owner.inventory.get_instance(id)
	emit("item_activated", at, activation)
	var target := sim.state.target_for(side)
	var attack: Dictionary = {}
	for e: Dictionary in item.effects_for("on_activate"):
		if e.effect == "damage":
			attack = e.duplicate(true)
			attack.damage_type = e.get("damage_type","钝击")
	var hit := false
	var hp_loss := 0.0
	if not attack.is_empty() and target != null:
		# One pending enhancement per concrete target item, consumed on an actual
		# attack attempt (including a miss), never on an unaffordable cycle.
		attack.value += float(owner.pending_item_attacks.get(item.id, 0))
		owner.pending_item_attacks.erase(item.id)
		var result := attack_item(owner, target, item, attack, at, source)
		hit = result.hit
		hp_loss = result.hp_loss
	for e: Dictionary in item.effects_for("on_activate"):
		match e.effect:
			"prime_item_attack":
				owner.pending_item_attacks[e.target_item] = e.value
				emit("attack_primed", at, {"owner_name": owner.definition.name, "item_id": e.target_item, "value": e.value})
			"damage": pass
			"apply_status":
				if e.status == "寒霜" and not attack.is_empty():
					continue # Applied before the hit's freeze trigger in attack_item.
				if e.gate == "always" or e.gate == "hit" and hit or e.gate == "hp_damage" and hp_loss > 0:
					apply_status(owner if e.target == "self" else target, e.status, e.value, owner, at)
			"restore_capped":
				restore(owner, e.resource, e.value, at, floorf(float(owner.maximum(e.resource)) * e.cap_numerator / e.cap_denominator))
			"restore_instant": restore(owner, e.resource, e.value, at)
			"restore_armor":
				var bonus := link_bonus(owner)
				restore(owner, "armor", e.value + bonus.recovery.get(id, 0), at)
				var stamina_bonus: int = bonus.stamina_recovery.get(id, 0)
				if stamina_bonus > 0: restore(owner, "stamina", stamina_bonus, at)
			"restore_ticks":
				_serial += 1
				owner.temporary_effects[item.id] = {"until": at + roundi(e.interval * e.ticks * 1_000_000), "token": _serial}
				for tick in range(1, int(e.ticks) + 1):
					sim.queue.schedule(at + roundi(tick * float(e.interval) * 1_000_000), "t01_restore", {"member": owner, "resource": e.resource, "value": e.value, "item_id": item.id, "token": _serial}, -3)
					sim._pending_restores += 1
			"cleanse_toxin":
				consume(owner, "毒蚀", layers(owner, "毒蚀"))
				owner.toxin_immune_until_usec = at + roundi(e.duration * 1_000_000)
				owner.temporary_effects.toxin_immunity = {"until": owner.toxin_immune_until_usec}
			"barrier":
				sim.cultivation.add_barrier(owner, e.value, item.id)
				emit("barrier_changed", at, {"target_name": owner.definition.name, "value": owner.barrier})
			"resistance":
				owner.temporary_effects[item.id] = {"until": at + roundi(e.duration * 1_000_000), "element": e.element, "reduction": e.value}
				sim.queue.schedule(at + roundi(e.duration * 1_000_000), "t01_wake", {}, -2)
			_: assert(false, "Unimplemented effect %s on %s" % [e.effect, item.id])
	if item.is_consumable():
		var consumed := owner.inventory.use_consumable(id)
		emit("pill_used", at, {"owner_name": owner.definition.name, "item_id": item.id, "consumed": consumed})
		if owner.inventory.get_instance(id).is_empty():
			sim.detach(id)
			return
	runtime.ready_at_usec = at + item.cooldown_usec
	sim.timeline.restart(id, at)

func attack_item(owner: PartyMemberState, target: PartyMemberState, item: ItemData, attack: Dictionary, at: int, source: Dictionary) -> Dictionary:
	var art := sim.cultivation
	var p: Dictionary = source.get("spell", {})
	var resonance := {}
	var before := {}
	source.pre_paralyzed = target.paralyzed_until > at
	source.missing_ratio = minf(1, art.missing_resources(target) * float(p.get("missing_scale", 1)))
	for element: String in T01Definition.STATUS_GROUPS:
		resonance[element] = art.resonance(owner, target, element)
		for status: String in T01Definition.STATUS_GROUPS[element]: before[status] = layers(target, status)
	source.resonance = resonance
	source.entangle = layers(target, "缠绕")
	source.category = item.category if not source.has("category") else source.category
	var weapon: bool = source.category == "weapon"
	var flame := layers(owner, "附炎")
	source.flame = flame
	consume(owner, "附炎", flame)
	var enchant: Dictionary = {}
	var returned_edge := 0.0
	if weapon:
		if not owner.return_edge.is_empty():
			returned_edge=q(art.barrier_from(owner,owner.return_edge)*.5)
			art.spend_barrier(owner,returned_edge,owner.return_edge)
			owner.return_edge=""
		if not owner.weapon_enchantment.is_empty():
			enchant=owner.weapon_enchantment.duplicate(true)
			owner.weapon_enchantment.clear()
		var force_id := art.prepared(owner,"force_critical",at)
		if not force_id.is_empty(): source.forced=art.trigger(force_id,at)
	var chance := art.hit_chance(owner, target, float(item.combat.get("hit_chance", .95 if item.category == "spell" else .9)) + float(p.get("hit_bonus", 0)), item.element, at)
	var dodge_id := art.prepared(target, "dodge", at)
	var dodge := art.trigger(dodge_id, at) if not dodge_id.is_empty() else {}
	if not dodge.is_empty() or roll() >= chance:
		if not dodge.is_empty():
			if dodge.has("agility"): apply_status(target, "轻灵", dodge.agility, target, at)
			if dodge.has("advance_cd"):
				var chosen := art.cd_target(target, dodge_id, dodge, at)
				if not chosen.is_empty(): sim.timeline.change_cd(chosen, -roundi(dodge.advance_cd * 1_000_000), at)
		else: half_consume(target, "轻灵")
		if art.spec(owner, "fire", 1, "余焰"): apply_status(owner, "附炎", roundi(flame * .5), owner, at)
		art.dodged(target, owner, at)
		emit("miss", at, {"target_name": target.definition.name, "owner_name": owner.definition.name})
		return {"hit": false, "hp_loss": 0.0, "armor_loss": 0.0, "effective": 0.0}
	defer_thunder += 1
	if art.spec(owner, "fire", 5, "火种不灭"): apply_status(owner, "附炎", roundi(flame * .5), owner, at)
	var critical := false
	var critical_scale := 1.5
	var reduction := 0.0
	var forced: Dictionary = source.get("forced",{})
	var guard: Dictionary = {}
	var used_fatigue := 0
	if weapon:
		var fatigue_owner := art.status_source(target,"疲惫")
		var unresisted := .05+layers(target,"疲惫")*(.01+art.bonus(fatigue_owner,"earth",2,"困乏",.004)+art.bonus(fatigue_owner,"earth",4,"疲极",.006))
		var r := 0.0 if not forced.is_empty() else roll()
		var would_critical := not forced.is_empty() or r<clampf(unresisted,0,1)
		var guard_id := art.prepared(target,"guard_critical",at) if would_critical else ""
		if not guard_id.is_empty():
			guard=art.trigger(guard_id,at)
			reduction=guard.get("reduction",0)
		if guard.is_empty():
			if not forced.is_empty():
				critical=true
				if attack.damage_type=="钝击": critical_scale=forced.blunt_critical
			else:
				var tenacity := layers(target,"坚韧")*(.01+art.bonus(target,"earth",2,"固岳",.004)+art.bonus(target,"earth",4,"岳体",.006))
				critical=r<clampf(unresisted-tenacity,0,1)
				if critical:
					used_fatigue=layers(target,"疲惫")
					half_consume(target,"疲惫")
					used_fatigue-=layers(target,"疲惫")
				elif would_critical:
					half_consume(target,"坚韧")
					if art.spec(target,"earth",3,"岳势反镇"): apply_status(owner,"疲惫",1,target,at)
					if art.spec(target,"earth",5,"山岳不倾"): reduction=.2
	_serial += 1
	var frost_attack := _serial
	for e: Dictionary in item.effects_for("on_activate"):
		if e.effect == "apply_status" and e.status == "寒霜": apply_status(target, e.status, e.value, owner, at, false, frost_attack)
	for e: Dictionary in p.get("statuses", []):
		if e.status == "寒霜": apply_status(target, e.status, e.count, owner, at, false, frost_attack)
	var eligible_frost := layers(target,"寒霜")
	for batch: Dictionary in target.combat_statuses.get("寒霜",{}).get("batches",[]):
		if batch.get("frost_attack",-1) == frost_attack: eligible_frost -= mini(batch.count,batch.fresh_bonus)
	if item.element == "base.element.water" and eligible_frost > 0:
		art.trigger_frost(owner, target, at, float(p.get("freeze_extra", 0)) if before["寒霜"] > 0 else 0.0)
	var parts: Array = source.get("components", [{"base": float(attack.value), "original": float(attack.value), "element": item.element, "type": attack.damage_type, "main": true}]).duplicate(true)
	for part: Dictionary in parts:
		if part.main: part.base+=returned_edge
	var primary_total := 0.0
	var components: Array = []
	for part: Dictionary in parts:
		var src := source.duplicate(true)
		src.primary = true
		src.damage_pct = float(src.get("damage_pct", 0)) - reduction
		if weapon and art.spec(owner, "metal", 5, "锋痕入骨"): src.damage_pct += before["锋痕"] * .01
		if not forced.is_empty() and part.type == "钝击": src.damage_pct += forced.blunt_pct
		if p.has("damage_layers"):
			var n := 0
			for status: String in p.damage_layers: n += before[status]
			src.damage_pct += minf(p.layer_cap, n * p.layer_ratio)
		if p.has("missing_scale"):
			var missing := art.missing_resources(target)
			src.damage_pct += minf(1, missing * float(p.missing_scale))
		var adjusted := adjusted_damage(owner, target, part.base, part.type, part.element, at, src, true, critical_scale if critical else 1.0)
		primary_total += adjusted
		src.adjusted = true
		src.critical = critical
		components.append({"value": adjusted, "type": part.type, "element": part.element, "source": src})
		if not enchant.is_empty() and part.main:
			var extra := source.duplicate(true)
			extra.erase("spell")
			extra.damage_pct = -reduction
			extra.adjusted = true
			var raw_extra := source.duplicate(true)
			raw_extra.erase("spell")
			raw_extra.damage_pct = -reduction
			components.append({"value": adjusted_damage(owner, target, part.original * enchant.ratio, "法术型", "base.element.metal", at, raw_extra, true), "type":"法术型", "element":"base.element.metal", "source":extra})
	if flame > 0:
		var flame_source := source.duplicate(true)
		flame_source.erase("spell")
		flame_source.damage_pct = -reduction + art.bonus(owner, "fire", 2, "蕴火", .1) + art.bonus(owner, "fire", 4, "炎势炽盛", .2)
		var value := adjusted_damage(owner, target, flame, "法术型", "base.element.fire", at, flame_source, true)
		flame_source.adjusted = true
		flame_source.flame_packet = true
		components.append({"value":value, "type":"法术型", "element":"base.element.fire", "source":flame_source})
	components.sort_custom(func(a: Dictionary, b: Dictionary): return a.element != "base.element.none" and b.element == "base.element.none")
	var total := 0.0
	for part: Dictionary in components: total += part.value
	var round_context := {"special": not target.thunder_shields.is_empty() or not target.sword_screen.is_empty(), "entangle_used": {}, "defer_recharge": true, "broken": 0, "shield_total": 0.0}
	round_context.allowance = q(total * art.absorption(target))
	var hp_before := target.hp
	var armor_before := target.armor
	allocate_attack_shields(owner,target,components,round_context,at)
	var effective := 0.0
	var post_shield := 0.0
	for part: Dictionary in components:
		if owner.hp <= 0 or target.hp <= 0: break
		round_context.allocated_shield = part.shield_loss
		var result := damage(owner, target, part.value, part.type, part.element, at, part.source, true, round_context)
		effective += result.get("effective", 0)
		post_shield += result.get("post_shield", 0)
	var direct_hp_loss := maxf(0, hp_before - target.hp)
	var armor_loss := maxf(0, armor_before - target.armor)
	round_context.erase("allocated_shield")
	round_context.erase("allowance")
	if weapon and owner.hp > 0 and target.hp > 0 and before["锋痕"] > 0:
		var marks: int = before["锋痕"]
		var retained := roundi(marks * .25) if art.spec(owner, "metal", 1, "留痕") else 0
		consume(target, "锋痕", marks - retained)
		var mark_result := damage(owner, target, marks, "法术型", "base.element.metal", at, {"kind":"derived", "label":"锋痕", "damage_pct":art.bonus(owner,"metal",2,"刻痕",.1)+art.bonus(owner,"metal",4,"深痕",.2)}, false, round_context)
		if mark_result.get("hp_loss",0) > 0 and art.spec(owner,"metal",3,"锋痕见血"): apply_status(target,"流血",1,owner,at)
	art.after_primary(owner,target,item,p,before,{"hit":true,"hp_loss":direct_hp_loss,"armor_loss":armor_loss,"effective":effective,"post_shield":post_shield},source,at,round_context)
	if target.hp > 0 and owner.hp > 0 and post_shield > 0 and weapon and layers(target,"反锋") > 0:
		var n := layers(target,"反锋")
		consume(target,"反锋",n - (roundi(n * .25) if art.spec(target,"metal",1,"回锋") else 0))
		var counter := damage(target,owner,n,"法术型","base.element.metal",at,{"kind":"counter","label":"反锋","damage_pct":art.bonus(target,"metal",2,"蕴锋",.1)+art.bonus(target,"metal",4,"化锋",.2)},false,{"special":art.has_special(owner)})
		if counter.get("hp_loss",0)>0 and art.spec(target,"metal",3,"反锋生痕"): apply_status(owner,"锋痕",1,target,at)
		if art.spec(target,"metal",5,"反锋镇兵") and sim.timeline.timers.has(source.get("instance_id","")): sim.state.item_runtime[source.instance_id].next_cd_extra = 1_000_000
	if target.hp > 0 and owner.hp > 0 and armor_loss > 0:
		var id := art.prepared(target,"armor_counter",at)
		if not id.is_empty():
			var config := art.trigger(id,at)
			if not config.is_empty(): art.counter_attack(target,owner,armor_loss * config.ratio,"earth",config,at)
	if target.hp > 0 and guard.has("tenacity"): apply_status(target,"坚韧",guard.tenacity,target,at)
	if weapon and critical and forced.is_empty() and before["疲惫"] > 0:
		if art.spec(owner,"earth",3,"乏极成伤"): apply_status(target,"重伤",1,owner,at)
		if art.spec(owner,"earth",5,"疲势崩裂") and target.hp>0: damage(owner,target,used_fatigue*2,"法术型","base.element.earth",at,{"kind":"derived","label":"疲势崩裂"},false,{"special":art.has_special(target)})
	if weapon and not forced.is_empty() and forced.has("injury") and effective > 0: apply_status(target,"重伤",forced.injury,owner,at)
	if weapon and enchant.has("bleed") and direct_hp_loss > 0: apply_status(target,"流血",enchant.bleed,owner,at)
	if owner.hp > 0 and target.hp > 0 and weapon: art.followup(owner,target,item,primary_total,at)
	if target.hp > 0 and effective > 0: on_attacked(target,at)
	defer_thunder -= 1
	if target.hp > 0: convert_thunder(target,at)
	if owner.hp > 0: convert_thunder(owner,at)
	return {"hit":true,"hp_loss":direct_hp_loss,"armor_loss":armor_loss,"effective":effective,"post_shield":post_shield}

# An attack shares one shield phase across its attribute/physical components.
# Deduct the complete actual shield loss before reacting; a lethal shield counter
# then cancels every still-unsettled armor/HP component of that same attack.
func allocate_attack_shields(owner: PartyMemberState, target: PartyMemberState, parts: Array, context: Dictionary, at: int) -> void:
	var allowance: float = context.allowance
	var broken := 0
	var screen: Dictionary = {}
	var barrier_before := target.barrier
	var total := 0.0
	for part: Dictionary in parts:
		var available := q(minf(part.value,allowance))
		var absorbed := 0.0
		if context.special and not target.sword_screen.is_empty():
			absorbed = q(minf(target.sword_screen.value,available))
			target.sword_screen.value = q(target.sword_screen.value-absorbed)
			if target.sword_screen.value <= 0:
				screen = target.sword_screen.duplicate(true)
				target.sword_screen.clear()
		elif context.special:
			while available > 0 and not target.thunder_shields.is_empty():
				var used := q(minf(available,target.thunder_shields[0]))
				target.thunder_shields[0] = q(target.thunder_shields[0]-used)
				available = q(available-used)
				absorbed += used
				if target.thunder_shields[0] <= 0:
					target.thunder_shields.pop_front()
					broken += 1
		elif target.barrier > 0:
			absorbed = q(minf(target.barrier,available))
			sim.cultivation.spend_barrier(target,absorbed)
		allowance = q(allowance-absorbed)
		part.shield_loss = absorbed
		total += absorbed
	context.shield_total = total
	context.planned_shield_loss = total
	if not screen.is_empty(): sim.cultivation.shield_broken(target,owner,context,at,screen)
	for i in broken: sim.cultivation.shield_broken(target,owner,context,at)
	if target.barrier < barrier_before: wake_barrier_items(target,at)
	if owner.hp <= 0 and total > 0:
		emit("shield_interrupted",at,{"target_name":target.definition.name,"value":total})

func adjusted_damage(owner: PartyMemberState, target: PartyMemberState, base: float, attack_type: String, element_id: String, at: int, source: Dictionary, active: bool, critical := 1.0) -> float:
	assert(attack_type in EffectSystem.ARMOR_MULTIPLIERS, "Unknown attack type " + attack_type)
	var multiplier := EffectSystem.armor_multiplier(attack_type, target.armor_type)
	var element := element_id.trim_prefix("base.element.")
	var defense := target.defense_element.trim_prefix("base.element.")
	if element != "none" and defense != "none" and rank(owner) == rank(target) and rank(owner) >= 2:
		if defense in COUNTERS.get(element, []):
			multiplier += 0.2
			if sim.cultivation.general(owner,element,2,"乘克"): multiplier += .1
			if source.get("primary",false): multiplier += float(source.get("spell",{}).get("counter_bonus",0))
			if sim.cultivation.general(target,defense,2,"逆克") and target.body_element == "base.element."+defense: multiplier -= .1
		if element in COUNTERS.get(defense, []): multiplier -= 0.2
	if active and T01Definition.STATUS_GROUPS.has(element):
		var cap := resonance_cap(owner)
		var group: Array = T01Definition.STATUS_GROUPS[element]
		var own := layers(owner, group[0]) + (owner.thunder_shields.size() * 10 if element == "thunder" else 0)
		multiplier += source.get("resonance", {}).get(element, sim.cultivation.resonance(owner,target,element))
		if element in ["fire", "thunder"] and layers(target, "缠绕") > 0:
			var binder := sim.cultivation.status_source(target,"缠绕")
			multiplier += int(source.get("entangle", layers(target, "缠绕"))) * .02 * (1+sim.cultivation.bonus(binder,"wood",2,"紧缚",.2)+sim.cultivation.bonus(binder,"wood",4,"盘根愈固",.3))
	if source.get("kind", "active") in ["active", "counter", "followup"]:
		for effect: Dictionary in target.temporary_effects.values():
			if effect.get("element") == element_id and int(effect.until) > at:
				multiplier -= float(effect.reduction)
	multiplier += sim.cultivation.damage_bonus(owner,target,element,attack_type,source,active)
	return q(base if source.get("adjusted", false) else maxf(0, base * multiplier) * critical)

func damage(owner: PartyMemberState, target: PartyMemberState, base: float, attack_type: String, element_id: String, at: int, source: Dictionary, active: bool, round_context: Dictionary, critical := 1.0) -> Dictionary:
	if target.hp <= 0:
		return {}
	var element := element_id.trim_prefix("base.element.")
	var owner_alive := owner.hp>0
	var adjusted := adjusted_damage(owner, target, base, attack_type, element_id, at, source, active, critical)
	if active and element in ["fire", "thunder"] and layers(target, "缠绕") > 0 and not round_context.get("entangle_used", {}).has(element):
		var binder := sim.cultivation.status_source(target,"缠绕")
		var ordinal := sim.cultivation.count(binder,"entangle")
		if not (sim.cultivation.spec(binder,"wood",5,"盘根不绝") and ordinal % 3 == 0): consume(target, "缠绕", 1)
		if sim.cultivation.spec(binder,"wood",3,"缚毒相生"): apply_status(target,"毒蚀",1,binder,at)
		if sim.cultivation.spec(binder,"wood",3,"缠生回息"): apply_status(binder,"生机",1,binder,at)
		if not round_context.has("entangle_used"): round_context.entangle_used = {}
		round_context.entangle_used[element] = true
	var remaining := adjusted
	var shield_loss := 0.0
	var barrier_before := target.barrier
	if round_context.has("allocated_shield"):
		shield_loss = round_context.allocated_shield
	elif round_context.get("special", false) and not target.sword_screen.is_empty():
		shield_loss = q(minf(target.sword_screen.value,minf(adjusted,float(round_context.get("allowance",adjusted*target.sword_screen.absorption)))))
		target.sword_screen.value = q(target.sword_screen.value-shield_loss)
		if target.sword_screen.value <= 0:
			var screen := target.sword_screen.duplicate()
			target.sword_screen.clear()
			sim.cultivation.shield_broken(target,owner,round_context,at,screen)
	elif round_context.get("special", false):
		var allowance := q(minf(adjusted, float(round_context.get("allowance", adjusted * sim.cultivation.absorption(target)))))
		while allowance > 0 and not target.thunder_shields.is_empty():
			var absorb := q(minf(target.thunder_shields[0], allowance))
			target.thunder_shields[0] = q(target.thunder_shields[0] - absorb)
			allowance = q(allowance - absorb)
			shield_loss += absorb
			round_context.shield_total = float(round_context.get("shield_total",0))+absorb
			if target.thunder_shields[0] == 0:
				target.thunder_shields.pop_front()
				sim.cultivation.shield_broken(target,owner,round_context,at)
	elif target.barrier > 0:
		shield_loss = q(minf(target.barrier, minf(adjusted, float(round_context.get("allowance", adjusted * 0.3)))))
		sim.cultivation.spend_barrier(target,shield_loss)
	if round_context.has("allowance"):
		round_context.allowance = q(round_context.allowance - shield_loss)
	remaining = q(remaining - shield_loss)
	if owner_alive and owner.hp <= 0: return {"effective":shield_loss,"adjusted":adjusted,"hp_loss":0.0,"post_shield":0.0}
	var post_shield := remaining
	var p: Dictionary = source.get("spell",{})
	if source.get("primary",false) and target.armor>0:
		if p.has("armor_only"):
			var extra := q(minf(target.armor,remaining*p.armor_only))
			target.armor=q(target.armor-extra)
			emit("armor_only",at,{"value":extra,"target_name":target.definition.name,"label":"裂冰"})
		remaining=q(remaining*(1+float(p.get("armor_bonus",0))))
	var bypass := q(remaining * minf(1, layers(target, "破甲") * (.01+sim.cultivation.bonus(owner,"fire",2,"初熔",.005)+sim.cultivation.bonus(owner,"fire",4,"深熔",.005)))) if active and element == "fire" else 0.0
	var armor_loss := q(minf(target.armor, remaining - bypass))
	target.armor = q(target.armor - armor_loss)
	var health_part := remaining-armor_loss
	if source.get("label")=="灼烧" and sim.cultivation.spec(owner,"fire",5,"灼骨"): health_part*=1.5
	var hp_loss := q(minf(target.hp, health_part))
	target.hp = q(target.hp - hp_loss)
	if hp_loss>0 and source.get("flame_packet",false) and sim.cultivation.spec(owner,"fire",3,"炎入灼痕"): apply_status(target,"灼烧",2,owner,at)
	if bypass>0 and hp_loss>0 and sim.cultivation.spec(owner,"fire",3,"熔火生灼"): apply_status(target,"灼烧",2,owner,at)
	var side := 0 if owner == sim.state.teams[0][0] else 1
	sim.state.damage_totals[side] += hp_loss
	var event := source.duplicate()
	event.damage_type = attack_type
	event.element = element_id
	event.merge({"owner_name": owner.definition.name, "owner_id": owner.id, "side": side, "target_name": target.definition.name, "target_id": target.id, "value": hp_loss, "hp_after": target.hp, "armor_absorbed": armor_loss, "shield_absorbed": shield_loss, "blocked": armor_loss + shield_loss, "adjusted_damage": adjusted, "stamina_cost": source.get("stamina_cost", 0), "label": source.get("label", "" )}, true)
	emit("damage", at, event)
	if barrier_before > target.barrier:
		wake_barrier_items(target, at)
	if adjusted > 0 and target.hp > 0 and source.get("kind", "active") == "active" and not source.has("resonance"):
		on_attacked(target, at)
	if not round_context.get("defer_recharge", false) and target.hp > 0:
		convert_thunder(target, at)
	if target.hp == 0:
		emit("fallen", at, {"target_id": target.id, "target_name": target.definition.name})
	return {"effective": q(shield_loss + armor_loss + hp_loss), "adjusted": adjusted, "hp_loss": hp_loss, "post_shield": post_shield, "armor_loss":armor_loss}

func direct_hp(member: PartyMemberState, amount: float, source: PartyMemberState, at: int, label: String) -> void:
	var actual := q(minf(member.hp, amount))
	member.hp = q(member.hp - actual)
	var side := 0 if source == sim.state.teams[0][0] else 1
	sim.state.damage_totals[side] += actual
	emit("status_damage", at, {"target_id": member.id, "target_name": member.definition.name, "value": actual, "status": label})
	if member.hp == 0:
		emit("fallen", at, {"target_id": member.id, "target_name": member.definition.name})

func paralyze(member: PartyMemberState, at: int) -> void:
	member.paralyzed_until = maxi(member.paralyzed_until, at + 1_000_000)
	sim.queue.schedule(member.paralyzed_until, "t01_wake", {}, -2)
	emit("control", at, {"target_name": member.definition.name, "status": "麻痹", "until": member.paralyzed_until})

func freeze(member: PartyMemberState, duration: int, at: int) -> void:
	sim.timeline.apply_control(member, "freeze", "all", duration, "frost", at)

func on_attacked(member: PartyMemberState, at: int) -> void:
	if member.frozen_until > at:
		return
	for id: String in sim._definitions:
		if sim._owners[id] != member:
			continue
		var rt: Dictionary = sim.state.item_runtime[id]
		if sim.timeline.blocked(id, at, true) or not rt.entered or at < int(rt.get("reactive_ready", 9_000_000)):
			continue
		for e: Dictionary in sim._definitions[id].effects_for("on_attacked"):
			if e.effect == "apply_status" and apply_status(member, e.status, e.value, member, at):
				rt.reactive_ready = at + roundi(e.cooldown * 1_000_000)
				sim.timeline.timers[id].reactive = float(e.cooldown)*1_000_000

func wake_barrier_items(member: PartyMemberState, at: int) -> void:
	for id: String in sim._definitions:
		if sim._owners[id] == member and sim.state.item_runtime[id].get("barrier_stopped", false):
			var rt: Dictionary = sim.state.item_runtime[id]
			rt.barrier_stopped = false
			rt.ready_at_usec = at + sim._definitions[id].cooldown_usec
			sim._schedule(id, rt.ready_at_usec)

func refresh_equipment(member: PartyMemberState, excluded_id: String = "") -> void:
	member.armor_capacity_sources.clear()
	member.armor_type_sources.clear()
	var armor_weights := {}
	var element_weights := {}
	var ordered: Array = member.inventory.get_instances()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary): return a.cell.y < b.cell.y if a.cell.y != b.cell.y else a.cell.x < b.cell.x)
	var body := ""
	member.body_element="base.element.none"
	for entry: Dictionary in ordered:
		if entry.instance_id == excluded_id: continue
		var item := sim._registry.get_item(entry.item_id)
		member.armor_capacity_sources[entry.instance_id] = item.armor_capacity
		if item.category != "armor": continue
		var weight := item.grid_size.x * item.grid_size.y * (2 if item.armor_slot in ["身甲", "衣甲"] else 1)
		armor_weights[item.armor_type] = int(armor_weights.get(item.armor_type, 0)) + weight
		element_weights[item.element] = int(element_weights.get(item.element, 0)) + weight
		if item.armor_slot in ["身甲", "衣甲"]:
			body = item.armor_type
			member.body_element=item.element
	var selected := String(member.definition.get("innate_armor_type", "无甲"))
	var largest := 0
	for armor: String in armor_weights:
		if armor_weights[armor] > largest or armor_weights[armor] == largest and armor == body:
			largest = armor_weights[armor]
			selected = armor
	member.armor_candidates.clear()
	for armor: String in armor_weights:
		if armor_weights[armor] == largest: member.armor_candidates.append(armor)
	var needs_choice: bool = member == sim.state.teams[0][0] and member.armor_candidates.size() > 1 and body not in member.armor_candidates
	member.armor_choice_required = needs_choice and member.armor_choice not in member.armor_candidates
	if needs_choice and not member.armor_choice_required: selected = member.armor_choice
	member.armor_type_sources.t01 = selected
	member.defense_element = "base.element.none"
	largest = 0
	for element: String in element_weights:
		if element_weights[element] > largest:
			largest = element_weights[element]
			member.defense_element = element
	member.armor_capacity_sources.t01_link = link_bonus(member, excluded_id).capacity
	member.armor = minf(member.armor, member.maximum("armor"))

func link_bonus(member: PartyMemberState, excluded_id: String = "") -> Dictionary:
	var result := {"capacity": 0, "recovery": {}, "stamina_recovery": {}}
	var groups := {}
	for entry: Dictionary in member.inventory.get_instances():
		if entry.instance_id == excluded_id: continue
		var item := sim._registry.get_item(entry.item_id)
		var lineage: String = item.combat.get("lineage", "")
		if lineage.is_empty(): continue
		if not groups.has(lineage): groups[lineage] = {}
		if not groups[lineage].has(item.armor_slot): groups[lineage][item.armor_slot] = []
		groups[lineage][item.armor_slot].append({"entry": entry, "item": item})
	for lineage: String in groups:
		var group: Dictionary = groups[lineage]
		if not group.has_all(["身甲", "护具·臂", "护具·腿"]): continue
		var body: Dictionary = group["身甲"][0]
		var low: bool = body.item.quality == "下品"
		var valid := true
		for slot in ["护具·臂", "护具·腿"]:
			var selected: Dictionary = {}
			# Keep all same-slot accessories; a remote extra must not mask a
			# touching member. Inventory order selects one stable valid trio.
			for part: Dictionary in group[slot]:
				if _link_adjacent(body, part):
					selected = part
					break
			if selected.is_empty():
				valid = false
				break
			low = low or selected.item.quality == "下品"
		if valid:
			var iron := lineage == "t01.lineage.iron_armor"
			var reward: Dictionary = body.item.combat.get("link_reward", {})
			result.capacity += int(reward.get("capacity", (3 if low else 4) if iron else (2 if low else 3)))
			result.recovery[body.entry.instance_id] = int(reward.get("recovery", 2 if iron else 1))
			if int(reward.get("stamina",0)) > 0:
				result.stamina_recovery[body.entry.instance_id] = int(reward.stamina)
	return result

static func _link_adjacent(body: Dictionary, part: Dictionary) -> bool:
	var body_rect := Rect2i(body.entry.cell, body.item.grid_size)
	var part_rect := Rect2i(part.entry.cell, part.item.grid_size)
	for y in body_rect.size.y:
		for x in body_rect.size.x:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if part_rect.has_point(body_rect.position + Vector2i(x, y) + offset): return true
	return false
