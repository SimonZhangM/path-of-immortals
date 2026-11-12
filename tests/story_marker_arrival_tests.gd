extends "res://tests/clinic_herb_quest_tests.gd"

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/story-marker-arrival-20261103/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	path = Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	await switch_to("qingshizhen",31)
	var fixture := state.snapshot()
	for objective: Dictionary in QuestState.definition.objectives:
		fixture.quests[QuestState.ID].counts[objective.id] = objective.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	check(state.restore(fixture).is_empty(),"completed first main fixture")
	check(state.add_reward({"id":"base.map_reward.test.marker_herbs","item_id":HerbQuest.data.item_id,"quantity":2}).is_empty(),"carry herbs before clinic request")
	arrive(32)
	check(HerbQuest.story(state).active=="intro","gold introduction marker triggers on arrival")
	finish_herb_scene("intro")
	check(not map.event_state.is_active(),"request finishes with free movement")
	check(HerbQuest.has_clinic_marker(state),"gold delivery marker available")
	var herbs := HerbQuest.quantity(state)
	var stones := state.spirit_stones
	arrive(31)
	arrive(32)
	check(HerbQuest.story(state).active=="delivery" and map.dialogue.visible,"gold delivery marker triggers on arrival")
	check(HerbQuest.quantity(state)==herbs and state.spirit_stones==stones,"arrival starts dialogue without settlement")
	finish_herb_scene("delivery")
	map._accept_reward()
	check(HerbQuest.story(state).completed and not HerbQuest.has_clinic_marker(state),"completed errand removes marker")
	arrive(31)
	arrive(32)
	check(not map.event_state.is_active(),"ordinary clinic does not open on arrival after completion")
	var mother := FileAccess.get_file_as_string("res://data/dialogues/mother.json")
	check(not mother.contains("您"),"mother chat uses familiar address throughout")
	for line in ["娘，你认得它？","我不太确定，印象中好像叫……照尘镜。娘的先人可能曾经用过。","可爹后来出了那场风暴……这么多年仍旧杳无音讯。"]:
		check(mother.contains(line),"requested mother dialogue: "+line)
	check(not JSON.stringify(HomecomingQuest.data.scenes.reunion.lines).contains("您"),"reunion uses familiar address")
	check(HomecomingQuest.data.scenes.intro.lines[7].contains("您"),"elder Ye retains his existing address")
	# Optional shrine stories use the same arrival path as their ordinary markers.
	var optional_fixture := state.snapshot()
	optional_fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance"]
	optional_fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	var encounter := MapEventRegistry.encounter_at(RiverQuest.data.scenes.array.point_id)
	check(not MapEventRegistry.story_allowed(state,RiverQuest.data.scenes.array.point_id),"uncleared encounter gates the optional story marker")
	optional_fixture.encounter_cooldowns = optional_fixture.get("encounter_cooldowns",{})
	optional_fixture.encounter_cooldowns[encounter.id] = WorldCalendar.current_day(state.calendar)+1
	check(state.restore(optional_fixture).is_empty(),"optional shrine fixture")
	check(MapLoadoutStore.save(state,path).is_empty(),"save optional fixture")
	await switch_to("wumingjiuci",26)
	check(RiverQuest.story(state).active=="array","ordinary shrine marker starts its story on arrival")
	finish_scene("array")
	check(RiverQuest.arrival(state,RiverQuest.SHRINE,RiverQuest.data.scenes.array.point_id).is_empty(),"completed optional story does not repeat on arrival")
	var result := {"checks":checks,"failures":failures,"directory":directory}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STORY_MARKER_ARRIVAL "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
