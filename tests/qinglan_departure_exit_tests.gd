extends "res://tests/diecuifeng_tests.gd"
## Only the chapter-four exit gate, its saved facts and the real round trip.

const Departure := preload("res://scripts/quests/qinglan_departure_quest.gd")
const EXIT_POINT := TOWN + ".point.n02"

func departure_fixture(base: Dictionary, done_steps: Array) -> Dictionary:
	var fixture := base.duplicate(true)
	var saved: Dictionary = Departure.initial()
	saved.accepted_location = Departure.data.accepted_location
	saved.done = done_steps.duplicate()
	saved.token_received = "outpost" in done_steps
	fixture.quests[Departure.ID] = saved
	for step: String in ["mother", "pharmacy", "clinic", "outpost"]:
		fixture.narrative.flags["base.story.qinglanchujie."+step+"_done"] = step in done_steps
	return fixture

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	output = "res://artifacts/qinglan-departure-exit-20261110/run-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output)
	save_path = output + "/live_session.json"
	MapLoadoutStore.GameSaveSession.index_path = output + "/index.json"
	MapLoadoutStore.GameSaveSession.clear_selection()
	var town := await boot("qingshizhen", EXIT_POINT)
	if not town.startup_error.is_empty(): quit(1); return
	check(Departure.configuration_error().is_empty(), "updated dialogue configuration loads")
	var original: Dictionary = town.loadout.snapshot()
	var exit_config: Dictionary = town.exits_by_point[EXIT_POINT]
	check(town._try_open_exit(EXIT_POINT), "locked exit still explains why travel is unavailable")
	check(town.exit_dialog.confirm_button.disabled and town.exit_dialog.error_label.text == exit_config.locked_hint, "before main four, travel confirmation is disabled")
	town._complete_exit()
	check(find_map(PEAK) == null and town.loadout.snapshot() == original, "direct transition completion cannot bypass the gate")
	town._cancel_exit()
	for done_steps: Array in [["mother"], ["mother", "outpost"], ["mother", "pharmacy", "clinic"], ["mother", "pharmacy", "outpost"], ["mother", "clinic", "outpost"]]:
		check(town.loadout.restore(departure_fixture(original, done_steps)).is_empty(), "partial departure state valid")
		check(not town._exit_lock_hint(exit_config).is_empty() and Departure.display_entry(town.loadout, {}).stage_id != "road", "every unfinished town conversation keeps the exit locked: " + str(done_steps))
	# Existing single-flag exits remain independent of the new all-flags gate.
	var village: Dictionary = town.exits_by_point[TOWN + ".point.n30"]
	check(not town._exit_lock_hint(village).is_empty(), "village retains its original quest condition")
	town.loadout.narrative.flags[village.required_story_flag] = true
	check(town._exit_lock_hint(village).is_empty(), "original single-flag exit still unlocks")
	check(town._exit_lock_hint(town.exits_by_point[TOWN + ".point.n04"]).is_empty(), "ungated slope exit unchanged")
	# Complete the actual final line; receiving the token earlier was insufficient.
	var ending := departure_fixture(original, ["mother", "pharmacy", "outpost"])
	ending.quests[Departure.ID].active = "clinic"
	ending.quests[Departure.ID].line = Departure.data.scenes.clinic.lines.size() - 1
	ending.quests[Departure.ID].location = Departure.data.locations.clinic.duplicate(true)
	check(town.loadout.restore(ending).is_empty(), "clinic final-line save valid")
	check(not Departure.command(town.loadout, output+"/missing/save.json", "advance").is_empty() and not town._exit_lock_hint(exit_config).is_empty(), "failed completion save does not unlock travel")
	check(Departure.command(town.loadout, save_path, "advance").is_empty(), "final conversation commits successfully")
	check(Departure.display_entry(town.loadout, {}).stage_id == "road" and town._exit_lock_hint(exit_config).is_empty(), "mountain objective and exit unlock on the same completion")
	check(Departure.display_entry(town.loadout, {}).objectives.back().text == "沿山路抵达青岚宗", "unlocks at the requested objective")
	# Reload proves already-completed saves need no new unlock flag or replay.
	town.queue_free()
	await settle()
	town = await boot("qingshizhen", EXIT_POINT)
	check(town._exit_lock_hint(town.exits_by_point[EXIT_POINT]).is_empty(), "saved four-conversation facts unlock immediately on reload")
	check(town._try_open_exit(EXIT_POINT) and not town.exit_dialog.confirm_button.disabled, "ready travel confirmation enabled")
	town.exit_dialog.confirm_button.pressed.emit()
	while is_instance_valid(town): await process_frame
	var peak := find_map(PEAK)
	check(peak != null and peak.travel.current_node_id == PEAK+".point.n01", "confirmed travel arrives at peak entrance")
	if peak != null:
		check(peak._try_open_exit(PEAK+".point.n01") and not peak.exit_dialog.confirm_button.disabled, "return to town remains available")
		peak.exit_dialog.confirm_button.pressed.emit()
		while is_instance_valid(peak): await process_frame
		town = find_map(TOWN)
		check(town != null and town.travel.current_node_id == EXIT_POINT, "return arrives at town north exit")
	# Reject malformed gate data before any exit configuration replaces the valid set.
	if town != null:
		for invalid: Variant in ["not-an-array", [17], ["wrong.flag"]]:
			var broken: Dictionary = town.exits_by_point[EXIT_POINT].duplicate(true)
			broken.required_story_flags = invalid
			check(not town._configure_exits([broken]).is_empty(), "malformed all-flags condition rejected")
		var missing_hint: Dictionary = town.exits_by_point[EXIT_POINT].duplicate(true)
		missing_hint.erase("locked_hint")
		check(not town._configure_exits([missing_hint]).is_empty(), "gated exit requires a player-facing hint")
		town.queue_free()
	await settle()
	var result := {"checks": checks, "failures": failures, "output": output}
	FileAccess.open(output+"/validation.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("QINGLAN DEPARTURE EXIT: "+JSON.stringify(result))
	quit(1 if failures else 0)
