class_name MapEventState
extends RefCounted

signal encounter_changed(event_id: String)

# Run-scoped stable IDs survive map reinstantiation, but never write to disk.
static var session_completed: Dictionary = {}

var registry: MapEventRegistry
var completed: Dictionary
var active_id := ""
var line_index := 0
var phase := ""
var reward_claimed: Callable
var _accepted_rewards: Dictionary = {}

func _init(content: MapEventRegistry, completion_record: Variant = null) -> void:
	registry = content
	completed = session_completed if completion_record == null else completion_record

func is_active() -> bool:
	return not active_id.is_empty()

func try_start(point_id: String, current_point_id: String, stationary: bool, trigger: String = "click") -> bool:
	if is_active() or not stationary or point_id != current_point_id:
		return false
	var event_id: String = registry.by_point.get(point_id, "")
	if event_id.is_empty() or completed.has(event_id):
		return false
	var event: Dictionary = registry.events[event_id]
	# Arrival encounters can be retried by clicking while standing at the node.
	if event.get("trigger", "click") != trigger and not (event.type == "encounter" and trigger == "click"):
		return false
	for prerequisite in registry.events[event_id].get("requires_completed", []):
		if not completed.has(prerequisite):
			return false
	active_id = event_id
	line_index = 0
	phase = "encounter" if event.type == "encounter" else ("illustration" if event.presentation.has("illustration") else "dialogue")
	return true

func active_event() -> Dictionary:
	return registry.events.get(active_id, {})

func current_line() -> String:
	return active_event().lines[line_index] if is_active() and phase == "dialogue" else ""

func current_speaker_id() -> String:
	if not is_active() or phase != "dialogue":
		return ""
	var event := active_event()
	var speakers: Array = event.get("line_speakers", [])
	return event.speaker_id if speakers.is_empty() else speakers[line_index]

# Empty result means no completion. Final advance returns the stable event ID.
func advance() -> String:
	if not is_active():
		return ""
	if phase in ["reward", "encounter"]:
		return ""
	if phase == "illustration":
		phase = "dialogue"
		return ""
	var reward: Dictionary = active_event().get("reward", {})
	if not reward.is_empty() and line_index == int(reward.after_line) and not _accepted_rewards.has(reward.id):
		if reward.get("test_replay_on_restart", false) or not reward_claimed.is_valid() or not reward_claimed.call(reward.id):
			phase = "reward"
			return ""
	if line_index + 1 < active_event().lines.size():
		line_index += 1
		return ""
	var finished := active_id
	completed[finished] = true
	active_id = ""
	line_index = 0
	phase = ""
	return finished

func cancel_encounter() -> bool:
	if phase != "encounter":
		return false
	active_id = ""
	line_index = 0
	phase = ""
	return true

func resolve_encounter(event_id: String, result: String) -> bool:
	if registry.events.get(event_id, {}).get("type", "") != "encounter" or result not in ["victory", "defeat", "draw", "retreat"]:
		return false
	if active_id == event_id:
		cancel_encounter()
	if result == "victory" and not completed.has(event_id):
		completed[event_id] = true
		encounter_changed.emit(event_id)
	return true

func respawn_encounter(event_id: String) -> bool:
	if active_id == event_id or registry.events.get(event_id, {}).get("type", "") != "encounter":
		return false
	if completed.erase(event_id):
		encounter_changed.emit(event_id)
	return true

func accept_reward() -> String:
	if phase != "reward":
		return ""
	_accepted_rewards[active_event().reward.id] = true
	phase = "dialogue"
	return advance()
