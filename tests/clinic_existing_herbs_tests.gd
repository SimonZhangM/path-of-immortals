extends "res://tests/clinic_herb_quest_tests.gd"

func click_at(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()

func focus_clinic() -> void:
	var point: Vector2 = map.travel.node_positions[HerbQuest.data.clinic.point_id]
	map.content.position = map.map_viewport.size*0.5-point*map.content.scale
	map._clamp_position()

func restore_ready(ready: Dictionary) -> void:
	check(state.restore(ready).is_empty(),"restore accepted ready-to-deliver fixture")
	if map.reward_dialog!=null: map.reward_dialog.hide()
	map.herb_story_controller.finish()
	check(MapLoadoutStore.save(state,path).is_empty(),"persist ready fixture")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/clinic-existing-herbs-20261102/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	path = Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	render = DisplayServer.get_name()!="headless"
	await switch_to("qingshizhen",31)
	var fixture := state.snapshot()
	for id: String in fixture.quests[QuestState.ID].counts: fixture.quests[QuestState.ID].counts[id] = 1
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	for id: String in fixture.owned_units.keys():
		if fixture.owned_units[id]==HerbQuest.data.item_id: fixture.owned_units.erase(id)
	check(state.restore(fixture).is_empty(),"first main completed before side acceptance")
	check(state.add_reward({"id":"base.map_reward.test.existing_herbs","item_id":HerbQuest.data.item_id,"quantity":2}).is_empty(),"herbs already carried before accepting side quest")
	check(MapLoadoutStore.save(state,path).is_empty(),"save pre-existing stock")
	arrive(32)
	finish_herb_scene("intro")
	check(HerbQuest.accepted(state) and HerbQuest.quantity(state)==2 and entry().stage_id=="returning","side accepts pre-existing stock immediately")
	check(not map.event_state.is_active() and not HerbQuest.story(state).completed,"acceptance does not automatically consume or submit")
	check(HerbQuest.arrival(state,map.definition.id,HerbQuest.data.clinic.point_id).is_empty(),"arrival does not auto-start delivery")
	check(HerbQuest.interaction(state,map.definition.id,HerbQuest.data.clinic.point_id)=="delivery","explicit interaction offers immediate delivery")
	var ready: Dictionary = state.snapshot().duplicate(true)
	var stones: int = state.spirit_stones
	focus_clinic()
	await settle()
	await click_at(map.map_to_screen(map.travel.node_positions[HerbQuest.data.clinic.point_id]))
	check(HerbQuest.story(state).active=="delivery" and map.dialogue.visible,"actual stationary node click opens delivery dialogue")
	check(HerbQuest.quantity(state)==2 and state.spirit_stones==stones,"opening dialogue neither consumes herbs nor pays")
	if render:
		await shot("existing-stock-node-dialogue")
		map._advance_dialogue()
		await switch_to("qingshizhen",32)
		check(HerbQuest.story(state).active=="delivery" and HerbQuest.story(state).line==1,"delivery cursor from pre-existing stock resumes")
	else:
		for dimensions in [Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size = dimensions
			await settle()
			for zoom in [1.0,1.75]:
				restore_ready(ready)
				map.zoom_factor = zoom
				map._fit_map()
				focus_clinic()
				await settle()
				var markers: Node2D = map.quest_tracker_controller.markers
				check(markers.get_child_count()==1,"ready delivery pointer present")
				var art: Control = markers.get_child(0).get_child(0)
				var canvas: Vector2 = art.get_global_transform_with_canvas()*(art.size*0.5)
				var local: Vector2 = map.get_global_transform_with_canvas().affine_inverse()*canvas
				check(map._node_at(local)==HerbQuest.data.clinic.point_id,"animated pointer hit resolves across resolution/pan/zoom")
				await click_at(canvas)
				check(HerbQuest.story(state).active=="delivery" and map.dialogue.visible,"actual location artwork click opens delivery")
				check(HerbQuest.quantity(state)==2 and state.spirit_stones==stones,"pointer click does not settle early")
		map._advance_dialogue()
		await switch_to("qingshizhen",32)
		check(HerbQuest.story(state).line==1,"pointer-started dialogue resumes after reload")
	finish_herb_scene("delivery")
	check(map.reward_dialog.visible and HerbQuest.quantity(state)==2,"reward waits for confirmation")
	await shot("existing-stock-reward")
	await click(map.reward_dialog.accept_button)
	check(HerbQuest.story(state).completed and HerbQuest.quantity(state)==1 and state.spirit_stones==stones+3,"confirm consumes exactly one old herb and grants three stones")
	var completed := state.snapshot()
	check(HerbQuest.command(state,path,"accept").is_empty() and state.snapshot()==completed,"repeat confirmation cannot pay again")
	map._try_start_event(HerbQuest.data.clinic.point_id,"click",true)
	check(map.event_state.phase=="clinic" and not map.clinic_dialog.herb_quest_button.visible,"completed node returns to ordinary clinic")
	map._close_clinic()
	if not render:
		restore_ready(ready)
		var neighbor: String = map.travel.adjacency[HerbQuest.data.clinic.point_id][0].to
		arrive(int(neighbor.get_slice(".",4).trim_prefix("n")))
		focus_clinic()
		await settle()
		var art: Control = map.quest_tracker_controller.markers.get_child(0).get_child(0)
		await click_at(art.get_global_transform_with_canvas()*(art.size*0.5))
		check(HerbQuest.story(state).active.is_empty() and map.travel.mode!="idle","pointer away from node only requests travel")
		map.travel.stop_at_current_node()
		arrive(32)
		check(not map.event_state.is_active(),"arrival after pointer travel still waits for another click")
		var full := ready.duplicate(true)
		full.spirit_stones = 1000000000
		check(state.restore(full).is_empty() and HerbQuest.interaction(state,map.definition.id,HerbQuest.data.clinic.point_id).is_empty(),"wallet limit preserves dismissible ordinary clinic path")
	Meta.stop()
	map.deactivate_location()
	map.free()
	map = null
	state = null
	await settle()
	print("EXISTING HERBS: %d checks, %d failures; output %s"%[checks,failures,directory])
	quit(1 if failures else 0)
