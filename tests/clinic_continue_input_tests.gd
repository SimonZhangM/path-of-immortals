extends "res://tests/clinic_dialog_tests.gd"

const NPC := "base.npc.suqinghe"
const WELCOME := "base.dialogue.suqinghe.welcome"

func pointer(point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event,true)

func click_at(point: Vector2) -> void:
	pointer(point,true)
	pointer(point,false)
	await settle()

func space(echo := false, physical := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	if not physical: event.keycode = KEY_SPACE
	event.pressed = true
	event.echo = echo
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func reset_greeting(map: Node) -> void:
	map.loadout.narrative = DialogueJournal.initial()
	map.clinic_dialog.set_mode("conversation")
	map._clinic_dialogue_command("visit","")
	await settle()

func seen(map: Node) -> int:
	return int(map.loadout.narrative.npcs[NPC].seen[WELCOME])

func run() -> void:
	# This suite exercises one-click routing; reveal-first behavior is covered
	# separately by settings_gameplay_tests with the normal medium setting.
	root.get_node("GameSettings").apply_values({"dialogue_speed":"instant","dialogue_auto":false,"background_pause":false})
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town starts")
	if not map.startup_error.is_empty(): quit(1); return
	map.travel.current_node_id = CLINIC_POINT
	map.travel.map_position = map.travel.node_positions[CLINIC_POINT]
	map.travel.stop_at_current_node()
	# Match an actual arrival so the exploration layer reveals the clinic.
	map.travel.node_arrived.emit(CLINIC_POINT)
	await open_clinic(map)
	if not map.clinic_dialog.visible: quit(1); return
	var dialog: MapClinicDialog = map.clinic_dialog
	for surface in ["scene","bubble","blank","continue"]:
		await reset_greeting(map)
		var point := dialog.canvas.get_global_transform()*Vector2(700,650)
		if surface=="scene": point = dialog.illustration.get_global_rect().get_center()
		if surface=="bubble": point = dialog.dialogue_rows.get_child(0).bubble.get_global_rect().get_center()
		if surface=="continue": point = dialog.continue_button.get_global_rect().get_center()
		await click_at(point)
		check(seen(map)==2,"one click advances exactly once: "+surface)
	await reset_greeting(map)
	await space()
	check(seen(map)==2,"space advances exactly once")
	await space(true)
	check(seen(map)==2,"held space echo does not advance")
	await space(false,true)
	check(seen(map)==3,"physical space supported")
	check(dialog.continue_button.text=="点击开启话题" and dialog.topic_buttons.values().all(func(button): return not button.visible),"last welcome line waits with all topic cards hidden")
	var welcome_before: Dictionary = map.loadout.narrative.duplicate(true)
	await space(true)
	check(dialog.topic_buttons.values().all(func(button): return not button.visible),"held space cannot open topics after final line")
	await click(dialog.continue_button)
	check(dialog.topic_buttons.values().all(func(button): return button.visible) and map.loadout.narrative==welcome_before,"extra native click reveals three topics without advancing story")
	check(dialog.dialogue_note.text.is_empty(),"remove topic selection hint after greeting")
	check(dialog.continue_button.position.y>dialog.conversation_options.position.y+dialog.conversation_options.size.y,"continue below topic row")
	await click(dialog.topic_buttons[0])
	check(int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.medical.01"])==1,"topic click selects without advancing twice")
	await click(dialog.topic_buttons[1])
	check(int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.family.01"])==1 and int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.medical.01"])==1,"topic switch never advances either topic")
	await click(dialog.topic_buttons[1])
	check(int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.family.01"])==2,"click current topic advances exactly one line")
	await click(dialog.topic_buttons[0])
	check(int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.medical.01"])==1,"switch back resumes without skipping")
	await click(dialog.topic_buttons[0])
	check(int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.medical.01"])==2 and int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.family.01"])==2,"current topic advances independently")
	while dialog._view.can_continue: await click(dialog.topic_buttons[0])
	check(not map.loadout.narrative.npcs[NPC].seen.has("base.dialogue.suqinghe.medical.02"),"last line does not also open next segment")
	await click(dialog.topic_buttons[0])
	check(int(map.loadout.narrative.npcs[NPC].seen["base.dialogue.suqinghe.medical.02"])==1,"updated topic button opens next segment")
	for stage in range(2,5):
		while dialog._view.can_continue: map._clinic_dialogue_command("advance","")
		if stage<4: map._clinic_dialogue_command("select","medical")
	await settle()
	var archived: Dictionary = map.loadout.narrative.duplicate(true)
	await click(dialog.topic_buttons[0])
	check(map.loadout.narrative==archived and not dialog._view.can_continue,"completed topic remains history without replay")
	await reset_greeting(map)
	await click(dialog.treatment_tab)
	await space()
	await click_at(dialog.illustration.get_global_rect().get_center())
	check(dialog.mode=="treatment" and seen(map)==1,"treatment ignores continue gestures")
	await click(dialog.conversation_tab)
	check(seen(map)==1,"conversation tab itself does not advance")
	await click_at(Vector2(10,10))
	check(seen(map)==1,"outside popup does not advance")
	var point := dialog.illustration.get_global_rect().get_center()
	pointer(point,true)
	pointer(point+Vector2(40,0),false)
	await settle()
	check(seen(map)==1,"drag does not become continue")
	pointer(dialog.dialogue_scroll.get_global_rect().get_center(),true,MOUSE_BUTTON_WHEEL_UP)
	pointer(dialog.dialogue_scroll.get_global_rect().get_center(),false,MOUSE_BUTTON_WHEEL_UP)
	await settle()
	check(seen(map)==1,"history wheel does not advance")
	for step in 2: map._clinic_dialogue_command("advance","")
	map._clinic_dialogue_command("select","family")
	while dialog._view.can_continue: map._clinic_dialogue_command("advance","")
	var before: Dictionary = map.loadout.narrative.duplicate(true)
	await click_at(point)
	await space()
	check(map.loadout.narrative==before,"completed segment waits for topic selection")
	await click(dialog.leave_button)
	check(not dialog.visible and not map.event_state.is_active(),"leave retains native behavior")
	check(map.loadout.narrative==before,"leave does not advance dialogue")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("CLINIC CONTINUE INPUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
