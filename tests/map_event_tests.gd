extends SceneTree

var checks := 0
var failures := 0
const EVENT_PATH := "res://data/map_events/qingshihewan_bridge_dialogue.json"
const POINT := "base.map.qingshihewan.point.n37"

func _initialize() -> void:
	var registry := MapEventRegistry.new()
	_check(registry.load_files([EVENT_PATH], [POINT]).is_empty(), "load bridge dialogue content")
	var event: Dictionary = registry.events.values()[0]
	var record: Dictionary = {}
	var state := MapEventState.new(registry, record)
	_check(not state.try_start(POINT, "elsewhere", true), "remote click cannot trigger")
	_check(not state.try_start(POINT, POINT, false), "moving through node cannot trigger")
	_check(not state.try_start("unconfigured", "unconfigured", true), "unconfigured signs have no invented events")
	_check(state.advance().is_empty() and record.is_empty(), "idle advance does not complete")
	_check(state.try_start(POINT, POINT, true), "stationary second click starts")
	_check(not state.try_start(POINT, POINT, true), "active dialogue cannot restart")
	for i in event.lines.size():
		_check(state.current_line() == event.lines[i] and state.line_index == i, "authored paragraph %d" % i)
		_check(not record.has(event.id), "displaying final paragraph alone is not completion")
		var done := state.advance()
		_check(done == (event.id if i == event.lines.size() - 1 else ""), "completion only after final advance")
	_check(not state.is_active() and state.current_line().is_empty() and record.has(event.id), "final advance clears active and records stable ID")
	_check(not state.try_start(POINT, POINT, true), "completed event cannot repeat")
	var revisit := MapEventState.new(registry, record)
	_check(not revisit.try_start(POINT, POINT, true), "same run completion survives state replacement")
	var fresh := MapEventState.new(registry, {})
	_check(fresh.try_start(POINT, POINT, true), "fresh run may trigger again")
	var variants: Array = []
	var bad := event.duplicate(true)
	bad.lines = []
	variants.append([bad])
	bad = event.duplicate(true)
	bad.point_id = "missing"
	variants.append([bad])
	bad = event.duplicate(true)
	bad.type = "unsupported"
	variants.append([bad])
	bad = event.duplicate(true)
	bad.presentation.text_rect = [0, 0, 99999, 200]
	variants.append([bad])
	bad = event.duplicate(true)
	bad.presentation.portrait_max_size = 99999
	variants.append([bad])
	variants.append([event, event])
	for definitions in variants:
		_check(not registry.configure(definitions, [POINT]).is_empty(), "invalid content rejected")
		_check(registry.events.size() == 1 and registry.events.has(event.id), "failed reload preserves prior complete registry")
	_check_illustrated_event()
	print("MAP EVENT RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_illustrated_event() -> void:
	var registry := MapEventRegistry.new()
	var second_point := "base.map.qingshihewan.point.n20"
	_check(registry.load_files([EVENT_PATH, "res://data/map_events/qingshihewan_wounded_disciple.json"], [POINT, second_point]).is_empty(), "load prerequisite and illustrated dialogue")
	var record: Dictionary = {}
	var state := MapEventState.new(registry, record)
	_check(not state.try_start(second_point, second_point, true), "prerequisite blocks N20 before N37")
	state.try_start(POINT, POINT, true)
	_check(state.phase == "dialogue", "legacy event starts directly in dialogue")
	while state.is_active():
		state.advance()
	_check(state.try_start(second_point, second_point, true), "completed N37 unlocks N20")
	_check(state.phase == "illustration" and state.line_index == 0 and state.current_line().is_empty() and state.current_speaker_id().is_empty(), "illustration stage has no dialogue yet")
	_check(not state.try_start(second_point, second_point, true), "cannot restart illustration stage")
	state.advance()
	_check(state.phase == "dialogue" and state.line_index == 0 and state.current_line() == "等等，先别过来，附近还有山兽。", "first advance enters first paragraph without skipping")
	var event := state.active_event()
	_check(event.lines.size() == 20, "all twenty paragraphs retained")
	for i in 20:
		var speaker := "base.npc.qinglan.outer_disciple" if i % 2 == 0 else "base.map_player.chen_yu"
		_check(state.current_speaker_id() == speaker and state.current_line() == event.lines[i], "speaker and text stay in sync: %d" % i)
		_check(not record.has(event.id), "N20 not completed before final dismissal")
		state.advance()
	_check(record.has(event.id) and not state.is_active() and state.phase.is_empty(), "twentieth paragraph dismissal completes event")
	_check(not state.try_start(second_point, second_point, true), "completed N20 cannot repeat")
	var restored := MapEventState.new(registry, record)
	_check(not restored.try_start(second_point, second_point, true), "N20 stays complete across map reinstantiation")
	var fresh := MapEventState.new(registry, {})
	_check(not fresh.try_start(second_point, second_point, true) and fresh.try_start(POINT, POINT, true), "new run resets completion and prerequisite")
	var first: Dictionary = registry.events[registry.by_point[POINT]].duplicate(true)
	var bad := event.duplicate(true)
	bad.line_speakers[0] = "missing"
	_check(not registry.configure([first, bad], [POINT, second_point]).is_empty(), "unknown speaker rejected")
	bad = event.duplicate(true)
	bad.line_speakers.pop_back()
	_check(not registry.configure([first, bad], [POINT, second_point]).is_empty(), "missing paragraph speaker rejected")
	bad = event.duplicate(true)
	bad.requires_completed = ["missing"]
	_check(not registry.configure([first, bad], [POINT, second_point]).is_empty(), "unknown prerequisite rejected")
	first.requires_completed = [event.id]
	_check(not registry.configure([first, event], [POINT, second_point]).is_empty(), "cyclic prerequisites rejected")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
