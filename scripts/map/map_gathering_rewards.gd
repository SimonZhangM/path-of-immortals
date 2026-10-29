class_name MapGatheringRewards
extends RefCounted

const SPIRIT_STONE_ID := "base.currency.spirit_stones"
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")

# A presentation record only: currency never enters the item registry or bag.
static func record_for(records: Dictionary, id: String) -> Dictionary:
	if id == SPIRIT_STONE_ID:
		return {"id": id, "name": "灵石", "category": "mineral", "subcategory": "灵石",
			"quality": "下品", "icon": "res://assets/player-status-coin.webp", "quantity": 1}
	return records.get(id, {})

# Pending rolls are saved before displaying loot; confirmation uses the existing
# atomic reward receipt. Map completion stays session-only for test respawns.
static func validate_offers(raw: Variant, records: Dictionary) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	var profiles := {}
	for event_id: Variant in raw:
		if not event_id is String or not event_id.begins_with("base.map_event."): return false
		var offer: Variant = raw[event_id]
		if not offer is Dictionary or not offer.get("id") is String or not offer.id.begins_with(event_id.replace("base.map_event.","base.map_reward.") + "."): return false
		if not offer.get("item_id") is String: return false
		var record := record_for(records, offer.item_id)
		if record.get("category") not in ["plant", "mineral"]: return false
		var profile := MapGatheringOptions.path_for_record(record)
		if not profiles.has(profile):
			var loaded := MapGatheringOptions.new()
			if not loaded.load_options(profile).is_empty(): return false
			profiles[profile] = loaded
		var options: MapGatheringOptions = profiles[profile]
		if not ContentRegistry._positive_integer(offer.get("quantity")): return false
		var index := -1
		for i in options.methods.size():
			if options.methods[i].id == offer.get("method_id"): index = i
		if index < 0: return false
		var forecast := options.forecast(index)
		if offer.quantity < forecast.total_min or offer.quantity > forecast.total_max or offer.get("days") != forecast.days: return false
	return true

static func pending(state: MapLoadoutState, event: Dictionary) -> Dictionary:
	var offer: Dictionary = state.gathering_offers.get(event.id,{})
	if offer.is_empty() or state.has_reward(offer.id): return {}
	return offer.duplicate(true)

static func prepare(state: MapLoadoutState, event: Dictionary, method_id: String, path: String, rng: RandomNumberGenerator) -> String:
	var record := record_for(state.records, event.get("item_id", ""))
	if record.get("category") not in ["plant", "mineral"]: return "采集材料未配置。"
	if not pending(state,event).is_empty(): return ""
	var options := MapGatheringOptions.new()
	var error := options.load_options(MapGatheringOptions.path_for_record(record))
	if not error.is_empty(): return error
	var index := -1
	for i in options.methods.size():
		if options.methods[i].id == method_id: index = i
	if index < 0: return "采集方式无效。"
	var forecast := options.forecast(index)
	var number := 1
	while state.has_reward("%s.%d" % [event.reward_prefix, number]): number += 1
	var offer := {"id": "%s.%d" % [event.reward_prefix,number], "item_id": event.item_id,
		"quantity": forecast.base + rng.randi_range(forecast.extra_min,forecast.extra_max),
		"method_id": method_id, "days": forecast.days}
	var candidate := MapLoadoutState.new()
	candidate.registry = state.registry
	candidate.board = state.board
	candidate.records = state.records
	candidate._seed_owned = state._seed_owned
	candidate.cultivation_rank_id = state.cultivation_rank_id
	candidate.formation_icons = state.formation_icons
	var next := state.snapshot()
	next.gathering_offers = state.gathering_offers.duplicate(true)
	next.gathering_offers[event.id] = offer
	error = candidate.restore(next)
	if not error.is_empty(): return error
	# Producing a result completes the activity; reopening/claiming it costs no time.
	error = candidate.advance_days(int(forecast.days),offer.id)
	if not error.is_empty(): return error
	error = MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return error
	return state.restore(candidate.snapshot())

static func claim(state: MapLoadoutState, event: Dictionary, path: String) -> String:
	var offer: Dictionary = state.gathering_offers.get(event.id,{})
	if offer.is_empty() or offer.item_id != event.item_id: return "尚未产生采集结果。"
	var already_claimed := state.has_reward(offer.id)
	var error := MapLoadoutStore.claim_reward(state,offer,path)
	if error.is_empty() and not already_claimed:
		Checkpoints.after_action(state,path,"gathering_complete")
	return error
