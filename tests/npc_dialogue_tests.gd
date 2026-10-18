extends "res://tests/clinic_dialog_tests.gd"

const NPC := "base.npc.suqinghe"
const PREFIX := "base.dialogue.suqinghe."

func finish(narrative: Dictionary, library: NpcDialogueLibrary, day: int) -> void:
	var guard := 0
	while DialogueJournal.view(narrative,library,{}).can_continue and guard<30:
		DialogueJournal.advance(narrative,library,day)
		guard += 1
	check(guard<30,"segment terminates")

func model_checks(map: Node, library: NpcDialogueLibrary) -> void:
	var narrative := DialogueJournal.initial()
	check(DialogueJournal.visit(narrative,library,0).is_empty(),"first welcome starts")
	var partial := narrative.duplicate(true)
	DialogueJournal.visit(narrative,library,0)
	check(narrative==partial,"same visit never repeats greeting or advances reading")
	check(not DialogueJournal.select(narrative,library,"medical",0,{}).is_empty(),"greeting completes before topics")
	finish(narrative,library,0)
	check(DialogueJournal.view(narrative,library,{}).topics.size()==3,"three independent topics unlocked")
	DialogueJournal.select(narrative,library,"medical",0,{})
	DialogueJournal.advance(narrative,library,0)
	DialogueJournal.select(narrative,library,"family",0,{})
	DialogueJournal.select(narrative,library,"medical",0,{})
	check(int(narrative.npcs[NPC].seen[PREFIX+"medical.01"])==2,"switching topics resumes exact line")
	check(int(narrative.npcs[NPC].seen[PREFIX+"family.01"])==1,"other topic progress retained")
	for stage in 4:
		DialogueJournal.select(narrative,library,"medical",0,{})
		finish(narrative,library,0)
	check(narrative.clues.get("base.clue.qingshihewan.herb_anomaly")=="青石河湾药材异常","final medical speech records clue")
	check(DialogueJournal.view(narrative,library,{}).topics[0].label=="医馆近况","completed topic returns to original label")
	partial = narrative.duplicate(true)
	DialogueJournal.select(narrative,library,"medical",0,{})
	DialogueJournal.advance(narrative,library,0)
	check(narrative==partial,"archive click and continue never replay or regrant clue")
	var branching := NpcDialogueLibrary.new()
	var branch_data := library.definition.duplicate(true)
	branch_data.segments[PREFIX+"family.02"].requires_points = [{"map_id":"base.map.qingshihewan","point_id":"base.map.qingshihewan.point.n01"}]
	check(branching.configure(branch_data).is_empty(),"future exploration-conditioned branch accepted")
	DialogueJournal.select(narrative,library,"family",0,{})
	finish(narrative,library,0)
	check(DialogueJournal.next_segment(narrative,branching,"family",{}).is_empty(),"unvisited point gates branch")
	check(DialogueJournal.next_segment(narrative,branching,"family",{"base.map.qingshihewan":["base.map.qingshihewan.point.n01"]})==PREFIX+"family.02","real exploration fact unlocks branch")
	for stage in 3:
		DialogueJournal.select(narrative,library,"chat",0,{})
		finish(narrative,library,0)
	DialogueJournal.visit(narrative,library,0)
	check(DialogueJournal.next_segment(narrative,library,"chat",{}).is_empty(),"first three chats finish same day; return cannot farm pool")
	var story_visit := narrative.duplicate(true)
	story_visit.story_revision += 1
	DialogueJournal.visit(story_visit,library,0)
	check(DialogueJournal.next_segment(story_visit,library,"chat",{}).is_empty(),"story change does not refresh ordinary batch")
	DialogueJournal.visit(narrative,library,90)
	check(DialogueJournal.next_segment(narrative,library,"chat",{})==PREFIX+"visit.01","three months unlocks first batch")
	DialogueJournal.visit(narrative,library,900)
	check(int(narrative.npcs[NPC].visits.chat.unlocked)==2,"unread retained across days without accumulating unlocks")
	DialogueJournal.select(narrative,library,"chat",900,{})
	finish(narrative,library,900)
	DialogueJournal.visit(narrative,library,900)
	check(DialogueJournal.next_segment(narrative,library,"chat",{})==PREFIX+"visit.02","same batch second chat remains available")
	DialogueJournal.select(narrative,library,"chat",900,{})
	narrative.flags["base.story.qinglan.departure_ready"] = true
	narrative.story_revision += 1
	check(DialogueJournal.next_segment(narrative,library,"chat",{})==PREFIX+"story.depart","story has priority over pending ordinary dialogue")
	DialogueJournal.select(narrative,library,"chat",900,{})
	finish(narrative,library,900)
	DialogueJournal.select(narrative,library,"chat",900,{})
	check(narrative.npcs[NPC].cursor.chat==PREFIX+"visit.02" and int(narrative.npcs[NPC].seen[PREFIX+"visit.02"])==1,"interrupted ordinary chat resumes after story")
	finish(narrative,library,900)
	for day in [990,1080,1170,1260]:
		DialogueJournal.visit(narrative,library,day)
		for i in 2:
			DialogueJournal.select(narrative,library,"chat",day,{})
			finish(narrative,library,day)
	DialogueJournal.visit(narrative,library,1350)
	check(int(narrative.npcs[NPC].visits.chat.unlocked)==10 and DialogueJournal.next_segment(narrative,library,"chat",{}).is_empty(),"all ten exhausted then archive only")
	narrative.flags["base.story.qinglan.joined"] = true
	check(DialogueJournal.next_segment(narrative,library,"chat",{}).is_empty(),"joining alone does not pretend first return occurred")
	narrative.flags["base.story.qinglan.first_town_return"] = true
	check(DialogueJournal.next_segment(narrative,library,"chat",{})==PREFIX+"story.return","joint story conditions unlock first return")
	check(DialogueJournal.valid_record(narrative) and library.journal_error(narrative.npcs[NPC]).is_empty(),"played journal remains valid")
	var previous: Dictionary = map.loadout.snapshot()
	var fixture: Dictionary = previous.duplicate(true)
	fixture.narrative = narrative
	check(map.loadout.restore(fixture).is_empty(),"journal enters shared state")
	check(MapLoadoutStore.save(map.loadout,"res://artifacts/dialogue-test.json").is_empty(),"isolated journal save")
	var restored: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(restored,"res://artifacts/dialogue-test.json").is_empty() and restored.narrative==narrative,"reload preserves archive partial lines and clue")
	var before: Dictionary = map.loadout.snapshot()
	check(not NpcDialogueActions.command(map.loadout,library,"select","res://artifacts/no-dialogue-directory/save.json","family").is_empty(),"save failure reported")
	check(map.loadout.snapshot()==before,"save failure leaves all progress untouched")
	var corrupt := before.duplicate(true)
	corrupt.narrative.npcs[NPC].seen[PREFIX+"family.01"] = -1
	check(not map.loadout.restore(corrupt).is_empty() and map.loadout.snapshot()==before,"invalid dialogue save rejected atomically")
	check(NpcDialogueActions.set_player_name(map.loadout,"杨","笑一","").is_empty(),"split-name interface")
	check(DialogueJournal.render_text("张辰宇，辰宇？",map.loadout.narrative)=="杨笑一，笑一？","full and affectionate two-character names normalized")
	NpcDialogueActions.set_player_name(map.loadout,"杨","辰","")
	check(DialogueJournal.render_text("辰宇？",map.loadout.narrative)=="阿辰？","single-character name gets affectionate prefix")
	NpcDialogueActions.set_player_name(map.loadout,"欧阳","若水","")
	check(DialogueJournal.full_name(map.loadout.narrative)=="欧阳若水" and DialogueJournal.render_text("辰宇",map.loadout.narrative)=="若水","compound surname preserved")
	check(map.player_status.display_name=="欧阳若水","map and battle source name synchronized")
	check(DialogueBubble.wrap("一".repeat(100)).size()>3,"long speeches split rather than truncate")
	var revision: int = int(map.loadout.narrative.story_revision)
	NpcDialogueActions.set_story_flag(map.loadout,"base.story.test.important_change","")
	NpcDialogueActions.set_story_flag(map.loadout,"base.story.test.important_change","")
	check(int(map.loadout.narrative.story_revision)==revision+1,"same story fact cannot repeatedly unlock visits")
	fixture.erase("narrative")
	check(map.loadout.restore(fixture).is_empty() and map.loadout.narrative==DialogueJournal.initial(),"legacy save gets default identity and no false dialogue progress")
	map.loadout.restore(previous)
	for segment: Dictionary in library.segments.values():
		for line: Dictionary in segment.lines:
			var rendered := DialogueJournal.render_text(line.text,map.loadout.narrative)
			var wrapped := DialogueBubble.wrap(rendered)
			check(not wrapped.is_empty() and "".join(wrapped)==rendered,"wrap preserves full speech including emoji")
			for row: String in wrapped:
				check(DialogueBubble.font().get_string_size(row,HORIZONTAL_ALIGNMENT_LEFT,-1,DialogueBubble.FONT_SIZE).x<=DialogueBubble.TEXT_WIDTH,"every measured row fits bubble")
	for speaker in ["npc","player"]:
		for count in range(1,4):
			var bubble := DialogueBubble.new()
			var lines: Array[String] = []
			for i in count: lines.append("测试楷体台词🙂")
			bubble.configure(speaker,lines,library,map.player_status,map.player_status.display_name)
			check(is_equal_approx(bubble.arrow_y,bubble.portrait_target_y),"each artwork arrow meets upper third")
			check(bubble.rim.get_index()>bubble.portrait.get_index() and bubble.portrait.material is ShaderMaterial,"portrait masked below frame")
			check(bubble.bubble.texture.atlas.resource_path.ends_with(("you" if speaker=="player" else "zuo")+str(count)+".webp"),"proper one/two/three-line asset")
			bubble.free()

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town with dialogue starts: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	map.travel.current_node_id = CLINIC_POINT
	map.travel.map_position = map.travel.node_positions[CLINIC_POINT]
	map.travel.stop_at_current_node()
	await open_clinic(map)
	var dialog: MapClinicDialog = map.clinic_dialog
	check(dialog.library.segments.size()==22,"all 22 authored segments loaded")
	if DisplayServer.get_name()=="headless":
		model_checks(map,dialog.library)
		await click(dialog.continue_button)
		check(int(map.loadout.narrative.npcs[NPC].seen[PREFIX+"welcome"])==2,"continue button reveals next greeting")
		await click(dialog.continue_button)
		check(not dialog.topic_buttons[0].visible and dialog.continue_button.text=="点击开启话题","final greeting waits before topic reveal")
		await click(dialog.continue_button)
		check(dialog.topic_buttons[0].visible,"extra click opens topics")
		await click(dialog.topic_buttons[0])
		check(map.loadout.narrative.npcs[NPC].selected=="medical","medical native topic click")
		await click(dialog.continue_button)
		await click(dialog.topic_buttons[1])
		await click(dialog.topic_buttons[0])
		check(int(map.loadout.narrative.npcs[NPC].seen[PREFIX+"medical.01"])==2,"native switching keeps partial lines")
		await click(dialog.leave_button)
		await open_clinic(map)
		check(int(map.loadout.narrative.npcs[NPC].seen[PREFIX+"medical.01"])==2,"close and reenter resumes partial topic")
		# Complete and browse a long archived thread using native wheel input.
		for stage in 4:
			map._clinic_dialogue_command("select","medical")
			while dialog._view.can_continue: map._clinic_dialogue_command("advance","")
		await settle()
		var before_history: Dictionary = map.loadout.narrative.duplicate(true)
		await click(dialog.topic_buttons[0])
		var old_scroll := dialog.dialogue_scroll.scroll_vertical
		for step in 4:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			wheel.position = dialog.dialogue_scroll.get_global_rect().get_center()
			root.push_input(wheel,true)
		await settle()
		check(dialog.dialogue_scroll.scroll_vertical<old_scroll,"wheel scrolls archived messages upward")
		check(map.loadout.narrative==before_history and not dialog.continue_button.visible,"archive scrolling never replays lines or changes story")
	else:
		check(dialog.topic_buttons.values().all(func(button): return not button.is_visible_in_tree() and not button.get_node("TopicFrame").is_visible_in_tree()),"welcome initially hides all topic frames and labels")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/dialogue-welcome-pending.png")
		map._clinic_dialogue_command("advance","")
		check(dialog.topic_buttons.values().all(func(button): return not button.is_visible_in_tree() and not button.get_node("TopicFrame").is_visible_in_tree()),"unfinished welcome keeps all topic frames hidden")
		map._clinic_dialogue_command("advance","")
		await settle()
		check(dialog.continue_button.text=="点击开启话题" and not dialog.topic_buttons[0].visible,"completed welcome waits for explicit reveal")
		dialog.request_continue()
		await settle()
		check(dialog.topic_buttons.values().all(func(button): return button.is_visible_in_tree() and not button.text.is_empty() and button.get_node("TopicFrame").is_visible_in_tree()),"opening topics reveals all three frames and labels together")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/dialogue-welcome.png")
		map._clinic_dialogue_command("select","medical")
		for step in 2: map._clinic_dialogue_command("advance","")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/dialogue-medical.png")
		check(not dialog.topic_continue_hint.visible,"ongoing speech keeps normal continue hint")
		var before_hint: Dictionary = map.loadout.narrative.duplicate(true)
		while dialog._view.can_continue: map._clinic_dialogue_command("advance","")
		await settle()
		check(dialog.topic_continue_hint.visible and dialog.topic_continue_hint.text=="点击话题继续" and not dialog.continue_button.visible,"segment end points to next topic")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/dialogue-topic-continue.png")
		dialog.set_mode("treatment")
		check(not dialog.topic_continue_hint.visible,"topic hint hidden on treatment page")
		check(dialog.topic_buttons.values().all(func(button): return not button.get_node("TopicFrame").is_visible_in_tree()),"treatment hides independent topic frames")
		dialog.set_mode("conversation")
		check(dialog.topic_continue_hint.visible,"topic hint restored on conversation page")
		check(dialog.topic_buttons.values().all(func(button): return button.get_node("TopicFrame").is_visible_in_tree()),"return to conversation preserves visible completed-greeting topics")
		for stage in range(2,5):
			map._clinic_dialogue_command("select","medical")
			check(not dialog.topic_continue_hint.visible,"next segment restores reading hint")
			while dialog._view.can_continue: map._clinic_dialogue_command("advance","")
		check(not dialog.topic_continue_hint.visible,"completed topic history has no continuation hint")
		map.loadout.narrative = before_hint
		dialog.refresh_dialogue()
		NpcDialogueActions.set_story_flag(map.loadout,"base.story.qinglan.departure_ready","")
		map._clinic_dialogue_command("select","chat")
		for step in 5: map._clinic_dialogue_command("advance","")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/dialogue-story-preview.png")
		for child: Node in dialog.dialogue_rows.get_children(): child.free()
		for speaker in ["npc","player"]:
			var bubble := DialogueBubble.new()
			bubble.configure(speaker,["这是一句用于三行气泡布局检查的台词。","左右气泡分别采用对应的第三张底图。","头像框在上层，箭头对齐头像上三分之一。"],dialog.library,map.player_status,map.player_status.display_name)
			dialog.dialogue_rows.add_child(bubble)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/dialogue-three-lines.png")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("NPC DIALOGUE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
