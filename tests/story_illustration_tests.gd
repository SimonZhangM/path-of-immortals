extends "res://tests/river_quest_tests.gd"

const Art = preload("res://scripts/dialogue/dialogue_illustration.gd")
const MIRROR_TEXT := "（你通过古镜看到了一些奇怪的场景。）"

func shot(label: String) -> void:
	if render:
		await create_timer(0.27).timeout
		await capture(label)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/scene-art-20261103/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	path = Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	var settings := root.get_node("GameSettings")
	settings.apply_values({"background_pause":false,"background_mute":false,"dialogue_speed":"instant","dialogue_auto":false})
	settings.set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	render = DisplayServer.get_name()!="headless"
	var focused_scene := OS.get_environment("STORY_ART_SCENE_ONLY")
	if OS.get_environment("STORY_ART_FOX_RELEASE_ONLY")=="1": focused_scene = "fox_release"
	if focused_scene in ["fox_release","medicine"]:
		await switch_to("qingshihewan",20 if focused_scene=="medicine" else 2)
		var focused_event := RiverQuest.event(focused_scene)
		var first_picture_line := 6 if focused_scene=="medicine" else 1
		var indices := [0,4,5,6,focused_event.lines.size()-1] if focused_scene=="medicine" else [0,1,focused_event.lines.size()-1]
		var picture_path := "res://assets/map-event-2-6.webp" if focused_scene=="medicine" else "res://assets/map-event-2-2b.webp"
		for dimensions in [Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size = dimensions
			await settle()
			for index in indices:
				map.dialogue.present(focused_event,focused_event.lines[index],focused_event.line_speakers[index],"dialogue",index)
				check(map.dialogue.picture.requested_visible==(index>=first_picture_line),"picture follows specified action: "+focused_scene)
				check(map.dialogue.text_label.visible and map.dialogue.text_label.get_parsed_text()==focused_event.lines[index],"dialogue retained")
				if index>=first_picture_line: check(map.dialogue.picture.illustration.texture.resource_path==picture_path,"correct illustration")
				if index==first_picture_line: await shot("%s-%d"%[focused_scene,dimensions.x])
		if focused_scene=="medicine":
			var following_event := RiverQuest.event("return_jade")
			map.dialogue.present(following_event,following_event.lines[0],following_event.line_speakers[0],"dialogue",0)
			check(map.dialogue.picture.visible,"jade return still carries previous picture")
			check(map.dialogue.picture.illustration.texture.resource_path==picture_path,"jade return retains medicine art")
		print("FOCUSED_ILLUSTRATION scene=%s checks=%d failures=%d directory=%s"%[focused_scene,checks,failures,directory])
		map.deactivate_location()
		map.free()
		quit(1 if failures else 0)
		return
	if OS.get_environment("STORY_ART_CLINIC_ONLY")=="1":
		await switch_to("qingshizhen",32)
		var clinic_event := RiverQuest.event("invite_doctor")
		for index in [0,8,clinic_event.lines.size()-1]:
			map.dialogue.present(clinic_event,clinic_event.lines[index],clinic_event.line_speakers[index],"dialogue",index)
			check(map.dialogue.picture.visible,"2-7 visible throughout clinic request")
			check(map.dialogue.picture.illustration.texture.resource_path=="res://assets/map-event-2-7.webp","2-7 correct asset")
		check(map.dialogue.picture.illustration.texture.get_image().has_mipmaps(),"2-7 mipmaps imported")
		await shot("invite-doctor-1080p")
		FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"clinic-2-7"}))
		print("CLINIC_ILLUSTRATION checks=%d failures=%d directory=%s"%[checks,failures,directory])
		map.free()
		quit(1 if failures else 0)
		return
	await switch_to("qingshihewan",15)
	if OS.get_environment("STORY_ART_MIRROR_ONLY")!="1":
		var bindings := [
			[QuestStory,"wake","1-1"],[QuestStory,"morning","1-2"],
			[HerbQuest,"intro","z1-1"],[RiverQuest,"injured","2-1"],
			[RiverQuest,"fox_notice","2-2a"],[RiverQuest,"fox_choice","2-2a"],
			[RiverQuest,"fox_release","2-2b"],[RiverQuest,"medicine","2-6"],
			[RiverQuest,"return_jade","2-6"],[RiverQuest,"pickup","2-8"],
			[RiverQuest,"clinic_arrival","2-9"],[RiverQuest,"gift_book","2-9"],[RiverQuest,"closing","2-9"]]
		for binding: Array in bindings:
			var event: Dictionary = binding[0].event(binding[1])
			var index: int = event.get("illustration",{}).get("start_line",0)
			map.dialogue.present(event,event.lines[index],event.line_speakers[index],"dialogue",index)
			check(map.dialogue.picture.visible,"picture visible "+binding[1])
			check(map.dialogue.picture.illustration.texture.resource_path=="res://assets/map-event-"+binding[2]+".webp","asset binding "+binding[1])
			check(map.dialogue.picture.frame.texture.region==Rect2(101,17,1471,907),"shared frame crop "+binding[1])
			check(map.dialogue.picture._slot==Rect2(62,91,1349,758),"shared image window "+binding[1])
			if binding[1] in ["wake","morning","intro","fox_notice","fox_release","medicine","pickup","clinic_arrival"]:
				await shot(binding[1]+"-1080p")
		var event := RiverQuest.event("injured")
		map.dialogue.present(event,event.lines[0],event.line_speakers[0],"dialogue",0)
		check(not map.dialogue.picture.requested_visible,"observation before injured picture")
		map.dialogue.present(event,event.lines[1],event.line_speakers[1],"dialogue",1)
		check(map.dialogue.picture.visible,"picture appears after observation")
		await shot("injured-1080p")
		event = RiverQuest.event("invite_doctor")
		map.dialogue.present(event,event.lines[8],event.line_speakers[8],"dialogue",8)
		check(map.dialogue.picture.visible and map.dialogue.picture.illustration.texture.resource_path=="res://assets/map-event-2-7.webp","clinic request uses supplied 2-7")
	var fixture := state.snapshot()
	for id: String in fixture.quests[QuestState.ID].counts: fixture.quests[QuestState.ID].counts[id] = 1
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","courtyard_check"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"mirror prerequisite fixture")
	check(MapLoadoutStore.save(state,path).is_empty(),"save fixture")
	await switch_to("wumingjiuci",5)
	check(RiverQuest.story(state).active=="mirror","mirror begins at altar")
	for i in 3: map._advance_dialogue()
	check(RiverQuest.story(state).line==3 and not map.dialogue.picture.requested_visible,"this mirror line before gallery")
	settings.apply_values({"dialogue_speed":"slow"})
	await click(map.dialogue)
	check(RiverQuest.story(state).line==4,"mouse starts first image")
	var fixed_rect: Rect2 = map.dialogue.picture.get_rect()
	var fixed_frame: Texture2D = map.dialogue.picture.frame.texture
	var fixed_node: int = map.dialogue.picture.frame.get_instance_id()
	for page in 3:
		check(RiverQuest.picture_page(RiverQuest.story(state))==page,"gallery page "+str(page))
		check(map.dialogue.picture.illustration.texture.resource_path=="res://assets/map-event-2-%d.webp"%(page+3),"gallery image order")
		check(map.dialogue.picture.get_rect().is_equal_approx(fixed_rect),"frame geometry stays fixed between clicks")
		check(map.dialogue.picture.frame.texture==fixed_frame,"frame texture stays fixed between clicks")
		check(map.dialogue.picture.frame.get_instance_id()==fixed_node,"frame node stays fixed between clicks")
		check(map.dialogue._phase=="illustration" and map.dialogue.text_label.visible and not map.dialogue.next_marker.visible,"gallery retains dialogue without ordinary next marker")
		check(map.dialogue.background.visible and map.dialogue.portrait.visible and map.dialogue.portrait_rim.visible and map.dialogue.speaker_name.visible,"gallery retains player's complete dialogue layer")
		check(map.dialogue.text_label.get_parsed_text()==MIRROR_TEXT and not map.dialogue.playback.is_revealing(),"same caption fully visible even at slow speed")
		check(map.dialogue.speaker_name.text==map.player_status.display_name,"gallery caption belongs to player")
		check(map.travel.paused and map.event_state.is_active(),"gallery blocks map movement")
		settings.apply_values({"dialogue_auto":true})
		map.dialogue._process(60.0)
		check(RiverQuest.picture_page(RiverQuest.story(state))==page,"auto playback cannot skip image")
		settings.apply_values({"dialogue_auto":false})
		var snapshot := state.snapshot()
		check(not RiverQuest.command(state,directory+"missing/fail.json","advance").is_empty(),"page save failure returned")
		check(state.snapshot()==snapshot,"page save failure preserves exact state")
		await shot("mirror-page-%d-1080p"%page)
		if render and page==0:
			root.size = Vector2i(2560,1440)
			await shot("mirror-page-0-2k")
			root.size = Vector2i(1920,1080)
			await settle()
		await switch_to("wumingjiuci",5)
		check(RiverQuest.picture_page(RiverQuest.story(state))==page and map.dialogue.picture.visible,"page restores through map reload")
		check(map.dialogue.text_label.visible and map.dialogue.text_label.get_parsed_text()==MIRROR_TEXT,"caption also restores on every page")
		fixed_frame = map.dialogue.picture.frame.texture
		fixed_node = map.dialogue.picture.frame.get_instance_id()
		await click(map.dialogue)
	check(RiverQuest.story(state).line==9,"last image click resumes at next spoken line")
	check(not map.dialogue.picture.requested_visible and map.dialogue.text_label.visible and map.dialogue._phase=="dialogue","last image closes frame and resumes speech")
	check(map.dialogue.text_label.get_parsed_text()=="怎么又没了……","third-page click replaces caption with following dialogue")
	await shot("mirror-resumed-1080p")
	for old_line in [4,5,6,7,8]:
		var old := state.snapshot()
		old.quests[RiverQuest.ID].line = old_line
		check(state.restore(old).is_empty(),"old textual vision cursor remains valid")
		map.river_story_controller.present()
		var expected := 0 if old_line<6 else (1 if old_line<8 else 2)
		check(RiverQuest.picture_page(RiverQuest.story(state))==expected and map.dialogue.picture.visible,"old vision cursor maps to same scene")
		check(map.dialogue.text_label.visible and map.dialogue.text_label.get_parsed_text()==MIRROR_TEXT,"legacy page cursor receives the same fixed caption")
		check(RiverQuest.command(state,path,"advance").is_empty(),"legacy vision advances")
		check(RiverQuest.story(state).line==([6,8,9][expected]),"legacy cursor advances to following picture or dialogue")
	finish_scene("mirror")
	check(RiverQuest.done(state,"mirror") and state.narrative.flags.get("base.story.hewanfengxian.broken_mirror",false),"gallery completes ordinary story fact")
	var result := {"checks":checks,"failures":failures,"render":render,"directory":directory}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STORY_ILLUSTRATION "+JSON.stringify(result))
	map.free()
	quit(1 if failures else 0)
