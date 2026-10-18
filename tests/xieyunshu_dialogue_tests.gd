extends "res://tests/npc_topic_gate_tests.gd"

const XIE := "base.npc.xieyunshu"
const P := "base.dialogue.xieyunshu."
const F := "base.story.xieyunshu."
const JOIN := "base.story.qinglan.joined"
const TASK := "base.story.tianhe.material_inquiry_assigned"
const COMPLETE := "base.story.tianhe.inquiry_completed"
const POINT_XIE := "base.map.qingshizhen.point.n01"
const BAD_PATH := "res://artifacts/no-xie-directory/save.json"

func finish(n: Dictionary, lib: NpcDialogueLibrary, day := 0) -> void:
	var guard := 0
	while DialogueJournal.view(n,lib,{}).can_continue and guard<70:
		DialogueJournal.advance(n,lib,day)
		guard += 1
	check(guard<70,"finite dialogue")

func read(n: Dictionary, lib: NpcDialogueLibrary, topic: String, day := 0) -> void:
	check(DialogueJournal.select(n,lib,topic,day,{}).is_empty(),"select "+topic)
	finish(n,lib,day)

func fresh(lib: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,lib,0).is_empty(),"independent Xie journal")
	finish(n,lib)
	return n

func joined_text(lib: NpcDialogueLibrary, n: Dictionary, key: String) -> String:
	return "\n".join(lib.segment_for(n.npcs[XIE],P+key).lines.map(func(line):return line.text))

func model_checks(map: Node, lib: NpcDialogueLibrary) -> void:
	check(lib.segments.size()==24 and lib.definition.greetings.entries.size()==12,"merged revisions, relationship chat and retrospective branches")
	for topic in ["shop","cultivation","chat"]:
		var independent := fresh(lib)
		read(independent,lib,topic)
		var labels := {"shop":"你怎么辨认货物？","cultivation":"你为何修水？","chat":"说说你的理想"}
		check(lib.segments[DialogueJournal.next_segment(independent,lib,topic,{})].label==labels[topic],"next button "+topic)
		read(independent,lib,topic)
		check(independent.npcs[XIE].done.size()==3 and DialogueJournal.next_segment(independent,lib,topic,{}).is_empty(),"each initial pair independent")
		var before := independent.duplicate(true)
		read(independent,lib,topic)
		check(independent==before,"history click has no new effects")
	var n := fresh(lib)
	for topic in ["shop","cultivation","chat"]:
		read(n,lib,topic)
		read(n,lib,topic)
	n.story_revision += 1
	DialogueJournal.visit(n,lib,89)
	check(n.npcs[XIE].visits.chat.unlocked==0 and n.npcs[XIE].visits.shop.unlocked==0,"89 days and event revision do not refresh ordinary content")
	DialogueJournal.visit(n,lib,90)
	check(n.npcs[XIE].visits.chat.unlocked==2 and n.npcs[XIE].visits.shop.unlocked==1,"90 days opens two chats and homeland market")
	read(n,lib,"shop",90)
	read(n,lib,"chat",90)
	DialogueJournal.visit(n,lib,900)
	check(n.npcs[XIE].visits.chat.unlocked==2,"unread pair does not bank missed batches")
	read(n,lib,"chat",900)
	DialogueJournal.visit(n,lib,989)
	check(n.npcs[XIE].visits.chat.unlocked==2,"next period starts on full pair completion")
	for day in [990,1080]:
		DialogueJournal.visit(n,lib,day)
		read(n,lib,"chat",day)
		read(n,lib,"chat",day)
	DialogueJournal.visit(n,lib,1170)
	read(n,lib,"chat",1170)
	check(n.npcs[XIE].visits.chat.unlocked==8 and DialogueJournal.next_segment(n,lib,"chat",{}).is_empty(),"eighth visit waits for actual same-sect friendship")
	n.flags[JOIN]=true
	read(n,lib,"cultivation",1170)
	check(n.npcs[XIE].cursor.cultivation==P+"cultivation.joined","joining unlocks same-sect chat immediately")
	read(n,lib,"chat",1170)
	check(P+"visit.08" in n.npcs[XIE].done,"same-sect final visit now available")
	check(n.npcs[XIE].done.size()==17 and not n.flags.has(F+"compared_materials"),"time never fabricates investigation or talent")
	var ordinary: Array=[]
	for i in 10:
		DialogueGreetings.arrive(n,lib,{})
		ordinary.append(n.npcs[XIE].greeting.active)
	check(ordinary.slice(0,5)==ordinary.slice(5,10),"five ordinary greetings rotate")
	# Late first meeting and partially read pre-sect welcome are both truthful.
	for interrupted in [false,true]:
		var late := DialogueJournal.initial()
		late.identity={"surname":"欧阳","given_name":"岚"}
		if interrupted: DialogueJournal.visit(late,lib,0)
		late.flags[JOIN]=true
		DialogueJournal.visit(late,lib,0)
		DialogueGreetings.arrive(late,lib,{})
		check(late.npcs[XIE].greeting.active==P+"greeting.intro_joined" and P+"welcome" not in late.npcs[XIE].done,"late intro does not fake original welcome completion")
		finish(late,lib)
		var intro := "\n".join(DialogueJournal.view(late,lib,{}).rows.map(func(row):return row.text))
		check("欧阳岚" in intro and "先前在镇上的药材铺" in intro and "原来是同门" in intro,"same-sect introduction uses real stage and name")
		read(late,lib,"cultivation")
		check("欧阳师弟" in "\n".join(DialogueJournal.view(late,lib,{}).rows.map(func(row):return row.text)),"surname-specific address supports compound surname")
		read(late,lib,"cultivation")
		check("家离青岚宗又不算远" in joined_text(lib,late,"cultivation.01"),"already joined player still gets valid life account")
		check(late.npcs[XIE].seen.get(P+"welcome",0)==(1 if interrupted else 0),"only actually read old welcome remains")
	# Her future realm comes from an explicit story fact, never player's test rank.
	var advanced := fresh(lib)
	DialogueJournal.select(advanced,lib,"cultivation",0,{})
	var seen: int=advanced.npcs[XIE].seen[P+"cultivation.01"]
	advanced.flags[F+"beyond_qi_refining"]=true
	check(not DialogueJournal.view(advanced,lib,{}).can_continue,"obsolete unfinished beginner account stops")
	read(advanced,lib,"cultivation")
	read(advanced,lib,"cultivation")
	check(P+"cultivation.life_review" in advanced.npcs[XIE].done and P+"cultivation.water_review" in advanced.npcs[XIE].done,"needed life and water information survives in current wording")
	check(advanced.npcs[XIE].seen[P+"cultivation.01"]==seen and P+"cultivation.01" not in advanced.npcs[XIE].done and not advanced.npcs[XIE].seen.has(P+"cultivation.02"),"retired unread content never enters history")
	advanced.flags[JOIN]=true
	read(advanced,lib,"cultivation")
	check(DialogueJournal.next_segment(advanced,lib,"cultivation",{}).is_empty(),"joining does not automatically invent a new practice problem")
	advanced.flags[F+"practice_story_ready"]=true
	read(advanced,lib,"cultivation")
	check(P+"cultivation.practice" in advanced.npcs[XIE].done,"explicit later story opens practice")
	# Text-only evidence can create a checklist, never microscopic discoveries.
	var words := fresh(lib)
	words.flags[TASK]=true
	DialogueGreetings.arrive(words,lib,{})
	check("daily" in words.npcs[XIE].greeting.active,"assignment does not inform Xie")
	read(words,lib,"shop")
	check(words.flags.get(F+"knows_inquiry",false) and not words.flags.has(F+"compared_materials") and words.story_revision==0,"disclosure only records knowledge")
	DialogueGreetings.arrive(words,lib,{})
	check(words.npcs[XIE].greeting.active==P+"greeting.inquiry","known but unseen-material welcome")
	words.flags[F+"one_sample_available"]=true
	words.flags[F+"observable_comparison_ready"]=true
	check(DialogueJournal.next_segment(words,lib,"shop",{})==P+"shop.01","single unpaired sample cannot produce a comparison")
	words.flags[F+"difference_verified"]=true
	words.flags[F+"result_disclosed"]=true
	check(DialogueJournal.next_segment(words,lib,"shop",{})==P+"shop.01","result flags cannot fabricate previous help")
	for reference in [false,true]:
		var evidence := fresh(lib)
		evidence.flags[TASK]=true
		read(evidence,lib,"shop")
		evidence.flags[F+("sample_and_reference_available" if reference else "two_samples_available")]=true
		check(DialogueJournal.next_segment(evidence,lib,"shop",{})==P+"shop.01","materials alone do not invent a visible difference")
		evidence.flags[F+"observable_comparison_ready"]=true
		DialogueJournal.select(evidence,lib,"shop",0,{})
		var opening: String=DialogueJournal.view(evidence,lib,{}).rows[-1].text
		check(("对照图样" in opening)==reference,"opening matches actual evidence")
		evidence.flags[F+"two_samples_available"]=true
		finish(evidence,lib)
		check(("对照图样" in joined_text(lib,evidence,"shop.compare"))==reference,"begun branch never changes with later evidence")
		DialogueGreetings.arrive(evidence,lib,{})
		check(evidence.npcs[XIE].greeting.active==P+"greeting.inquiry_followup","only actual participation permits followup")
		evidence.flags[F+"difference_verified"]=true
		check(DialogueJournal.next_segment(evidence,lib,"shop",{})==P+"shop.01","verified but undisclosed result is not NPC knowledge")
		evidence.flags[F+"result_disclosed"]=true
		read(evidence,lib,"shop")
		check(evidence.npcs[XIE].cursor.shop==P+"shop.result" and evidence.story_revision==0,"disclosed verified outcome enables restrained recap")
	var obsolete := fresh(lib)
	obsolete.flags[TASK]=true
	DialogueJournal.select(obsolete,lib,"shop",0,{})
	obsolete.flags[COMPLETE]=true
	check(not DialogueJournal.view(obsolete,lib,{}).can_continue and DialogueJournal.next_segment(obsolete,lib,"shop",{})==P+"shop.01","completed task retires pending request without blocking life content")
	var unaware := fresh(lib)
	unaware.flags["base.story.cultivation.started"]=true
	DialogueGreetings.arrive(unaware,lib,{})
	check("daily" in unaware.npcs[XIE].greeting.active,"cultivation event alone does not inform NPC")
	unaware.flags[F+"knows_cultivation"]=true
	DialogueGreetings.arrive(unaware,lib,{})
	check(unaware.npcs[XIE].greeting.active==P+"greeting.cultivation","known cultivation stage welcome")
	unaware.flags[JOIN]=true
	unaware.flags["base.story.qinglan.first_town_return"]=true
	DialogueGreetings.arrive(unaware,lib,{"resources":{"hp":1},"maxima":{"hp":55}})
	check(unaware.npcs[XIE].greeting.active==P+"greeting.return","return does not assume shopping purpose or healthy body")
	finish(unaware,lib)
	DialogueGreetings.arrive(unaware,lib,{})
	check("daily" in unaware.npcs[XIE].greeting.active,"return disclosure prevents duplicate join introduction")
	# Failed final comparison must not publish knowledge or alter other NPCs.
	var state: MapLoadoutState=MapLoadoutStore.candidate(map.loadout).state
	state.narrative=fresh(lib)
	state.narrative.flags[TASK]=true
	read(state.narrative,lib,"shop")
	for flag in ["observable_comparison_ready","sample_and_reference_available"]:state.narrative.flags[F+flag]=true
	DialogueJournal.select(state.narrative,lib,"shop",0,{})
	for i in lib.segments[P+"shop.compare"].lines.size()-2:DialogueJournal.advance(state.narrative,lib,0)
	var before:=state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"advance",BAD_PATH).is_empty() and state.snapshot()==before,"failed save cannot publish a material discovery")
	var path:="res://artifacts/xie-dialogue-%d.json" % Time.get_ticks_usec()
	check(MapLoadoutStore.save(state,path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.snapshot()==before,"partial reference branch survives reload")
	check(NpcDialogueActions.command(state,lib,"advance",path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.narrative.flags.get(F+"compared_materials",false),"retry persists final line and participation together")
	for other in ["yesongnian","suqinghe","qianwanshun","luhuaizhen","hantieshan"]:
		var other_lib:=NpcDialogueLibrary.new()
		check(other_lib.load_file("res://data/dialogues/"+other+".json").is_empty(),"existing library "+other)
		DialogueJournal.visit(state.narrative,other_lib,0)
	var others:Dictionary=state.narrative.npcs.duplicate(true)
	NpcDialogueActions.command(state,lib,"select","","chat")
	for other in ["yesongnian","suqinghe","qianwanshun","luhuaizhen","hantieshan"]:
		check(state.narrative.npcs["base.npc."+other]==others["base.npc."+other],"separate journal "+other)

func run() -> void:
	create_timer(45).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	var map=load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town with Xie starts")
	if not map.startup_error.is_empty():quit(1);return
	var dialog:=await open_person(map,POINT_XIE)
	check(dialog.library!=null and dialog.library.definition.id==XIE,"N01 binds Xie")
	if DisplayServer.get_name()=="headless":model_checks(map,dialog.library)
	await finish_greeting(dialog)
	check_closed(dialog)
	if DisplayServer.get_name()!="headless":await capture_gate("xieyunshu-welcome")
	var before:Dictionary=map.loadout.snapshot()
	if DisplayServer.get_name()=="headless":await click(dialog.continue_button)
	else:dialog.request_continue()
	check_open(dialog,map,before)
	if DisplayServer.get_name()!="headless":await capture_gate("xieyunshu-topics")
	if DisplayServer.get_name()=="headless":await click(dialog.topic_buttons[0])
	else:map._shop_dialogue_command("select","shop")
	for i in 4:dialog.request_continue()
	check(dialog._view.rows[-1].segment_id==P+"shop.01","shop topic opens via card")
	before=map.loadout.snapshot()
	map.shop_dialog.set_selling(false)
	map.shop_dialog.set_selling(true)
	map.shop_dialog.set_conversation()
	check(map.loadout.snapshot()==before and dialog.topic_buttons[0].visible,"three pages preserve reading state")
	map._shop_dialogue_command("select","cultivation")
	await finish_greeting(dialog)
	map._shop_dialogue_command("select","cultivation")
	for i in 9:dialog.request_continue()
	if DisplayServer.get_name()!="headless":await capture_gate("xieyunshu-water")
	map._shop_dialogue_command("select","chat")
	for i in 6:dialog.request_continue()
	if DisplayServer.get_name()!="headless":await capture_gate("xieyunshu-cat")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("XIE YUNSHU DIALOGUE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
