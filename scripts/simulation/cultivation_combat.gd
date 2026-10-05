class_name CultivationCombat
extends RefCounted

var _simulation: WeakRef
var sim: BattleSimulation:
	get: return _simulation.get_ref()
var rules: T01CombatRules:
	get: return sim.t01
var counters: Dictionary = {}
var pending_delays: Dictionary = {}

func _init(battle: BattleSimulation) -> void:
	_simulation = weakref(battle)

func spec(member: PartyMemberState, element: String, stage: int, choice: String) -> bool:
	return member.knowledge.branch("base.cultivation_book.%s_03" % element, stage) == choice

func general(member: PartyMemberState, element: String, stage: int, choice: String) -> bool:
	var book := "base.cultivation_book.%s_02" % element
	if member.knowledge.branch(book, stage) != choice: return false
	for id: String in sim._definitions:
		if sim._owners[id] == member and sim._definitions[id].id == book and not sim.timeline.blocked(id, sim.state.time_usec, true): return true
	return false

func data(member: PartyMemberState, item: ItemData) -> Dictionary:
	return sim._registry.library.resolved(member, item.id) if item.category == "spell" else {}

func bonus(member: PartyMemberState, element: String, stage: int, choice: String, value: float) -> float:
	return value if spec(member, element, stage, choice) else 0.0

func count(member: PartyMemberState, key: String) -> int:
	var name := member.id + ":" + key
	counters[name] = int(counters.get(name, 0)) + 1
	return counters[name]

func source_for(member: PartyMemberState) -> PartyMemberState:
	return sim.state.teams[1][0] if member == sim.state.teams[0][0] else sim.state.teams[0][0]

func status_source(member: PartyMemberState, status: String) -> PartyMemberState:
	var id: String = member.combat_statuses.get(status, {}).get("source_id", member.id)
	for team: Array in sim.state.teams:
		if team[0].id == id: return team[0]
	return member

func ordered(member: PartyMemberState) -> Array:
	var entries := member.inventory.get_instances()
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return a.cell.y < b.cell.y if a.cell.y != b.cell.y else a.cell.x < b.cell.x)
	return entries

func weapons(member: PartyMemberState, at: int) -> Array:
	var result: Array = []
	for entry: Dictionary in ordered(member):
		if sim._definitions.has(entry.instance_id) and sim._definitions[entry.instance_id].category == "weapon" and not sim.timeline.blocked(entry.instance_id, at, true): result.append(entry.instance_id)
	return result

func weapon_attack(item: ItemData) -> Dictionary:
	for e: Dictionary in item.effects:
		if e.effect == "damage":
			var result := e.duplicate(true)
			result.damage_type = e.get("damage_type","钝击")
			return result
	return {}

func strongest(ids: Array) -> String:
	var best := ""
	var value := -1.0
	for id: String in ids:
		var amount := float(weapon_attack(sim._definitions[id]).get("value", 0))
		if amount > value: best = id; value = amount
	return best

func cd_target(owner: PartyMemberState, caster: String, params: Dictionary, at: int, selection := "") -> String:
	var enemy := params.has("delay_cd")
	var target := source_for(owner) if enemy else owner
	for entry: Dictionary in ordered(target):
		var id: String = entry.instance_id
		if not selection.is_empty() and id != selection: continue
		if id == caster or not sim.timeline.timers.has(id) or sim.timeline.full_cd(id) <= 0 or sim.timeline.blocked(id, at): continue
		var item: ItemData = sim._definitions[id]
		if not enemy:
			var p := data(target, item)
			if p.has("advance_cd") or p.get("opcode") == "change_cd": continue
			if sim.timeline.remaining(id) <= 0 or sim.timeline.remaining(id, true) > 0: continue
			if params.get("opcode") == "dodge" and "穿刺" not in item.tags: continue
			if params.get("name") == "清风涤尘" and not (item.category == "weapon" and "穿刺" in item.tags or item.category == "spell" and item.element == "base.element.wind"): continue
		return id
	return ""

func can_cast(id: String, at: int) -> bool:
	var owner: PartyMemberState = sim._owners[id]
	var p := data(owner, sim._definitions[id])
	if p.is_empty(): return false
	if p.opcode == "change_cd": return not cd_target(owner, id, p, at, sim.timeline.timers[id].selection).is_empty()
	if p.opcode in ["command_weapon", "weapon_union", "weapon_barrier"]:
		var ids := weapons(owner, at)
		if ids.is_empty(): return false
		var cost := rules.costs(owner, sim._definitions[id], at)
		if p.opcode == "weapon_barrier": return true
		if p.opcode == "command_weapon": ids = selected_weapons(owner,id,at)
		if ids.is_empty(): return false
		cost += participant_cost(owner, id, at)
		return owner.stamina >= rules.q(cost.x) and owner.spirit >= rules.q(cost.y)
	return true

func activation_source(id: String, at: int) -> Dictionary:
	var member: PartyMemberState = sim._owners[id]
	var item: ItemData = sim._definitions[id]
	var cost: Vector2 = sim.state.item_runtime[id].get("fee_override",rules.costs(member,item,at))
	sim.state.item_runtime[id].erase("fee_override")
	if rules.active_injury(member,at)>0 and (cost.x>0 or cost.y>0): injury_event(status_source(member,"重伤"),at)
	member.stamina = rules.q(member.stamina - cost.x)
	member.spirit = rules.q(member.spirit - cost.y)
	sim.state.item_runtime[id].activation_count += 1
	var src := {"kind": "active", "item_id": item.id, "instance_id": id, "owner_id": member.id, "owner_name": member.definition.name, "side": sim.state.item_runtime[id].side, "category": item.category, "label": item.display_name, "stamina_cost": cost.x, "spirit_cost": cost.y, "spell": data(member, item)}
	var event := src.duplicate(true)
	event.entry = member.inventory.get_instance(id)
	rules.emit("item_activated", at, event)
	return src

func cast(id: String, at: int) -> void:
	var owner: PartyMemberState = sim._owners[id]
	var item: ItemData = sim._definitions[id]
	var p := data(owner, item)
	var fees: Dictionary = sim.state.item_runtime[id].get("participant_fees", participant_fees(owner, id, at))
	sim.state.item_runtime[id].erase("participant_fees")
	var src := activation_source(id, at)
	var target := source_for(owner)
	match p.opcode:
		"attack": spell_attack(owner, target, item, p, src, at)
		"status": statuses(owner, target, p, {"hit": true}, at)
		"heal":
			rules.restore(owner, "hp", p.heal * (1 + float(p.get("heal_pct", 0)) + healing_bonus(owner, "wood")), at)
			statuses(owner, target, p, {"hit": true}, at)
		"sword_screen":
			if not owner.thunder_shields.is_empty():
				target.paralyzed_until = maxi(target.paralyzed_until, at + owner.thunder_shields.size() * 1_000_000)
				owner.thunder_shields.clear()
			owner.sword_screen = {"value": float(p.shield), "counter": float(p.get("counter", 0)), "absorption": float(p.absorption)}
		"enchant": owner.weapon_enchantment = p.duplicate(true)
		"weapon_barrier":
			var weapon := strongest(weapons(owner, at))
			add_barrier(owner, float(weapon_attack(sim._definitions[weapon]).value) * p.ratio, item.id)
			if p.get("return_edge", false): owner.return_edge = item.id
		"command_weapon", "weapon_union":
			var ids := weapons(owner, at)
			if p.opcode == "command_weapon": ids = selected_weapons(owner,id,at)
			var main := strongest(ids)
			var parts: Array = []
			var inherited: Array = []
			for weapon: String in ids:
				var def: ItemData = sim._definitions[weapon]
				var cost: Vector2 = fees[weapon]
				owner.stamina = rules.q(owner.stamina - rules.q(cost.x))
				owner.spirit = rules.q(owner.spirit - rules.q(cost.y))
				var a := weapon_attack(def)
				var ratio := float(p.main_ratio if weapon == main else p.other_ratio) if p.opcode == "weapon_union" else 1.0
				parts.append({"base": a.value * ratio, "element": def.element, "type": a.damage_type, "main": weapon == main, "original": a.value})
				for effect: Dictionary in def.effects:
					if effect.effect == "apply_status": inherited.append(effect)
			src.category = "weapon"
			src.components = parts
			src.damage_pct = p.get("weapon_pct", 0)
			var result := rules.attack_item(owner, target, sim._definitions[main], weapon_attack(sim._definitions[main]), at, src)
			for effect: Dictionary in inherited:
				if effect.gate == "hit" and result.hit or effect.gate == "hp_damage" and result.hp_loss > 0 or effect.gate == "always": rules.apply_status(owner if effect.target == "self" else target, effect.status, effect.value, owner, at)
		"change_cd":
			var chosen := cd_target(owner, id, p, at, sim.timeline.timers[id].selection)
			sim.timeline.change_cd(chosen, roundi((p.delay_cd if p.has("delay_cd") else -p.advance_cd) * 1_000_000), at)
		_:
			push_error("Prepared spell cannot be directly cast: " + p.opcode)
	sim.timeline.restart(id, at)

func spell_attack(owner: PartyMemberState, target: PartyMemberState, item: ItemData, p: Dictionary, src: Dictionary, at: int) -> Dictionary:
	src.spell = p
	var result := rules.attack_item(owner, target, item, {"value": p.damage, "damage_type": "法术型"}, at, src)
	if result.hit: statuses(owner, target, p, result, at)
	return result

func statuses(owner: PartyMemberState, target: PartyMemberState, p: Dictionary, result: Dictionary, at: int) -> void:
	for entry: Dictionary in p.get("statuses", []):
		if entry.status == "寒霜" and p.damage > 0: continue
		var recipient := owner if entry.target == "self" else target
		if entry.gate == "always" or entry.gate == "hit" and result.hit or entry.gate == "hp_damage" and result.get("hp_loss", 0) > 0 or entry.gate == "armor_damage" and result.get("armor_loss", 0) > 0:
			var accepted := rules.apply_status(recipient, entry.status, entry.count, owner, at)
			if accepted and recipient.combat_statuses.has(entry.status):
				var pool: Dictionary = recipient.combat_statuses[entry.status]
				if entry.status == "枯脉" and p.has("wither_resource"):
					if not pool.has("participants"): pool.participants = {}
					pool.participants[owner.id + ":" + p.wither_resource] = p.wither_resource
				if entry.status == "驱散" and p.has("dispel_bonus"): pool.batches[-1].dispel_bonus = p.dispel_bonus
				if entry.status == "驱散" and p.has("advance_cd"):
					var caster := instance(owner, p.id)
					var chosen := cd_target(owner, caster, p, at)
					if not chosen.is_empty(): sim.timeline.change_cd(chosen, -roundi(p.advance_cd * 1_000_000), at)

func instance(member: PartyMemberState, item_id: String) -> String:
	for id: String in sim._definitions:
		if sim._owners[id] == member and sim._definitions[id].id == item_id: return id
	return ""

func prepared(member: PartyMemberState, opcode: String, at: int) -> String:
	if member.hp <= 0 or member.paralyzed_until > at: return ""
	for entry: Dictionary in ordered(member):
		var id: String = entry.instance_id
		if not sim.timeline.timers.has(id) or sim._definitions[id].combat.get("opcode") != opcode: continue
		var t: Dictionary = sim.timeline.timers[id]
		sim.timeline.settle(id, at)
		if t.get("triggering",false) or not t.enabled or t.entry > 0 or t.cd > 0 or sim.timeline.blocked(id, at): continue
		var cost := rules.costs(member, sim._definitions[id], at)
		if member.stamina >= cost.x and member.spirit >= cost.y: return id
	return ""

func trigger(id: String, at: int) -> Dictionary:
	var p := data(sim._owners[id], sim._definitions[id])
	sim.timeline.timers[id].triggering = true
	var allowed := tax_attempt(id, at)
	sim.timeline.timers[id].triggering = false
	if not allowed: return {}
	activation_source(id, at)
	sim.timeline.restart(id, at)
	return p

func add_barrier(member: PartyMemberState, value: float, source: String) -> float:
	var actual := rules.q(minf(value, maxf(0, rules.barrier_capacity(member) - member.barrier)))
	member.barrier = rules.q(member.barrier + actual)
	if actual > 0: member.barrier_sources.append({"source": source, "value": actual})
	return actual

func spend_barrier(member: PartyMemberState, amount: float, source := "") -> float:
	amount = minf(amount,member.barrier)
	var remaining := amount
	# Existing ordinary barriers loaded without attribution remain spendable, but
	# can never be borrowed by the weapon-barrier branch.
	var batches := member.barrier_sources.duplicate()
	if source.is_empty():
		var tracked := 0.0
		for batch: Dictionary in batches: tracked += batch.value
		remaining = maxf(0,remaining-maxf(0,member.barrier-tracked))
		# Core 1.22: damage consumes all other origins before weapon conversion.
		batches = batches.filter(func(b: Dictionary): return b.source != "base.spell.metal_07") + batches.filter(func(b: Dictionary): return b.source == "base.spell.metal_07")
	for batch: Dictionary in batches:
		if not source.is_empty() and batch.source != source: continue
		var used := minf(remaining, batch.value)
		batch.value = rules.q(batch.value - used)
		remaining = rules.q(remaining - used)
		if remaining <= 0: break
	member.barrier_sources = member.barrier_sources.filter(func(b: Dictionary): return b.value > 0)
	var spent := amount if source.is_empty() else amount - remaining
	member.barrier = rules.q(member.barrier - spent)
	return spent

func barrier_from(member: PartyMemberState, source: String) -> float:
	var total := 0.0
	for b: Dictionary in member.barrier_sources:
		if b.source == source: total += b.value
	return total

func healing_bonus(member: PartyMemberState, element: String) -> float:
	var other := source_for(member)
	var value := 0.0
	if general(member, element, 1, "木息" if element == "wood" else "流息"): value += .1
	if element == "wood" and general(member, element, 5, "生杀并济") and rules.layers(member, "生机") > 0 and (rules.layers(other, "毒蚀") > 0 or rules.layers(other, "缠绕") > 0): value += .1
	if element == "water" and general(member, element, 5, "玄水两仪") and rules.layers(member, "润脉") > 0 and (rules.layers(other, "枯脉") > 0 or rules.layers(other, "寒霜") > 0): value += .1
	return value

func injury_strength(member: PartyMemberState) -> float:
	var source := status_source(member, "重伤")
	return 1 + bonus(source, "earth", 2, "沉伤", .2) + bonus(source, "earth", 4, "伤元", .3)

func resonance(owner: PartyMemberState, target: PartyMemberState, element: String) -> float:
	var group: Array = T01Definition.STATUS_GROUPS[element]
	var cap := rules.resonance_cap(owner)
	var own := rules.layers(owner, group[0]) + (owner.thunder_shields.size() * 10 if element == "thunder" else 0)
	var internal := .015 if general(owner, element, 3, "内鸣") else .01
	var external := .0125 if general(owner, element, 3, "外鸣") else .01
	return mini(cap, own) * internal + (mini(cap, rules.layers(target, group[1])) + mini(cap, rules.layers(target, group[2]))) * external

func damage_bonus(owner: PartyMemberState, target: PartyMemberState, element: String, attack_type: String, source: Dictionary, active: bool) -> float:
	var value := float(source.get("damage_pct", 0))
	var p: Dictionary = source.get("spell", {})
	if source.get("primary", false): value += float(p.get("damage_pct", 0))
	if active:
		var first := {"metal":"锐金", "wood":"木锋", "water":"水锋", "fire":"烈火", "earth":"坤击", "wind":"风锋", "thunder":"霆威"}
		if element in first and general(owner, element, 1, first[element]): value += .1
		if element == "none" and source.get("category") == "weapon":
			if general(owner, "metal", 1, "兵心"): value += .1
			if attack_type == "钝击" and general(owner, "earth", 1, "重兵"): value += .1
		if element == "wood" and general(owner, element, 5, "生杀并济") and rules.layers(owner, "生机") > 0 and (rules.layers(target, "毒蚀") > 0 or rules.layers(target, "缠绕") > 0): value += .1
		if element == "water" and general(owner, element, 5, "玄水两仪") and rules.layers(owner, "润脉") > 0 and (rules.layers(target, "枯脉") > 0 or rules.layers(target, "寒霜") > 0): value += .1
		if element == "fire" and general(owner, element, 1, "蓄炎") and source.get("flame", 0) > 0: value += .1
	if element == "thunder" and target.definition.get("race", "") in ["ghost", "demon", "monster", "鬼", "鬼物", "妖", "妖族", "魔", "魔族"]:
		value += .2 + (float(p.get("race_bonus", 0)) if source.get("primary", false) else 0.0)
	if source.get("kind", "active") in ["active", "counter", "followup"] and owner.temporary_effects.get("weakness", {}).get("until", 0) > sim.state.time_usec: value -= .2
	return value

func hit_chance(owner: PartyMemberState, target: PartyMemberState, base: float, element: String, at: int) -> float:
	var imbalance := status_source(target, "失衡")
	var attack := rules.layers(target,"失衡") * (.01+bonus(imbalance,"wind",2,"破衡",.004)+bonus(imbalance,"wind",4,"失势",.006))
	var evade := rules.layers(target,"轻灵") * (.01+bonus(target,"wind",2,"轻身",.004)+bonus(target,"wind",4,"无影",.006))
	if general(target,"wind",1,"灵行"): evade += .1
	if element == "base.element.wind" and general(owner,"wind",1,"灵行"): attack += .1
	if owner.temporary_effects.get("wind_accuracy",{}).get("until",0)>at: attack += .1
	return clampf(base + attack - evade,0,1)

func dodged(member: PartyMemberState, attacker: PartyMemberState, at: int) -> void:
	if spec(member,"wind",3,"避实成隙"): rules.apply_status(attacker,"失衡",2,member,at)
	if spec(member,"wind",5,"乘风留影"): member.temporary_effects.wind_accuracy = {"until":at+10_000_000}

func trigger_frost(owner: PartyMemberState, target: PartyMemberState, at: int, extra: float) -> void:
	var n := count(owner,"frost")
	var retained := spec(owner,"water",2,"凝霜") and n % 5 == 0
	if not retained and spec(owner,"water",5,"寒潮留霜"): retained = rules.roll() < .2
	if not retained: rules.consume(target,"寒霜",1)
	rules.freeze(target,roundi((.5+bonus(owner,"water",4,"玄霜",.5)+extra)*1_000_000),at)
	if spec(owner,"water",3,"霜回活水"): rules.apply_status(owner,"润脉",1,owner,at)

func missing_resources(member: PartyMemberState) -> float:
	var n := 0
	var value := 0.0
	for r in ["stamina","spirit"]:
		if member.maximum(r)>0:
			n += 1
			value += 1 - float(member.get(r))/member.maximum(r)
	return value / n if n>0 else 0.0

func has_special(member: PartyMemberState) -> bool:
	return not member.thunder_shields.is_empty() or not member.sword_screen.is_empty()

func absorption(member: PartyMemberState) -> float:
	if not member.sword_screen.is_empty(): return member.sword_screen.absorption
	if not member.thunder_shields.is_empty(): return .8 if spec(member,"thunder",4,"雷罡凝实") else .6
	return .3

func counter_attack(owner: PartyMemberState, target: PartyMemberState, value: float, element: String, p: Dictionary, at: int) -> void:
	if owner.hp<=0 or target.hp<=0: return
	if rules.roll() >= hit_chance(owner,target,.95,"base.element."+element,at):
		rules.half_consume(target,"轻灵")
		dodged(target,owner,at)
		return
	var add := float(p.get("damage_pct",0))
	if element=="thunder" and general(owner,"thunder",1,"雷罡"): add+=.2
	var result := rules.damage(owner,target,value,"法术型","base.element."+element,at,{"kind":"counter","label":p.get("name","返剑"),"damage_pct":add},false,{"special":has_special(target)})
	result.hit=true
	statuses(owner,target,p,result,at)

func shield_broken(defender: PartyMemberState, attacker: PartyMemberState, context: Dictionary, at: int, screen: Dictionary = {}) -> void:
	if not screen.is_empty():
		if float(screen.get("counter",0))>0: counter_attack(defender,attacker,screen.counter,"metal",{},at)
		return
	var duration := 1_500_000 if general(defender,"thunder",1,"雷罡") else 1_000_000
	attacker.paralyzed_until = maxi(attacker.paralyzed_until,at+duration)
	sim.queue.schedule(attacker.paralyzed_until,"t01_wake",{},-2)
	# Conversion waits until the whole incoming attack has finished.
	rules.defer_thunder+=1
	if spec(defender,"thunder",1,"回蕴"): rules.apply_status(defender,"雷蕴",3,defender,at,true)
	rules.defer_thunder-=1
	if spec(defender,"thunder",3,"盾破留印"): rules.apply_status(attacker,"雷印",2,defender,at)
	if not context.get("shield_counter_done",false):
		context.shield_counter_done=true
		if spec(defender,"thunder",5,"雷罡反震"):
			counter_attack(defender,attacker,float(context.get("planned_shield_loss",context.get("shield_total",0)))*.5,"thunder",{"name":"雷罡反震"},at)
		var id := prepared(defender,"thunder_counter",at)
		if not id.is_empty() and attacker.hp>0:
			var p := trigger(id,at)
			if not p.is_empty(): counter_attack(defender,attacker,p.damage,"thunder",p,at)

func after_primary(owner: PartyMemberState, target: PartyMemberState, item: ItemData, p: Dictionary, before: Dictionary, result: Dictionary, source: Dictionary, at: int, context: Dictionary) -> void:
	if owner.hp<=0: return
	if target.hp>0 and p.has("burst_status") and int(before[p.burst_status])>0 and (not p.get("burst_armor_only",false) or result.post_shield>0):
		var value: float = before[p.burst_status]*p.burst_ratio
		if p.get("burst_armor_only",false):
			var adjusted := rules.adjusted_damage(owner,target,value,"法术型",item.element,at,{"kind":"derived","damage_pct":p.get("burst_pct",0)},false)
			var actual := rules.q(minf(target.armor,adjusted))
			target.armor=rules.q(target.armor-actual)
			rules.emit("armor_only",at,{"value":actual,"target_name":target.definition.name,"label":"熔爆"})
		else: rules.damage(owner,target,value,"法术型",item.element,at,{"kind":"derived","label":p.name,"damage_pct":p.get("burst_pct",0)},false,context)
	if item.element=="base.element.fire" and result.armor_loss>0 and before["破甲"]>0 and spec(owner,"fire",1,"熔痕") and target.combat_statuses.has("破甲"):
		target.combat_statuses["破甲"].next=at+10_000_000
		rules.schedule_status(target,"破甲")
	if p.has("drain_spirit"):
		var drained := minf(target.spirit,p.drain_spirit)
		target.spirit=rules.q(target.spirit-drained)
		if p.has("drain_return"): rules.restore(owner,"spirit",drained*p.drain_return,at)
	if p.has("life_per_hp") and result.hp_loss>0: rules.apply_status(owner,"生机",maxi(1,roundi(result.hp_loss*p.life_per_hp)),owner,at)
	if p.has("poison_entangle") and before["毒蚀"]>0: rules.apply_status(target,"缠绕",p.poison_entangle,owner,at)
	if target.hp>0 and p.has("root"): sim.timeline.apply_control(target,"root","weapons",roundi(p.root*1_000_000),owner.id,at)
	if p.get("refresh_fire",false):
		for status in ["灼烧","破甲"]:
			if target.combat_statuses.has(status):
				var pool: Dictionary = target.combat_statuses[status]
				if status=="灼烧": pool.expires=at+10_000_000
				else: pool.next=at+10_000_000
				rules.schedule_status(target,status)
	if p.has("paralysis_extension") and source.get("pre_paralyzed",false):
		target.paralyzed_until+=roundi(p.paralysis_extension*1_000_000)
		sim.queue.schedule(target.paralyzed_until,"t01_wake",{},-2)
	if p.get("return_resources",false):
		var portion: float = result.effective * source.get("missing_ratio",0) / (1+source.get("missing_ratio",0))
		var a := float(owner.spirit)/owner.maximum("spirit") if owner.maximum("spirit")>0 else 0.0
		var b := float(owner.stamina)/owner.maximum("stamina") if owner.maximum("stamina")>0 else 0.0
		var share := b/(a+b) if a+b>0 else .5
		rules.restore(owner,"spirit",portion*share,at)
		rules.restore(owner,"stamina",portion*(1-share),at)
	if result.hp_loss>0 and before["流血"]>0 and spec(owner,"metal",5,"血势不绝"): rules.apply_status(target,"流血",1,owner,at)
	if item.element=="base.element.thunder" and result.effective>0: lightning(owner,target,p,at,context)

func lightning(owner: PartyMemberState, target: PartyMemberState, p: Dictionary, at: int, context: Dictionary) -> void:
	var strikes := 0
	if rules.layers(target,"雷印")>=10:
		strikes=2 if rules.layers(target,"雷印")>=20 and spec(owner,"thunder",5,"双霆引印") else 1
	var new_chain := 0
	for i in strikes:
		if owner.hp<=0 or target.hp<=0 or rules.layers(target,"雷印")<10: break
		rules.consume(target,"雷印",10)
		var highest := 0.0
		for entry: Dictionary in owner.inventory.get_instances():
			var def := sim._registry.get_item(entry.item_id)
			if def.category=="spell":
				var candidate := data(owner,def)
				highest=maxf(highest,float(candidate.damage)*(1+float(candidate.get("damage_pct",0))))
			elif def.category in ["weapon","artifact"]: highest=maxf(highest,float(weapon_attack(def).get("value",0)))
		var add := bonus(owner,"thunder",2,"震印",.1)+bonus(owner,"thunder",4,"雷印震威",.2)+float(p.get("strike_bonus",0))
		rules.damage(owner,target,highest*1.5,"法术型","base.element.thunder",at,{"kind":"derived","label":"雷击","damage_pct":add},false,context)
		rules.paralyze(target,at)
		if spec(owner,"thunder",1,"留印"): rules.apply_status(target,"雷印",3,owner,at)
		if spec(owner,"thunder",3,"雷击成环"): new_chain+=2
	var chains := (1 if strikes>0 else 2) if p.get("extra_chain",false) else (0 if strikes>0 else 1)
	for i in chains:
		if owner.hp<=0 or target.hp<=0 or rules.layers(target,"连环")<=0: break
		var n := rules.layers(target,"连环")
		var ordinal := count(owner,"chain")
		if not (spec(owner,"thunder",5,"连霆不绝") and ordinal%5==0): rules.consume(target,"连环",1)
		var add := bonus(owner,"thunder",2,"连霆",.1)+bonus(owner,"thunder",4,"连霆增势",.2)
		if p.get("extra_chain",false) and (strikes>0 or i==1): add+=float(p.get("chain_bonus",0))
		rules.damage(owner,target,n*2,"法术型","base.element.thunder",at,{"kind":"derived","label":"连环","damage_pct":add},false,context)
		if spec(owner,"thunder",3,"连环回蕴"): rules.apply_status(owner,"雷蕴",1,owner,at)
	if new_chain>0 and target.hp>0: rules.apply_status(target,"连环",new_chain,owner,at)

func followup(owner: PartyMemberState, target: PartyMemberState, item: ItemData, first: float, at: int) -> void:
	var id := prepared(owner,"followup",at)
	var guaranteed := not id.is_empty()
	var chance := .35 if general(owner,"wind",1,"灵行") else .25
	if not guaranteed and (rules.layers(target,"失衡")<=0 or rules.roll()>=chance): return
	var p := trigger(id,at) if guaranteed else {}
	if guaranteed and p.is_empty(): return
	if rules.roll()>=hit_chance(owner,target,float(item.combat.get("hit_chance",.9))+float(p.get("followup_hit",0)),item.element,at):
		rules.half_consume(target,"轻灵")
		dodged(target,owner,at)
		return
	var pierce := "穿刺" in item.tags
	var ratio := .5+float(p.get("followup_bonus",0))+(float(p.get("pierce_bonus",0)) if pierce else 0.0)
	if spec(owner,"wind",5,"逐影连锋"): ratio+=.5 if pierce else .25
	if not guaranteed: rules.half_consume(target,"失衡")
	rules.damage(owner,target,first*ratio,weapon_attack(item).damage_type,item.element,at,{"kind":"followup","adjusted":true,"label":"追风式" if guaranteed else "失衡追击"},false,{"special":has_special(target)})
	if spec(owner,"wind",3,"乘隙化影"): rules.apply_status(owner,"轻灵",2,owner,at)

func initial_delay(source: PartyMemberState, status: String) -> int:
	var early := {"生机":["wood","早春"],"毒蚀":["wood","潜毒"],"润脉":["water","活泉"],"枯脉":["water","潜枯"]}
	if early.has(status) and spec(source,early[status][0],1,early[status][1]): return 1_500_000
	if status=="重伤" and spec(source,"earth",1,"催伤"): return 1_000_000
	if status=="驱散" and spec(source,"wind",1,"疾散"): return 1_000_000
	return 2_000_000

func status_strength(source: PartyMemberState, status: String) -> float:
	var names := {"反锋":["metal","蕴锋","化锋"],"锋痕":["metal","刻痕","深痕"],"流血":["metal","炼血","沸血"],"生机":["wood","养生","生息绵长"],"毒蚀":["wood","蚀骨","蚀骨渐深"],"润脉":["water","养脉","长养"],"枯脉":["water","蚀脉","深枯"],"灼烧":["fire","炽灼","灼火入骨"]}
	if not names.has(status): return 1
	var a: Array = names[status]
	return 1+bonus(source,a[0],2,a[1],.1)+bonus(source,a[0],4,a[2],.2)

func status_tick(member: PartyMemberState, status: String, pool: Dictionary, n: int, source: PartyMemberState, at: int) -> void:
	match status:
		"毒蚀","流血":
			if status=="毒蚀":
				var ordinal := count(source,"poison")
				if not (spec(source,"wood",5,"蚀骨难消") and ordinal%3==0): rules.consume(member,status,1)
			var before := member.hp
			rules.direct_hp(member,n*status_strength(source,status),source,at,status)
			if status=="毒蚀" and before>member.hp and spec(source,"wood",3,"以毒养生"): rules.apply_status(source,"生机",1,source,at)
			if status=="流血" and spec(source,"metal",3,"血养锋势"): rules.apply_status(source,"反锋",1,source,at)
		"灼烧":
			var add := status_strength(source,status)-1
			var base := float(n) * (1.2 if pool.get("revival_until",0)>at else 1.0)
			var result := rules.damage(source,member,base,"法术型","base.element.fire",at,{"kind":"dot","label":status,"damage_pct":add},false,{"special":has_special(member)})
			if result.get("effective",0)>0 and spec(source,"fire",3,"灼势回炎") and count(source,"burn")%3==0: rules.apply_status(source,"附炎",1,source,at)
		"生机":
			rules.consume(member,status,1)
			var value := n*(status_strength(source,status)+healing_bonus(source,"wood"))
			var missing := member.maximum("hp")-member.hp
			var prevented := minf(value,rules.active_injury(member,at)*injury_strength(member))
			var actual := rules.restore(member,"hp",value,at)
			if missing>0 and spec(source,"wood",5,"生生不息"): add_barrier(member,maxf(0,value-prevented-actual)*.5,"status.life")
		"润脉","枯脉": resource_tick(member,status,pool,n,source,at)
		"重伤":
			if at>int(pool.start): rules.consume(member,status,1)
		"破甲": rules.consume(member,status,1)
		"驱散": dispel_tick(member,pool,n,source,at)

func resource_tick(member: PartyMemberState, status: String, pool: Dictionary, n: int, source: PartyMemberState, at: int) -> void:
	rules.consume(member,status,1)
	var gain := status=="润脉"
	var strength := status_strength(source,status)+(healing_bonus(source,"water") if gain else 0.0)
	var intended := Vector2(n*strength,n*strength)
	if not gain:
		for resource: String in pool.get("participants",{}).values():
			if resource=="spirit": intended.x+=n*.25
			else: intended.y+=n*.25
	var old := Vector2(member.spirit,member.stamina)
	var capacity := Vector2(member.maximum("spirit"),member.maximum("stamina"))
	var room := capacity-old if gain else old
	var first := Vector2(minf(intended.x,room.x),minf(intended.y,room.y))
	var overflow := intended-first
	var ratio := 1.0 if spec(source,"water",5,"周流不息" if gain else "枯海断流") else .5
	var transfer := Vector2(overflow.y,overflow.x)*ratio
	var second := Vector2(minf(transfer.x,room.x-first.x),minf(transfer.y,room.y-first.y))
	var delta := first+second
	member.spirit=rules.q(old.x+delta.x*(1 if gain else -1))
	member.stamina=rules.q(old.y+delta.y*(1 if gain else -1))
	if gain and spec(source,"water",3,"盈流成护"):
		var leftover := overflow.x+overflow.y if room.x==0 and room.y==0 else transfer.x+transfer.y-second.x-second.y
		add_barrier(member,leftover*.5,"status.resources")
	if not gain and spec(source,"water",3,"枯极生寒") and (old.x>0 and member.spirit==0 or old.y>0 and member.stamina==0): rules.apply_status(member,"寒霜",1,source,at)
	rules.emit("status_tick",at,{"target_name":member.definition.name,"status":status,"value":n})

func dispel_tick(member: PartyMemberState, pool: Dictionary, n: int, source: PartyMemberState, at: int) -> void:
	var actual := 0
	while n>0:
		var targets := dispel_targets(member,at)
		if targets.is_empty(): break
		var batch: Dictionary = pool.batches[0]
		var bonus_chance := float(batch.get("dispel_bonus",0))+bonus(source,"wind",2,"拂尘",.1)+bonus(source,"wind",4,"涤尘",.15)
		dispel_one(member,targets,at)
		actual+=1
		rules.consume(member,"驱散",1)
		n-=1
		if bonus_chance>0 and rules.roll()<bonus_chance:
			targets=dispel_targets(member,at)
			if not targets.is_empty(): dispel_one(member,targets,at); actual+=1
	if member.combat_statuses.has("驱散"):
		pool.expires=at+5_000_000
		pool.next=pool.expires
	if actual>0 and spec(source,"wind",3,"清风乱势"): rules.apply_status(member,"失衡",2,source,at)
	if spec(source,"wind",5,"风过无尘"):
		for i in actual:
			if count(source,"dispel")%5==0: pending_delays[source.id]=int(pending_delays.get(source.id,0))+1
		flush_delays(source,at)
	rules.emit("status_tick",at,{"target_name":member.definition.name,"status":"驱散","value":actual})

func dispel_targets(member: PartyMemberState, at: int) -> Array:
	var result: Array = []
	for group: Array in T01Definition.STATUS_GROUPS.values():
		if rules.layers(member,group[0])>0: result.append(group[0])
	for id: String in member.temporary_effects:
		if id!="weakness" and member.temporary_effects[id].get("until",0)>at: result.append(id)
	return result

func dispel_one(member: PartyMemberState, targets: Array, at: int) -> void:
	var id: String = targets[mini(targets.size()-1,int(rules.roll()*targets.size()))]
	if member.temporary_effects.has(id):
		member.temporary_effects.erase(id)
		if id=="toxin_immunity": member.toxin_immune_until_usec=at
	else: rules.consume(member,id,1)

func flush_delays(member: PartyMemberState, at: int) -> void:
	var id := cd_target(member,"",{"delay_cd":2},at,str(member.definition.get("dispel_target","")))
	while int(pending_delays.get(member.id,0))>0 and not id.is_empty():
		if not sim.timeline.change_cd(id,2_000_000,at): break
		pending_delays[member.id]-=1

func tax_attempt(id: String, at: int) -> bool:
	var member: PartyMemberState = sim._owners[id]
	var item: ItemData = sim._definitions[id]
	if item.stamina_cost<=0 and item.spirit_cost<=0: return true
	var enemy := source_for(member)
	var tax := prepared(enemy,"tax_cast",at)
	if tax.is_empty(): return true
	var normal := rules.costs(member,item,at)
	var fees := participant_fees(member,id,at)
	var participation := Vector2.ZERO
	for fee: Vector2 in fees.values(): participation += fee
	var p := trigger(tax,at)
	if p.is_empty(): return true
	var extra := Vector2(item.stamina_cost,item.spirit_cost)*float(p.surcharge)
	var enough := member.stamina>=rules.q(normal.x+extra.x+participation.x) and member.spirit>=rules.q(normal.y+extra.y+participation.y)
	# New injury is applied after the fee snapshot and cannot affect this cast.
	sim.state.item_runtime[id].fee_override=Vector2(rules.q(normal.x+extra.x),rules.q(normal.y+extra.y))
	sim.state.item_runtime[id].participant_fees=fees
	rules.apply_status(member,"重伤",p.injury,enemy,at)
	if not enough:
		sim.state.item_runtime[id].erase("fee_override")
		sim.state.item_runtime[id].erase("participant_fees")
		sim.timeline.restart(id,at)
		rules.emit("cast_interrupted",at,{"item_id":item.id,"label":"镇脉诀","target_name":member.definition.name})
	return enough

func injury_event(source: PartyMemberState, at: int) -> void:
	if spec(source,"earth",3,"伤深养韧") and count(source,"injury")%4==0: rules.apply_status(source,"坚韧",1,source,at)

func selected_weapons(owner: PartyMemberState, caster: String, at: int) -> Array:
	var ids := weapons(owner,at)
	var selected: String = sim.timeline.timers[caster].selection
	if not selected.is_empty(): return [selected] if selected in ids else []
	return [ids[0]] if not ids.is_empty() else []

func participant_cost(owner: PartyMemberState, id: String, at: int) -> Vector2:
	var result := Vector2.ZERO
	for fee: Vector2 in participant_fees(owner,id,at).values(): result += fee
	return result

func participant_fees(owner: PartyMemberState, id: String, at: int) -> Dictionary:
	var p := data(owner,sim._definitions[id])
	var result := {}
	if p.get("opcode") not in ["command_weapon","weapon_union"]: return result
	var ids := selected_weapons(owner,id,at) if p.opcode=="command_weapon" else weapons(owner,at)
	for weapon: String in ids:
		var cost := rules.costs(owner,sim._definitions[weapon],at)*(0.5 if p.opcode=="weapon_union" else 1.0)
		result[weapon]=Vector2(rules.q(cost.x),rules.q(cost.y))
	return result
