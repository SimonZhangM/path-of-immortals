extends "res://tests/shrine_flow_tests.gd"

func optional_icon(number: int) -> void:
	var point: String = SHRINE+".point.n%02d" % number
	var sign: Sprite2D = map.river_story_controller.signs.entries[point].overlay
	check(sign!=null and sign.visible and sign.get_meta("optional",false),"optional story uses golden sign n%d" % number)

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	directory = "res://artifacts/encounter-priority-20261102/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"index.json"
	Session.clear_selection()
	path = Slots.working_path()
	AudioServer.set_bus_mute(0,true)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	render = DisplayServer.get_name()!="headless"
	await switch_to("wumingjiuci",1)
	var fixture := state.snapshot()
	for goal: Dictionary in QuestState.definition.objectives:
		fixture.quests[QuestState.ID].counts[goal.id] = goal.required
	fixture.quests[QuestState.ID].story = QuestStory.initial()
	fixture.quests[QuestState.ID].story.done = ["wake","morning","slope","returning"]
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"isolated shrine story fixture")
	optional_icon(17)
	optional_icon(33)
	var root_sign: Sprite2D = map.river_story_controller.signs.entries[SHRINE+".point.n31"].overlay
	check(root_sign!=null and not root_sign.get_meta("optional"),"main story retains red icon")
	var point := SHRINE+".point.n26"
	var event: Dictionary = map.event_registry.events[map.event_registry.by_point[point]]
	var prior: String = map.travel.adjacency[point][0].to
	place(int(prior.get_slice(".n",1)))
	check(map.travel.request_destination(point),"approach mixed encounter node")
	map.travel.advance(100)
	check(map.event_state.phase=="encounter" and RiverQuest.story(state).active.is_empty(),"mixed node defaults to encounter first")
	check(not RiverQuest.allowed(state,"array"),"story command remains blocked before victory")
	for edge: Dictionary in map.travel.adjacency[point]:
		if map.travel.hidden_points.has(edge.to): continue
		check(map.exploration.revealed.has(edge.to),"arrival reveals connected next node")
	map._retreat_encounter()
	check(map.travel.current_node_id==prior,"cancel returns to actual prior node")
	for edge: Dictionary in map.travel.adjacency[point]:
		if map.travel.hidden_points.has(edge.to): continue
		check(map.exploration.revealed.has(edge.to),"revealed next node remains visible after retreat")
	place(26)
	var won := state.snapshot()
	if not won.has("encounter_cooldowns"): won.encounter_cooldowns = {}
	won.encounter_cooldowns[event.id] = WorldCalendar.current_day(state.calendar)+20
	check(state.restore(won).is_empty(),"saved victory fixture")
	map._sync_calendar(false)
	check(map._try_start_event(point,"click",true) and RiverQuest.story(state).active=="array","victory enables story at mixed node")
	optional_icon(26)
	await shot("golden-array")
	finish_scene("array")
	# A data override permits the specifically authored story-first sequence.
	place(23)
	var configured := MapEventRegistry.encounter_at(SHRINE+".point.n23")
	configured.trigger_order = "story_first"
	map.river_story_controller.refresh()
	check(map._try_start_event(SHRINE+".point.n23","click",true) and RiverQuest.story(state).active=="stone_door","explicit story-first override is honored")
	optional_icon(23)
	place(33)
	await shot("golden-stone-and-door")
	place(23)
	finish_scene("stone_door")
	check(map.event_state.phase=="encounter","story-first flows into encounter after dialogue")
	map._retreat_encounter()
	configured.erase("trigger_order")
	var invalid := event.duplicate(true)
	invalid.trigger_order = "unknown"
	check(not MapEventRegistry.new().configure([invalid],[point]).is_empty(),"invalid trigger order rejected")
	place(17)
	await shot("golden-ali")
	# Reusing a node for a main/optional story also replaces its motion binding.
	var overlays = map.river_story_controller.signs
	var wanted: Array[String] = [SHRINE+".point.n17"]
	overlays.show_at(wanted)
	check(not overlays.entries[wanted[0]].overlay.get_meta("optional"),"icon switches back to main when category changes")
	overlays.show_at(wanted,wanted)
	optional_icon(17)
	check((load("res://assets/map-juqingo.webp") as Texture2D).get_image().has_mipmaps(),"golden icon mipmaps enabled")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("ENCOUNTER PRIORITY: %d checks, %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
