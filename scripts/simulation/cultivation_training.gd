class_name CultivationTraining
extends BattleSimulation

# Independent non-combat context. Reuses the deterministic board event timeline;
# no enemy attacks, encounter rewards, consumables, kill or retaliation events.
var paid_actions: Array[Dictionary] = []

func _init(player: PartyMemberState, registry: ContentRegistry) -> void:
	player.definition.training_precision = true
	var dummy := PartyMemberState.new({"id":"run.training.target", "name":"修炼靶", "max_hp":1000000000, "max_stamina":1000000000, "max_spirit":1000000000, "cultivation_rank":player.cultivation_rank_id},registry)
	super([player],[dummy],registry)

func _check_result(_at: int) -> void:
	# A target never dies or grants anything. Clear incoming effects only on it;
	# actor cooldowns and resource restoration remain continuous across days.
	var dummy: PartyMemberState = state.teams[1][0]
	dummy.hp = dummy.maximum("hp")

func _can_activate(id: String) -> bool:
	if not _definitions.has(id): return false
	var item: ItemData = _definitions[id]
	if item.is_consumable() or item.combat.get("prepared",false): return false
	if item.training:
		var owner: PartyMemberState = _owners[id]
		return owner.hp>0 and owner.stamina>=item.stamina_cost and owner.spirit>=item.spirit_cost
	return super(id)

func _activate(payload: Dictionary, at: int) -> void:
	var id := str(payload.instance_id)
	if not _definitions.has(id): return
	var item: ItemData = _definitions[id]
	var owner: PartyMemberState = _owners[id]
	if item.training:
		if not _can_activate(id): return
		owner.stamina = CultivationGrowth.quantize(owner.stamina-item.stamina_cost)
		owner.spirit = CultivationGrowth.quantize(owner.spirit-item.spirit_cost)
		state.item_runtime[id].activation_count += 1
		timeline.restart(id,at)
		paid_actions.append({"item_id":item.id,"element":"all","stamina":item.stamina_cost,"spirit":item.spirit_cost,"at":at})
		return
	var before := int(state.item_runtime[id].activation_count)
	super(payload,at)
	if int(state.item_runtime[id].activation_count)==before: return
	if item.category not in ["weapon","spell"]: return
	# Actual successful payment only. Weapon congestion surcharges do not train.
	var p := _registry.library.resolved(owner,item.id) if item.category=="spell" else {}
	var spirit := CultivationGrowth.quantize(item.spirit_cost*(1.0+float(p.get("cost_pct",0))))
	var element := item.element.trim_prefix("base.element.") if item.category=="spell" else "none"
	# Test-only spells can run on the board, but cannot bypass learned-source rules.
	if item.category=="spell" and owner.knowledge.level(p.book_id)<int(p.learned_at_book_level): element="none"
	paid_actions.append({"item_id":item.id,"element":element,"stamina":item.stamina_cost,"spirit":spirit,"at":at})

func take_payments() -> Array[Dictionary]:
	var result := paid_actions
	paid_actions = []
	drain_events()
	return result
