class_name MapEventState
extends RefCounted

signal encounter_changed(event_id: String)

# Keys are globally unique map event instance IDs, never enemy species IDs.
# Two nodes using the same enemy definition therefore die/respawn independently.
# Run-scoped stable IDs survive map reinstantiation, but never write to disk.
static var session_completed: Dictionary = {}
static var session_encounters: Dictionary = {}

var registry: MapEventRegistry
var completed: Dictionary
var active_id := ""
var line_index := 0
var phase := ""
var reward_claimed: Callable
var _accepted_rewards: Dictionary = {}
var encounters: Dictionary
var enemy_lookup: Callable
var enemy_available: Callable
var chest_resolver: Callable
var _active_snapshot: Dictionary = {}
var narrative_rng := RandomNumberGenerator.new()

func _init(content: MapEventRegistry, completion_record: Variant = null, encounter_record: Variant = null) -> void:
	registry = content
	completed = session_completed if completion_record == null else completion_record
	encounters = (session_encounters if completion_record == null else {}) if encounter_record == null else encounter_record
	narrative_rng.randomize()

func resolved_event(event_id: String) -> Dictionary:
	var event: Dictionary = registry.events.get(event_id, {}).duplicate(true)
	if event.get("type") == "chest" and chest_resolver.is_valid(): event = chest_resolver.call(event)
	if event.get("type") == "encounter":
		var sequence: Array = event.get("enemy_sequence", [event.enemy_id])
		event.enemy_id = sequence[int(encounters.get(event_id, {}).get("index", 0)) % sequence.size()]
	return event

func _available(event: Dictionary) -> bool:
	return event.get("enabled", true) and (event.get("type") != "encounter" or not enemy_available.is_valid() or enemy_available.call(event.enemy_id))

func is_active() -> bool:
	return not active_id.is_empty()

func try_start(point_id: String, current_point_id: String, stationary: bool, trigger: String = "click") -> bool:
	if is_active() or not stationary or point_id != current_point_id:
		return false
	var event_id: String = registry.by_point.get(point_id, "")
	if event_id.is_empty() or completed.has(event_id):
		return false
	var event := resolved_event(event_id)
	if not _available(event): return false
	if event.type == "chest" and reward_claimed.is_valid() and reward_claimed.call(event.reward_id): return false
	# Arrival encounters can be retried by clicking while standing at the node.
	if event.get("trigger", "click") != trigger and not (event.type in ["encounter", "chest", "gathering", "rest", "shop", "clinic", "inn", "cultivation"] and trigger == "click"):
		return false
	for prerequisite in registry.events[event_id].get("requires_completed", []):
		if not completed.has(prerequisite):
			return false
	active_id = event_id
	_active_snapshot = event
	# Authored location copy is stable; random species copy is only a fallback.
	if event.type == "encounter" and event.description.strip_edges().is_empty() and enemy_lookup.is_valid():
		var enemy: Dictionary = enemy_lookup.call(event.enemy_id)
		var descriptions: Array = enemy.get("encounter_descriptions", [])
		if not descriptions.is_empty(): _active_snapshot.description = descriptions[narrative_rng.randi_range(0, descriptions.size() - 1)]
	line_index = 0
	phase = event.type if event.type in ["encounter","chest","gathering","rest","shop","clinic","inn","cultivation"] else ("illustration" if event.presentation.has("illustration") else "dialogue")
	if event.type == "chest" and event.has("observation"):
		phase = "chest_observation"
	return true

func active_event() -> Dictionary:
	if not is_active(): return {}
	return _active_snapshot.duplicate(true) if _active_snapshot.get("id") == active_id else resolved_event(active_id)

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
	if phase in ["reward", "encounter", "chest_observation", "chest", "gathering", "gathering_reward", "rest", "shop", "clinic", "inn", "cultivation"]:
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

func open_chest() -> bool:
	# Controller prepares a persisted offer before entering the choice phase.
	# Future opening conditions belong before this transition, never in the UI.
	if phase != "chest_observation": return false
	phase = "chest"
	return true

func close_rest() -> bool:
	if phase != "rest": return false
	# A rest site is reusable; closing it never completes or removes its sign.
	active_id=""
	phase=""
	line_index=0
	return true

func close_shop() -> bool:
	if phase != "shop": return false
	active_id = ""
	phase = ""
	line_index = 0
	return true

func close_clinic() -> bool:
	if phase != "clinic": return false
	active_id = ""
	phase = ""
	line_index = 0
	return true

func close_cultivation() -> bool:
	if phase != "cultivation": return false
	active_id = ""
	phase = ""
	line_index = 0
	return true

func close_inn() -> bool:
	if phase != "inn": return false
	active_id = ""
	phase = ""
	line_index = 0
	return true

func close_chest(claimed: bool) -> String:
	if phase not in ["chest_observation", "chest"]: return ""
	var finished := active_id
	if claimed:
		if phase != "chest": return ""
		if not reward_claimed.is_valid() or not reward_claimed.call(active_event().reward_id): return ""
		completed[finished] = true
	active_id = ""
	phase = ""
	line_index = 0
	return finished

func close_gathering(receipt_id := "") -> String:
	if phase not in ["gathering", "gathering_reward"]: return ""
	var finished := active_id
	if not receipt_id.is_empty():
		if not receipt_id.begins_with(active_event().reward_prefix + ".") or not reward_claimed.is_valid() or not reward_claimed.call(receipt_id): return ""
		completed[finished] = true
	active_id = ""
	phase = ""
	line_index = 0
	return finished

func resolve_encounter(event_id: String, result: String) -> bool:
	if registry.events.get(event_id, {}).get("type", "") != "encounter" or result not in ["victory", "defeat", "draw", "retreat"]:
		return false
	if not _available(resolved_event(event_id)): return false
	if active_id == event_id:
		cancel_encounter()
	if result == "victory" and not completed.has(event_id):
		completed[event_id] = true
		var record: Dictionary = encounters.get(event_id, {"index": 0})
		record.remaining_days = int(registry.events[event_id].get("respawn_days", -1))
		encounters[event_id] = record
		encounter_changed.emit(event_id)
	return true

func respawn_encounter(event_id: String) -> bool:
	if active_id == event_id or registry.events.get(event_id, {}).get("type", "") != "encounter":
		return false
	if not registry.events[event_id].get("enabled", true): return false
	if not completed.has(event_id): return false
	var record: Dictionary = encounters.get(event_id, {"index": 0, "remaining_days": -1})
	if int(record.get("remaining_days", -1)) > 0: return false
	var event: Dictionary = registry.events[event_id]
	var sequence: Array = event.get("enemy_sequence", [event.enemy_id])
	record.index = (int(record.index) + 1) % sequence.size()
	record.remaining_days = -1
	encounters[event_id] = record
	if completed.erase(event_id):
		encounter_changed.emit(event_id)
	return true

# Legacy standalone countdown API. Live maps use persisted absolute deadlines
# in MapLoadoutState; never also tick this API for the same calendar action.
func advance_encounter_days(days: int) -> bool:
	if days <= 0: return false
	for event_id: String in encounters.keys():
		if not registry.events.has(event_id) or not completed.has(event_id): continue
		var record: Dictionary = encounters[event_id]
		if int(record.get("remaining_days", -1)) < 0: continue
		record.remaining_days = maxi(0, int(record.remaining_days) - days)
		if record.remaining_days == 0: respawn_encounter(event_id)
	return true

func accept_reward() -> String:
	if phase != "reward":
		return ""
	_accepted_rewards[active_event().reward.id] = true
	phase = "dialogue"
	return advance()
