extends "res://tests/npc_topic_gate_tests.gd"

const LU := "base.npc.luhuaizhen"
const P := "base.dialogue.luhuaizhen."
const ALCHEMY := "base.map.qingshizhen.point.n12"
const START := "base.story.cultivation.started"
const JOIN := "base.story.qinglan.joined"
const TASK := "base.story.tianhe.material_inquiry_assigned"
const YE := "base.clue.qingshihewan.herb_changes"
const SU := "base.clue.qingshihewan.herb_anomaly"
const WATER := "base.story.qingshihewan.water_observed"
const BAD_PATH := "res://artifacts/no-lu-directory/save.json"

func finish(n: Dictionary, lib: NpcDialogueLibrary, day := 0) -> void:
	var guard := 0
	while DialogueJournal.view(n,lib,{}).can_continue and guard<80:
		DialogueJournal.advance(n,lib,day)
		guard += 1
	check(guard<80,"finite dialogue")

func read(n: Dictionary, lib: NpcDialogueLibrary, topic: String, day := 0) -> void:
	check(DialogueJournal.select(n,lib,topic,day,{}).is_empty(),"select "+topic)
	finish(n,lib,day)

func fresh(lib: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,lib,0).is_empty(),"create independent journal")
	finish(n,lib)
	return n

func model_checks(map: Node, lib: NpcDialogueLibrary) -> void:
	check(lib.segments.size()==21 and lib.definition.greetings.entries.size()==10,"merged content including retrospective and five special greetings")
	var n := fresh(lib)
	for topic in ["alchemy","cultivation","chat"]:
		read(n,lib,topic)
		read(n,lib,topic)
		check(DialogueJournal.next_segment(n,lib,topic,{}).is_empty(),"initial two segments only: "+topic)
	check(n.npcs.size()==1 and n.flags.is_empty() and n.clues.is_empty(),"ordinary conversation does not grant events or inventory")
	n.story_revision += 1
	for day in [1,89]:
		DialogueJournal.visit(n,lib,day)
		check(n.npcs[LU].visits.chat.unlocked==0 and n.npcs[LU].visits.alchemy.unlocked==0,"calendar only, before three months")
	DialogueJournal.visit(n,lib,90)
	check(n.npcs[LU].visits.chat.unlocked==2 and n.npcs[LU].visits.alchemy.unlocked==1,"first three-month batch and rare-material story")
	read(n,lib,"alchemy",90)
	read(n,lib,"chat",90)
	DialogueJournal.visit(n,lib,900)
	check(n.npcs[LU].visits.chat.unlocked==2,"unread batch never accumulates")
	read(n,lib,"chat",900)
	DialogueJournal.visit(n,lib,989)
	check(n.npcs[LU].visits.chat.unlocked==2,"full batch completion anchors next period")
	DialogueJournal.visit(n,lib,990)
	check(n.npcs[LU].visits.chat.unlocked==4,"next two ordinary visits")
	read(n,lib,"chat",990)
	read(n,lib,"chat",990)
	DialogueJournal.visit(n,lib,1080)
	read(n,lib,"chat",1080)
	read(n,lib,"chat",1080)
	check(DialogueJournal.view(n,lib,{}).topics[2].label=="闲聊","completed pool returns to history")
	var daily: Array = []
	for index in 10:
		DialogueGreetings.arrive(n,lib,{})
		daily.append(n.npcs[LU].greeting.active)
	check(daily.slice(0,5)==daily.slice(5,10) and daily.slice(0,5).size()==5,"five ordinary welcomes rotate")
	# Each real evidence source independently unlocks a truthful, frozen opening.
	for sources in [[],[YE],[SU],[WATER],[YE,SU]]:
		var clues := fresh(lib)
		for source: String in sources:
			if source==WATER: clues.flags[source] = true
			else: clues.clues[source] = "actual discovered clue"
		if sources.is_empty():
			check(DialogueJournal.next_segment(clues,lib,"alchemy",{})==P+"alchemy.01","no anomaly before a real clue")
			continue
		DialogueJournal.select(clues,lib,"alchemy",0,{})
		var opening: String = DialogueJournal.view(clues,lib,{}).rows[0].text
		check(clues.npcs[LU].cursor.alchemy==P+"alchemy.anomaly","event bypasses ordinary time and prerequisites")
		check(("叶伯" in opening)==(YE in sources) and ("清禾姐" in opening)==(SU in sources),"speaker knows only actual evidence")
		if sources==[WATER]:
			DialogueJournal.advance(clues,lib,0)
			check("石头" in DialogueJournal.view(clues,lib,{}).rows[-1].text,"river branch uses actual observed water level")
		clues.clues[YE] = "later clue"
		clues.clues[SU] = "later clue"
		finish(clues,lib)
		check(DialogueJournal.view(clues,lib,{}).rows[0].text==opening,"new evidence never rewrites begun conversation")
		check(clues.flags.get("base.story.luhuaizhen.knows_anomaly",false) and clues.story_revision==0,"local knowledge only after reading")
	# Retire an interrupted beginner speech without pretending it was completed.
	var late := fresh(lib)
	DialogueJournal.select(late,lib,"cultivation",0,{})
	var seen: int = late.npcs[LU].seen[P+"cultivation.01"]
	late.flags[JOIN] = true
	check(not DialogueJournal.view(late,lib,{}).can_continue,"obsolete beginner speech stops mid-segment")
	read(late,lib,"cultivation")
	check(late.npcs[LU].cursor.cultivation==P+"cultivation.review" and late.npcs[LU].seen[P+"cultivation.01"]==seen and P+"cultivation.01" not in late.npcs[LU].done,"retrospective replaces unread content, history intact")
	read(late,lib,"cultivation")
	read(late,lib,"cultivation")
	check(P+"cultivation.04" in late.npcs[LU].done and P+"cultivation.02" in late.npcs[LU].done,"sect story and continuing foundation both available")
	var started := fresh(lib)
	started.flags[START] = true
	DialogueGreetings.arrive(started,lib,{})
	check("daily" in started.npcs[LU].greeting.active,"starting alone cannot give NPC knowledge")
	read(started,lib,"cultivation")
	read(started,lib,"cultivation")
	DialogueGreetings.arrive(started,lib,{})
	check(started.npcs[LU].greeting.active==P+"greeting.cultivation","cultivation welcome follows disclosure")
	# Material task works whether or not Qian has been consulted.
	for knows_qian in [false,true]:
		var task := fresh(lib)
		task.flags[TASK] = true
		if knows_qian: task.flags["base.story.qianwanshun.knows_inquiry"] = true
		DialogueGreetings.arrive(task,lib,{})
		check("daily" in task.npcs[LU].greeting.active,"assignment is not telepathic knowledge")
		read(task,lib,"alchemy")
		var last: String = DialogueJournal.view(task,lib,{}).rows[-1].text
		check(("你可以再去问问他" in last)!=knows_qian,"referral depends on actual Qian discussion")
		DialogueGreetings.arrive(task,lib,{})
		check(task.npcs[LU].greeting.active==P+"greeting.inquiry","inquiry welcome requires disclosure")
	var returning := fresh(lib)
	returning.flags["base.story.qinglan.departure_ready"] = true
	read(returning,lib,"chat")
	DialogueGreetings.arrive(returning,lib,{})
	check(returning.npcs[LU].greeting.active==P+"greeting.departure","departure known through player")
	returning.flags[JOIN] = true
	returning.flags["base.story.qinglan.first_town_return"] = true
	DialogueGreetings.arrive(returning,lib,{"resources":{"hp":1},"maxima":{"hp":55}})
	check(returning.npcs[LU].greeting.active==P+"greeting.return" and P+"story.return" not in returning.npcs[LU].done,"low hp return greeting neither assumes health nor consumes return chat")
	read(returning,lib,"chat")
	check(P+"story.return" in returning.npcs[LU].done,"return dialogue still independently read")
	var rescued := fresh(lib)
	rescued.flags["base.story.qingshihewan.rescue_completed"] = true
	DialogueGreetings.arrive(rescued,lib,{})
	check("daily" in rescued.npcs[LU].greeting.active,"merchant rescue is not cultivator rescue")
	rescued.flags["base.story.qingshihewan.cultivator_rescued"] = true
	DialogueGreetings.arrive(rescued,lib,{})
	check("daily" in rescued.npcs[LU].greeting.active,"unknown cultivator rescue does not trigger welcome")
	rescued.flags["base.story.luhuaizhen.knows_cultivator_rescue"] = true
	DialogueGreetings.arrive(rescued,lib,{})
	check(rescued.npcs[LU].greeting.active==P+"greeting.rescue","both rescue and knowledge required")
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.narrative = late.duplicate(true)
	var path := "res://artifacts/lu-dialogue-%d.json" % Time.get_ticks_usec()
	check(MapLoadoutStore.save(state,path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.narrative==late,"partial and retired history survive save/reload")
	var before := state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"select",BAD_PATH,"chat").is_empty() and state.snapshot()==before,"save failure never publishes progress")
	state.narrative = fresh(lib)
	state.narrative.flags[TASK] = true
	DialogueJournal.select(state.narrative,lib,"alchemy",0,{})
	for i in lib.segments[P+"alchemy.inquiry"].lines.size()-2: DialogueJournal.advance(state.narrative,lib,0)
	before = state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"advance",BAD_PATH).is_empty() and state.snapshot()==before and not state.narrative.flags.has("base.story.luhuaizhen.knows_inquiry"),"failed final line does not disclose mission or mark read")
	check(NpcDialogueActions.command(state,lib,"advance",path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.narrative.flags.get("base.story.luhuaizhen.knows_inquiry",false),"successful retry persists knowledge")
	var completed := fresh(lib)
	completed.flags[TASK] = true
	DialogueJournal.select(completed,lib,"alchemy",0,{})
	completed.flags["base.story.tianhe.inquiry_completed"] = true
	check(not DialogueJournal.view(completed,lib,{}).can_continue and DialogueJournal.next_segment(completed,lib,"alchemy",{})==P+"alchemy.01","completed mission retires unfinished inquiry without blocking other content")
	for other in ["yesongnian","suqinghe","qianwanshun"]:
		var other_lib := NpcDialogueLibrary.new()
		check(other_lib.load_file("res://data/dialogues/"+other+".json").is_empty(),"other library "+other)
		DialogueJournal.visit(state.narrative,other_lib,0)
	var others: Dictionary = state.narrative.npcs.duplicate(true)
	NpcDialogueActions.command(state,lib,"select","","chat")
	for other in ["yesongnian","suqinghe","qianwanshun"]:
		check(state.narrative.npcs["base.npc."+other]==others["base.npc."+other],"NPC histories independent: "+other)
	for invalid in [[],"bad",[{}],[{"requires_clues":["bad.id"]}]]:
		var raw := lib.definition.duplicate(true)
		raw.segments[P+"alchemy.anomaly"].any_of = invalid
		check(not NpcDialogueLibrary.new().configure(raw).is_empty(),"invalid alternative condition rejected")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town with Lu starts")
	if not map.startup_error.is_empty(): quit(1); return
	var dialog := await open_person(map,ALCHEMY)
	check(dialog.library!=null and dialog.library.definition.id==LU,"N12 binds Lu")
	if DisplayServer.get_name()=="headless": model_checks(map,dialog.library)
	await finish_greeting(dialog)
	check_closed(dialog)
	if DisplayServer.get_name()!="headless": await capture_gate("luhuaizhen-welcome")
	var before: Dictionary = map.loadout.snapshot()
	if DisplayServer.get_name()=="headless": await click(dialog.continue_button)
	else: dialog.request_continue()
	check_open(dialog,map,before)
	if DisplayServer.get_name()!="headless": await capture_gate("luhuaizhen-topics")
	if DisplayServer.get_name()=="headless": await click(dialog.topic_buttons[0])
	else: map._shop_dialogue_command("select","alchemy")
	check(dialog._view.rows[-1].segment_id==P+"alchemy.01","alchemy topic actually opens")
	for i in 5: dialog.request_continue()
	before = map.loadout.snapshot()
	map.shop_dialog.set_selling(false)
	map.shop_dialog.set_selling(true)
	map.shop_dialog.set_crafting()
	check(map.shop_dialog.crafting_panel.get_child_count()==0,"crafting remains reserved")
	map.shop_dialog.set_conversation()
	check(map.loadout.snapshot()==before and dialog.topic_buttons[0].visible,"four-page switching preserves read state")
	if DisplayServer.get_name()!="headless": await capture_gate("luhuaizhen-alchemy")
	map._shop_dialogue_command("select","cultivation")
	for i in 8: dialog.request_continue()
	if DisplayServer.get_name()!="headless": await capture_gate("luhuaizhen-cultivation")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("LU HUAIZHEN DIALOGUE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
