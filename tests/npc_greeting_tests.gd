extends "res://tests/npc_dialogue_tests.gd"

const GREETING := PREFIX+"greeting."
const HEALTHY := {"resources":{"hp":100,"stamina":100},"maxima":{"hp":100,"stamina":100}}

func command(map: Node, library: NpcDialogueLibrary, action: String, topic := "", context: Dictionary = HEALTHY, path := "") -> String:
	return NpcDialogueActions.command(map.loadout,library,action,path,topic,context)

func complete(map: Node, library: NpcDialogueLibrary) -> void:
	var guard := 0
	while DialogueJournal.view(map.loadout.narrative,library,{}).can_continue and guard<30:
		check(command(map,library,"advance").is_empty(),"continue saved greeting/topic")
		guard += 1
	check(guard<30,"reading terminates")

func greeting(map: Node) -> Dictionary:
	return map.loadout.narrative.npcs[NPC].greeting

func formal(map: Node) -> Dictionary:
	var result: Dictionary = map.loadout.narrative.npcs[NPC].duplicate(true)
	result.erase("greeting")
	return result

func model_greetings(map: Node, library: NpcDialogueLibrary) -> void:
	map.loadout.narrative = DialogueJournal.initial()
	check(command(map,library,"visit").is_empty(),"first visit accepts legacy missing greeting state")
	check(greeting(map).active.is_empty(),"first authored welcome precedes recurring greetings")
	complete(map,library)
	var baseline := formal(map)
	var expected := ["01","02","03","06","04","05","07","08","09","01","02","10"]
	var last := ""
	for suffix: String in expected:
		check(command(map,library,"visit").is_empty(),"revisit selects greeting")
		var current: String = greeting(map).active
		check(current==GREETING+"daily."+suffix and current!=last,"ordinary and close rotation without adjacent duplicates: "+suffix)
		check(formal(map)==baseline,"greeting cannot consume chat or change history")
		last = current
		complete(map,library)
	check(command(map,library,"select","medical").is_empty(),"topic opens after greeting")
	command(map,library,"advance")
	baseline = formal(map)
	var daily_turn: int = greeting(map).daily_turn
	command(map,library,"visit","",{"resources":{"hp":49,"stamina":1},"maxima":{"hp":100,"stamina":100}})
	check(greeting(map).active==GREETING+"injured" and int(greeting(map).daily_turn)==daily_turn,"low hp overrides low stamina and does not consume daily slot")
	check(not command(map,library,"select","family").is_empty(),"unfinished greeting gates topics")
	check(formal(map)==baseline,"injured greeting preserves interrupted topic")
	complete(map,library)
	command(map,library,"select","medical")
	check(formal(map)==baseline,"reselect resumes exact previous formal cursor")
	command(map,library,"visit","",{"resources":{"hp":50,"stamina":49},"maxima":{"hp":100,"stamina":100}})
	check(greeting(map).active==GREETING+"tired","hp at threshold plus low stamina chooses tired")
	complete(map,library)
	command(map,library,"visit","",{"resources":{"hp":50,"stamina":50},"maxima":{"hp":100,"stamina":100}})
	check("daily." in greeting(map).active,"exactly fifty percent is not low")
	complete(map,library)
	var before: Dictionary = map.loadout.snapshot()
	check(not command(map,library,"visit","",HEALTHY,"res://artifacts/no-greeting-directory/save.json").is_empty(),"failed visit save returns error")
	check(map.loadout.snapshot()==before,"failed selection never consumes rotation or reading")
	command(map,library,"visit","",{"resources":{"hp":10},"maxima":{"hp":100}})
	before = map.loadout.snapshot()
	check(not command(map,library,"advance","",HEALTHY,"res://artifacts/no-greeting-directory/save.json").is_empty(),"failed greeting advancement reported")
	check(map.loadout.snapshot()==before,"failed advancement keeps exact line")
	complete(map,library)
	var path := "res://artifacts/npc-greeting-roundtrip.json"
	check(MapLoadoutStore.save(map.loadout,path).is_empty(),"save to isolated fixture")
	var restored: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(restored,path).is_empty() and restored.narrative==map.loadout.narrative,"greeting counters normalize and survive reload")
	command(map,library,"visit")
	check(NpcDialogueActions.command(restored,library,"visit","","",HEALTHY).is_empty() and restored.narrative==map.loadout.narrative,"next greeting identical after reload")
	complete(map,library)
	map.loadout.narrative.clues["base.clue.qingshihewan.herb_anomaly"] = "青石河湾药材异常"
	command(map,library,"visit")
	check(greeting(map).active==GREETING+"river","real clue unlocks river welcome")
	complete(map,library)
	command(map,library,"visit")
	check("daily." in greeting(map).active,"phase greeting alternates with daily")
	complete(map,library)
	map.loadout.narrative.flags["base.story.qinglan.joined"] = true
	map.loadout.narrative.flags["base.story.qinglan.first_town_return"] = true
	command(map,library,"visit")
	check(greeting(map).active==GREETING+"river","flags alone do not pretend long return dialogue completed")
	complete(map,library)
	command(map,library,"select","chat")
	complete(map,library)
	check(PREFIX+"story.return" in map.loadout.narrative.npcs[NPC].done,"existing story dialogue completes normally")
	command(map,library,"visit")
	check(greeting(map).active==GREETING+"sect","completed return story unlocks higher phase")
	complete(map,library)
	command(map,library,"visit")
	check("daily." in greeting(map).active,"sect phase also alternates")
	complete(map,library)
	NpcDialogueActions.set_player_name(map.loadout,"杨","辰","")
	command(map,library,"visit")
	check(DialogueJournal.view(map.loadout.narrative,library,{}).rows[0].text.begins_with("阿辰"),"new greetings use live affectionate name")
	complete(map,library)
	check(DialogueJournal.valid_record(map.loadout.narrative) and library.journal_error(map.loadout.narrative.npcs[NPC]).is_empty(),"integrated record validates")
	var invalid := library.definition.duplicate(true)
	invalid.greetings.low_ratio = "half"
	check(not NpcDialogueLibrary.new().configure(invalid).is_empty(),"invalid threshold rejected before use")
	invalid = library.definition.duplicate(true)
	invalid.greetings.phases[0].requires_done = [PREFIX+"missing"]
	check(not NpcDialogueLibrary.new().configure(invalid).is_empty(),"unknown phase condition rejected")
	invalid = library.definition.duplicate(true)
	invalid.greetings.entries[GREETING+"daily.01"].lines = []
	check(not NpcDialogueLibrary.new().configure(invalid).is_empty(),"empty greeting rejected")
	before = map.loadout.snapshot()
	var corrupt: Dictionary = before.duplicate(true)
	corrupt.narrative.npcs[NPC].greeting.seen = -1
	check(not map.loadout.restore(corrupt).is_empty() and map.loadout.snapshot()==before,"invalid optional greeting save rejected atomically")
	for entry: Dictionary in library.definition.greetings.entries.values():
		for line: Dictionary in entry.lines:
			for wrapped: String in DialogueBubble.wrap(DialogueJournal.render_text(line.text,map.loadout.narrative)):
				check(DialogueBubble.font().get_string_size(wrapped,HORIZONTAL_ALIGNMENT_LEFT,-1,DialogueBubble.FONT_SIZE).x<=DialogueBubble.TEXT_WIDTH+1,"new greeting fits actual font measure")

func treatment_checks(map: Node, dialog: MapClinicDialog) -> void:
	map.loadout.narrative = DialogueJournal.initial()
	map._clinic_dialogue_command("visit","")
	var library := dialog.library
	complete(map,library)
	dialog.refresh_dialogue()
	await click(dialog.treatment_tab)
	var before: Dictionary = map.loadout.snapshot()
	await click(dialog.conversation_tab)
	check(map.loadout.snapshot()==before,"ordinary native page switch never generates greeting")
	await click(dialog.treatment_tab)
	map.player_status.set_resource("hp",10)
	map.loadout.spirit_stones = 10
	map.inventory_save_path = "res://artifacts/no-greeting-directory/save.json"
	before = map.loadout.snapshot()
	map._confirm_clinic_treatment()
	check(map.loadout.snapshot()==before and map.player_status.resources.hp==10,"failed treatment neither charges heals nor queues greeting")
	map.inventory_save_path = ""
	var formal_before := formal(map)
	map._confirm_clinic_treatment()
	check(map.loadout.spirit_stones==5 and map.player_status.resources.hp==map.player_status.maxima.hp and greeting(map).pending_treatment,"successful payment and pending greeting published together")
	check(formal(map)==formal_before,"treatment does not touch topic progress")
	await click(dialog.conversation_tab)
	check(greeting(map).active==GREETING+"treated" and int(greeting(map).seen)==1 and not greeting(map).pending_treatment,"native return consumes treatment greeting once")
	await click(dialog.continue_button)
	before = map.loadout.snapshot()
	await click(dialog.treatment_tab)
	await click(dialog.conversation_tab)
	check(map.loadout.snapshot()==before,"tabs preserve partial treatment reading without replay")
	await click(dialog.continue_button)
	check(not dialog._view.can_continue and dialog._view.topics.size()==3,"three treatment lines end with original topics")
	before = map.loadout.snapshot()
	await click(dialog.treatment_tab)
	await click(dialog.conversation_tab)
	check(map.loadout.snapshot()==before,"completed treatment welcome does not replay")
	await click(dialog.leave_button)
	await open_clinic(map)
	check(greeting(map).active.begins_with(GREETING+"daily."),"leaving and reentering starts new ordinary greeting")
	# First-time welcome remains ahead of a successful treatment done mid-greeting.
	map.loadout.narrative = DialogueJournal.initial()
	map._clinic_dialogue_command("visit","")
	await click(dialog.treatment_tab)
	map.player_status.set_resource("hp",10)
	map.loadout.spirit_stones = 5
	map._confirm_clinic_treatment()
	await click(dialog.conversation_tab)
	check(greeting(map).active.is_empty() and greeting(map).pending_treatment,"incomplete first welcome defers post-treatment greeting")
	map._clinic_dialogue_command("advance","")
	map._clinic_dialogue_command("advance","")
	check(dialog._view.rows[-1].text.contains("还是来陪我说说话") and dialog._view.can_continue,"first welcome final line remains visible before followup")
	map._clinic_dialogue_command("advance","")
	check(greeting(map).active==GREETING+"treated","next continue starts deferred treatment greeting")
	complete(map,library)

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
	check(map.startup_error.is_empty(),"actual town startup")
	if not map.startup_error.is_empty(): quit(1); return
	map.travel.current_node_id = CLINIC_POINT
	map.travel.map_position = map.travel.node_positions[CLINIC_POINT]
	map.travel.stop_at_current_node()
	await open_clinic(map)
	var dialog: MapClinicDialog = map.clinic_dialog
	check(dialog.library.definition.greetings.entries.size()==16,"all sixteen greetings loaded")
	if DisplayServer.get_name()=="headless":
		model_greetings(map,dialog.library)
		await treatment_checks(map,dialog)
	else:
		complete(map,dialog.library)
		command(map,dialog.library,"visit")
		dialog.refresh_dialogue()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/suqinghe-daily-greeting.png")
		command(map,dialog.library,"visit","",{"resources":{"hp":10},"maxima":{"hp":100}})
		complete(map,dialog.library)
		dialog.refresh_dialogue()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/suqinghe-injured-greeting.png")
		command(map,dialog.library,"select","medical")
		for stage in 4:
			command(map,dialog.library,"select","medical")
			complete(map,dialog.library)
		dialog.refresh_dialogue()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/suqinghe-emoji-dialogue.png")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("NPC GREETINGS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
