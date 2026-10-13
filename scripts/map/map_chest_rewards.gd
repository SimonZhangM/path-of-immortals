class_name MapChestRewards
extends RefCounted

# Data-driven pools; calendar deadlines and rewards share one atomic save.
const RULES_PATH := "res://data/maps/chest_pools.json"
const LEGACY_GROUPS := [["weapon", "armor"], ["pill", "artifact"]]
static var _rules: Dictionary = {}

static func load_rules() -> String:
	if not _rules.is_empty(): return ""
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if not raw is Dictionary or raw.get("version") != 2 or raw.get("allowed_qualities") != ["下品", "凡品"] or not raw.get("pools") is Array or raw.pools.is_empty():
		return "宝箱池配置无效。"
	var ids := {}
	for pool: Variant in raw.pools:
		if not pool is Dictionary or not pool.get("id") is String or not pool.id.begins_with("base.chest_pool.") or ids.has(pool.id) or not ContentRegistry._positive_integer(pool.get("weight")):
			return "宝箱池标识或权重无效。"
		if not pool.get("slots") is Array or pool.slots.size() != 2: return "宝箱池必须配置两栏。"
		for slot: Variant in pool.slots:
			if not slot is Array or slot.is_empty(): return "宝箱栏类别不能为空。"
			for category: Variant in slot:
				if category not in ["weapon", "armor", "pill", "throwable", "artifact"]: return "宝箱栏类别无效。"
		ids[pool.id] = true
	_rules = raw
	return ""

static func pool_definition(id: String) -> Dictionary:
	if not load_rules().is_empty(): return {}
	for pool: Dictionary in _rules.pools:
		if pool.id == id: return pool
	return {}

static func pool_for_roll(roll: int) -> Dictionary:
	if not load_rules().is_empty() or roll < 0: return {}
	for pool: Dictionary in _rules.pools:
		if roll < int(pool.weight): return pool
		roll -= int(pool.weight)
	return {}

static func candidates(state: MapLoadoutState, event: Dictionary, pool: Dictionary) -> Array:
	var result: Array = []
	for categories: Array in pool.slots:
		var ids: Array[String] = []
		for id: String in state.records:
			var record: Dictionary = state.records[id]
			if record.quality == event.quality and record.category in categories: ids.append(id)
		ids.sort()
		result.append(ids)
	return result

static func configuration_error(state: MapLoadoutState, event: Dictionary) -> String:
	var error := load_rules()
	if not error.is_empty(): return error
	if event.get("quality") not in _rules.allowed_qualities: return "宝箱品级超出当前开放范围。"
	for pool: Dictionary in _rules.pools:
		var slots := candidates(state,event,pool)
		if slots[0].is_empty() or slots[1].is_empty() or (slots[0].size()==1 and slots[1]==slots[0]):
			return "宝箱池不足两件不同物品：" + pool.id
	return ""

static func current_event(state: MapLoadoutState, event: Dictionary) -> Dictionary:
	var result := event.duplicate(true)
	var base_id: String = event.get("source_reward_id",event.reward_id)
	var cooldown: Dictionary = state.chest_cooldowns.get(base_id,{})
	var cycle := int(cooldown.get("cycle",1))
	if not cooldown.is_empty() and WorldCalendar.current_day(state.calendar)>=int(cooldown.ready_day): cycle += 1
	result.source_reward_id = base_id
	result.chest_cycle = cycle
	result.reward_id = base_id if cycle==1 else base_id+".cycle.%d" % cycle
	return result

static func items(state: MapLoadoutState, event: Dictionary) -> Array:
	var offer: Variant = state.chest_offers.get(event.reward_id, [])
	return offer.duplicate() if offer is Array else offer.get("items", []).duplicate()

static func validate_offers(raw: Variant, records: Dictionary) -> bool:
	if not raw is Dictionary or not load_rules().is_empty(): return false
	for id: Variant in raw:
		if not id is String or not id.begins_with("base.map_reward."): return false
		var offer: Variant = raw[id]
		var selected: Variant
		var groups: Array
		if offer is Array:
			# Old pairs remain readable; unclaimed ones migrate only on successful open.
			selected = offer
			groups = LEGACY_GROUPS
		elif offer is Dictionary and offer.get("version") == 2 and offer.get("pool_id") is String:
			var pool := pool_definition(offer.pool_id)
			if pool.is_empty(): return false
			groups = pool.slots
			selected = offer.get("items")
		else: return false
		if not selected is Array or selected.size()!=2 or selected[0]==selected[1]: return false
		for index in 2:
			if not selected[index] is String or not records.has(selected[index]): return false
			var record: Dictionary = records[selected[index]]
			if record.category not in groups[index] or record.quality not in _rules.allowed_qualities: return false
		if records[selected[0]].quality != records[selected[1]].quality: return false
	return true

static func validate_cooldowns(raw: Variant, grants: Variant) -> bool:
	if not raw is Dictionary or not grants is Dictionary: return false
	for id: Variant in raw:
		if not id is String or not id.begins_with("base.map_reward.") or not grants.has(id): return false
		var record: Variant = raw[id]
		if not record is Dictionary or not ContentRegistry._positive_integer(record.get("delay_days")) or not ContentRegistry._nonnegative_integer(record.get("remaining_days")):
			return false
		if record.remaining_days > record.delay_days: return false
		if record.has("ready_day") and not WorldCalendar.integer_between(record.ready_day,0,WorldCalendar.MAX_DAY): return false
		if record.has("cycle") and (not ContentRegistry._positive_integer(record.cycle) or (record.cycle>1 and not grants.has(id+".cycle.%d" % int(record.cycle)))): return false
	return true

static func _current_offer(state: MapLoadoutState, event: Dictionary) -> bool:
	var offer: Variant = state.chest_offers.get(event.reward_id)
	return offer is Dictionary and offer.get("version")==2 and validate_offers({event.reward_id:offer},state.records) and state.records[offer.items[0]].quality==event.quality

static func _candidate(state: MapLoadoutState) -> Dictionary:
	var candidate := MapLoadoutState.new()
	candidate.registry = state.registry
	candidate.board = state.board
	candidate.records = state.records
	candidate._seed_owned = state._seed_owned
	candidate.cultivation_rank_id = state.cultivation_rank_id
	candidate.formation_icons = state.formation_icons
	return {"state":candidate,"error":candidate.restore(state.snapshot())}

static func ensure_offer(state: MapLoadoutState, event: Dictionary, path: String, rng: RandomNumberGenerator) -> String:
	if current_event(state,event).reward_id != event.reward_id: return "宝箱轮次已变化，请重新打开。"
	if state.has_reward(event.reward_id): return "此宝箱已收取，尚待重新开启。"
	var error := configuration_error(state,event)
	if not error.is_empty(): return error
	if _current_offer(state,event): return ""
	var total := 0
	for pool: Dictionary in _rules.pools: total += int(pool.weight)
	var pool := pool_for_roll(rng.randi_range(0,total-1))
	var slots := candidates(state,event,pool)
	var choices: Array[String] = []
	for slot: Array in slots:
		var available := slot.filter(func(id): return id not in choices)
		choices.append(available[rng.randi_range(0,available.size()-1)])
	var prepared := _candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var candidate: MapLoadoutState = prepared.state
	candidate.chest_offers[event.reward_id] = {"version":2,"pool_id":pool.id,"items":choices}
	error = MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return error
	return state.restore(candidate.snapshot())

static func claim(state: MapLoadoutState, event: Dictionary, index: int, path: String) -> String:
	if current_event(state,event).reward_id != event.reward_id: return "宝箱轮次已变化，请重新打开。"
	if state.has_reward(event.reward_id): return "此宝箱已经领取。"
	if index < 0 or index >= 2 or not _current_offer(state,event): return "请先选择一件有效物品。"
	var delay: int = int(event.get("respawn_days",40))
	if delay <= 0: return "宝箱重新开启天数无效。"
	var prepared := state.reward_candidate({"id":event.reward_id,"item_id":items(state,event)[index],"quantity":1})
	if not prepared.error.is_empty(): return prepared.error
	var candidate: MapLoadoutState = prepared.state
	var ready_day := WorldCalendar.current_day(candidate.calendar)+delay
	if ready_day>WorldCalendar.MAX_DAY: return "宝箱日期超出历法范围。"
	var base_id: String = event.get("source_reward_id",event.reward_id)
	candidate.chest_cooldowns[base_id] = {"delay_days":delay,"remaining_days":delay,"ready_day":ready_day,"cycle":int(event.get("chest_cycle",1))}
	var error := MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return error
	return state.restore(candidate.snapshot())
