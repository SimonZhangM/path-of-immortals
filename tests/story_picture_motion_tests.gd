extends "res://tests/river_quest_tests.gd"

const CAPTION := "（你通过古镜看到了一些奇怪的场景。）"

func group_step(seconds: float) -> void:
	var tween: Tween = map.dialogue.picture._group_tween
	if tween!=null:
		tween.pause()
		tween.custom_step(seconds)
func image_step(seconds: float) -> void:
	var tween: Tween = map.dialogue.picture._image_tween
	if tween!=null:
		tween.pause()
		tween.custom_step(seconds)
func display(model: Variant, id: String, index := -1, phase := "dialogue") -> void:
	var event: Dictionary = model.event(id)
	if index<0: index = int(event.get("illustration",{}).get("start_line",0))
	map.dialogue.present(event,event.lines[index],event.line_speakers[index],phase,index)
func close_picture() -> void:
	map.dialogue.dismiss()
	group_step(0.181)
func caption_unchanged() -> void:
	check(map.dialogue.text_label.visible and map.dialogue.text_label.get_parsed_text()==CAPTION,"gallery caption remains visible and unchanged")
	check(map.dialogue.portrait.visible and map.dialogue.portrait_rim.visible and map.dialogue.speaker_name.visible,"gallery retains player presentation")

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	directory = "res://artifacts/story-picture-motion-20261103/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("qingshihewan",15)
	var before := state.snapshot()
	var picture: MapEventPicture = map.dialogue.picture
	# Sample tween time directly: rendering frames cannot make timing assertions flaky.
	display(QuestStory,"wake")
	check(picture.visible and picture.requested_visible and is_zero_approx(picture.modulate.a),"new picture starts transparent")
	var first_rect := picture.get_rect()
	group_step(0.125)
	check(is_equal_approx(picture.modulate.a,0.5),"whole group at half opacity after 0.125 seconds")
	check(picture.frame.modulate.a==1 and picture.illustration.modulate.a==1,"frame and image inherit the same group fade")
	check(picture.get_rect().is_equal_approx(first_rect),"fade preserves geometry")
	await shot("whole-enter-half-1080p")
	group_step(0.126)
	check(picture.modulate.a==1 and picture._group_tween==null,"entry finishes at 0.25 seconds")
	display(QuestStory,"wake",1)
	check(picture._group_tween==null and picture._image_tween==null,"same image on next line does not restart motion")
	map.dialogue.dismiss()
	check(picture.visible and not picture.requested_visible and map.dialogue.visible,"dialogue exit retains outgoing picture layer")
	check(not map.dialogue.text_label.visible,"only picture group has the requested exit fade")
	group_step(0.09)
	check(is_equal_approx(picture.modulate.a,0.5),"exit half opacity at 0.09 seconds")
	await shot("whole-exit-half-1080p")
	group_step(0.091)
	check(not picture.visible and not map.dialogue.visible,"picture and owner hide after 0.18 seconds")
	var bindings := [[QuestStory,"wake"],[QuestStory,"morning"],[HerbQuest,"intro"],
		[RiverQuest,"injured"],[RiverQuest,"fox_notice"],[RiverQuest,"fox_choice"],
		[RiverQuest,"fox_release"],[RiverQuest,"medicine"],[RiverQuest,"return_jade"],
		[RiverQuest,"invite_doctor"],[RiverQuest,"pickup"],[RiverQuest,"clinic_arrival"],
		[RiverQuest,"gift_book"],[RiverQuest,"closing"]]
	for binding: Array in bindings:
		display(binding[0],binding[1])
		check(picture.requested_visible and is_zero_approx(picture.modulate.a),"shared entry for "+binding[1])
		group_step(0.251)
		check(picture.modulate.a==1,"entry completion for "+binding[1])
		close_picture()
		check(not picture.visible and not map.dialogue.visible,"shared exit for "+binding[1])
	# Different scene IDs can reuse the same atlas crop and source image.
	display(RiverQuest,"medicine")
	group_step(0.251)
	map.dialogue.dismiss()
	display(RiverQuest,"return_jade")
	check(picture.modulate.a==1 and picture._group_tween==null and picture._image_tween==null,"same-frame same-image scene continuation stays steady")
	display(RiverQuest,"injured",1)
	check(picture._group_tween==null and picture._image_tween!=null,"other same-frame changes also crossfade only inside")
	image_step(0.121)
	close_picture()
	display(RiverQuest,"mirror",4,"illustration")
	group_step(0.251)
	caption_unchanged()
	var frame_node := picture.frame.get_instance_id()
	var frame_texture: Texture2D = picture.frame.texture
	var frame_rect := picture.get_rect()
	var dialogue_rect: Rect2 = map.dialogue.background.get_rect()
	display(RiverQuest,"mirror",6,"illustration")
	check(picture._group_tween==null and picture.modulate.a==1,"gallery frame stays fully opaque")
	check(picture.previous_illustration.visible and picture.previous_illustration.texture.resource_path=="res://assets/map-event-2-3.webp","old image remains under new page")
	check(picture.illustration.texture.resource_path=="res://assets/map-event-2-4.webp" and is_zero_approx(picture.illustration.modulate.a),"next page starts transparent")
	image_step(0.06)
	check(is_equal_approx(picture.illustration.modulate.a,0.5),"internal image mix at half of 0.12 seconds")
	check(picture.get_rect().is_equal_approx(frame_rect) and picture.frame.texture==frame_texture and picture.frame.get_instance_id()==frame_node,"same frame and geometry throughout page change")
	check(map.dialogue.background.get_rect().is_equal_approx(dialogue_rect),"dialogue stays fixed during page change")
	caption_unchanged()
	await shot("gallery-crossfade-half-1080p")
	root.size = Vector2i(2560,1440)
	await settle()
	caption_unchanged()
	await shot("gallery-crossfade-half-2k")
	image_step(0.061)
	check(picture.illustration.modulate.a==1 and not picture.previous_illustration.visible,"crossfade completes without residual image")
	display(RiverQuest,"mirror",8,"illustration")
	image_step(0.02)
	display(RiverQuest,"mirror",4,"illustration")
	image_step(0.121)
	check(picture.illustration.texture.resource_path=="res://assets/map-event-2-3.webp" and not picture.previous_illustration.visible,"rapid page changes keep latest requested image")
	display(RiverQuest,"mirror",9)
	check(not picture.requested_visible and picture.visible,"last-page exit fades picture while following dialogue appears")
	check(map.dialogue.text_label.visible and map.dialogue.text_label.get_parsed_text()=="怎么又没了……","following dialogue resumes immediately")
	group_step(0.09)
	display(RiverQuest,"mirror",8,"illustration")
	group_step(0.251)
	image_step(0.121)
	check(picture.visible and picture.requested_visible and map.dialogue.visible and picture.modulate.a==1,"new picture cancels stale outgoing hide callback")
	caption_unchanged()
	# A truly changed border gets full-group out/in rather than gallery treatment.
	var alternate_frame := (picture.frame.texture as AtlasTexture).duplicate() as AtlasTexture
	alternate_frame.region.size.x -= 1
	picture.configure(alternate_frame,picture.illustration.texture,[62,91,1349,758])
	group_step(0.09)
	check(is_equal_approx(picture.modulate.a,0.5),"changed border fades old group out")
	group_step(0.091)
	check(picture.frame.texture==alternate_frame and is_zero_approx(picture.modulate.a),"changed border installed between exit and entry")
	group_step(0.251)
	check(picture.modulate.a==1,"changed-border group fades in")
	close_picture()
	for controller in [map.quest_story_controller,map.herb_story_controller,map.river_story_controller]:
		display(RiverQuest,"injured",1)
		group_step(0.251)
		if controller==map.river_story_controller: controller.finish("blocked_exit")
		else: controller.finish()
		check(picture.visible and not picture.requested_visible,"quest controller preserves outgoing fade")
		group_step(0.181)
		check(not picture.visible and not map.dialogue.visible,"quest controller exits cleanly after fade")
	display(RiverQuest,"injured",1)
	group_step(0.251)
	map._present_event_progress("base.map_event.test.motion_complete")
	check(picture.visible and not picture.requested_visible,"registered event preserves outgoing fade")
	group_step(0.181)
	check(not picture.visible and not map.dialogue.visible,"registered event finishes fade cleanly")
	check(state.snapshot()==before,"presentation motion leaves inventory and quest state unchanged")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	map = null
	picture = null
	alternate_frame = null
	await settle()
	print("STORY PICTURE MOTION: %d checks; %d failures; no mouse or combat. %s"%[checks,failures,directory])
	quit(1 if failures else 0)
