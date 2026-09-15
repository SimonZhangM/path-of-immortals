class_name MapEventState
extends RefCounted

# Run-scoped stable IDs survive map reinstantiation, but never write to disk.
static var session_completed: Dictionary = {}

var registry: MapEventRegistry
var completed: Dictionary
var active_id := ""
var line_index := 0
var phase := ""

func _init(content: MapEventRegistry, completion_record: Variant = null) -> void:
	registry = content
	completed = session_completed if completion_record == null else completion_record

func is_active() -> bool:
	return not active_id.is_empty()

func try_start(point_id: String, current_point_id: String, stationary: bool) -> bool:
	if is_active() or not stationary or point_id != current_point_id:
		return false
	var event_id: String = registry.by_point.get(point_id, "")
	if event_id.is_empty() or completed.has(event_id):
		return false
	for prerequisite in registry.events[event_id].get("requires_completed", []):
		if not completed.has(prerequisite):
			return false
	active_id = event_id
	line_index = 0
	phase = "illustration" if active_event().presentation.has("illustration") else "dialogue"
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
	if phase == "illustration":
		phase = "dialogue"
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
