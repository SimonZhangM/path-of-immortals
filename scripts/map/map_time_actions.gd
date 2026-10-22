class_name MapTimeActions
extends RefCounted

static func rest(state: MapLoadoutState, status: MapPlayerStatus, event: Dictionary, path: String, food_id := "") -> Dictionary:
	if not food_id.is_empty() and (not event.get("allow_food",false) or state.inventory.locked): return {"error":"此处当前不能进食。"}
	var result := status.preview_rest(int(event.recovery_percent),int(event.duration_days),event.id)
	if not result.error.is_empty(): return result
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return {"error":prepared.error}
	var candidate: MapLoadoutState = prepared.state
	var error := candidate.advance_days(int(event.duration_days),event.id)
	if error.is_empty() and not food_id.is_empty(): error = MapFood.apply_to_candidate(candidate,food_id,result.result,status.maxima)
	if not candidate.growth.is_empty():
		for key: String in result.result.after: candidate.growth.resources[key]=CultivationGrowth.cents(result.result.after[key])
	if error.is_empty(): error = MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return {"error":error}
	error = state.restore(candidate.snapshot())
	if not error.is_empty(): return {"error":error}
	status.apply_rest(result.result)
	status.food_modifiers = MapFood.modifiers(state)
	return result
