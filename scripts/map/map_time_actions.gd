class_name MapTimeActions
extends RefCounted

static func rest(state: MapLoadoutState, status: MapPlayerStatus, event: Dictionary, path: String) -> Dictionary:
	var result := status.preview_rest(int(event.recovery_percent),int(event.duration_days),event.id)
	if not result.error.is_empty(): return result
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return {"error":prepared.error}
	var candidate: MapLoadoutState = prepared.state
	var error := candidate.advance_days(int(event.duration_days),event.id)
	if error.is_empty(): error = MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return {"error":error}
	error = state.restore(candidate.snapshot())
	if not error.is_empty(): return {"error":error}
	status.apply_rest(result.result)
	return result
