extends "res://tests/npc_topic_gate_tests.gd"

const TONG := "base.npc.tongwantang"
const P := "base.dialogue.tongwantang."
const F := "base.story.tongwantang."
const JOIN := "base.story.qinglan.joined"
const RETURN := "base.story.qinglan.first_town_return"
const RESCUE := "base.story.qingshihewan.rescue_completed"
const XIE_KNOWN := "base.story.xieyunshu.name_known"
const POINT_TONG := "base.map.qingshizhen.point.n13"

func finish(n: Dictionary, lib: NpcDialogueLibrary, day := 0) -> void:
	var guard := 0
	while DialogueJournal.view(n,lib,{}).can_continue and guard<40:
		DialogueJournal.advance(n,lib,day)
		guard += 1
	check(guard<40,"finite dialogue")

func read(n: Dictionary, lib: NpcDialogueLibrary, topic: String, day := 0) -> void:
	check(DialogueJournal.select(n,lib,topic,day,{}).is_empty(),"select "+topic)
	finish(n,lib,day)

func fresh(lib: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,lib,0).is_empty(),"new independent inn journal")
	finish(n,lib)
	return n

func joined_text(lib: NpcDialogueLibrary, n: Dictionary, key: String) -> String:
	return "\n".join(lib.segment_for(n.npcs[TONG],P+key).lines.map(func(line):return line.text))

func model_checks(map: Node, lib: NpcDialogueLibrary) -> void:
	for topic in ["inn","news","chat"]:
		var independent := fresh(lib)
		read(independent,lib,topic)
		var labels := {"inn":"住店有什么讲究？","news":"河湾路上的提醒","chat":"方师傅和阿顺"}
		check(lib.segments[DialogueJournal.next_segment(independent,lib,topic,{})].label==labels[topic],"next button "+topic)
		read(independent,lib,topic)
		check(independent.npcs[TONG].done.size()==3 and DialogueJournal.next_segment(independent,lib,topic,{}).is_empty(),"initial pair independent of other topics")
		var before := independent.duplicate(true)
		read(independent,lib,topic)
		check(independent==before,"history does not replay or publish effects")
	var n := fresh(lib)
	for topic in ["inn","news","chat"]:
		read(n,lib,topic)
		read(n,lib,topic)
	n.story_revision += 1
	DialogueJournal.visit(n,lib,89)
	check(n.npcs[TONG].visits.chat.unlocked==0 and n.npcs[TONG].visits.news.unlocked==0,"89 days or unrelated story change cannot open ordinary batch")
	DialogueJournal.visit(n,lib,90)
	check(n.npcs[TONG].visits.chat.unlocked==2 and n.npcs[TONG].visits.news.unlocked==1,"90 days opens two chats and privacy independently")
	read(n,lib,"news",90)
	read(n,lib,"chat",90)
	DialogueJournal.visit(n,lib,900)
	check(n.npcs[TONG].visits.chat.unlocked==2,"unread batch does not accumulate")
	read(n,lib,"chat",900)
	DialogueJournal.visit(n,lib,989)
	check(n.npcs[TONG].visits.chat.unlocked==2,"next period starts after reading whole pair")
	for day in [990,1080,1170]:
		DialogueJournal.visit(n,lib,day)
		read(n,lib,"chat",day)
		read(n,lib,"chat",day)
	check(P+"visit.08" in n.npcs[TONG].done and DialogueJournal.next_segment(n,lib,"news",{}).is_empty() and DialogueJournal.next_segment(n,lib,"chat",{}).is_empty(),"all eight visits end in history; time creates no story news")
	check("清水洗过青石" in joined_text(lib,n,"visit.08"),"final name has ordinary life origin")
	var ordinary: Array=[]
	for i in 12:
		DialogueGreetings.arrive(n,lib,{})
		ordinary.append(n.npcs[TONG].greeting.active)
	check(ordinary.slice(0,6)==ordinary.slice(6,12),"six ordinary welcomes rotate")
	# Main plot facts and her own knowledge are separate.
	for flag in [RESCUE,F+"qian_told_rescue"]:
		var incomplete := fresh(lib)
		incomplete.flags[flag]=true
		DialogueGreetings.arrive(incomplete,lib,{})
		check("daily" in incomplete.npcs[TONG].greeting.active and DialogueJournal.next_segment(incomplete,lib,"news",{})==P+"news.01","one fact cannot create rescue testimony")
	var rescued := fresh(lib)
	rescued.flags[RESCUE]=true
	rescued.flags[F+"qian_told_rescue"]=true
	DialogueGreetings.arrive(rescued,lib,{})
	check(rescued.npcs[TONG].greeting.active==P+"greeting.qian","known rescue welcome")
	read(rescued,lib,"news")
	check(P+"story.qian" in rescued.npcs[TONG].done and not rescued.npcs[TONG].seen.has(P+"news.01"),"event story need not wait for old news")
	DialogueGreetings.arrive(rescued,lib,{})
	check("daily" in rescued.npcs[TONG].greeting.active,"rescue does not replay thanks")
	rescued.flags[F+"knows_river_danger"]=true
	DialogueGreetings.arrive(rescued,lib,{})
	check(rescued.npcs[TONG].greeting.active==P+"greeting.river","player disclosure permits river response")
	var late := fresh(lib)
	late.flags[F+"road_news_ready"]=true
	read(late,lib,"news")
	check(late.npcs[TONG].cursor.news==P+"story.road","actual travel change opens immediately")
	read(late,lib,"news")
	read(late,lib,"news")
	check("不能算作眼下新来的消息" in joined_text(lib,late,"news.02"),"old boar account is retrospective at later stage")
	DialogueJournal.visit(late,lib,90)
	check(DialogueJournal.next_segment(late,lib,"news",{})==P+"news.privacy","late reading still permits independent privacy followup")
	# Hearing a name is not a prior meeting. Branch freezes when first read.
	for variant in ["base","met_xie","same_sect","same_sect_known","later_cultivation"]:
		var relation := fresh(lib)
		if variant in ["met_xie","same_sect_known"]: relation.flags[XIE_KNOWN]=true
		if variant in ["same_sect","same_sect_known"]: relation.flags[JOIN]=true
		if variant=="later_cultivation": relation.flags["base.story.xieyunshu.beyond_qi_refining"]=true
		read(relation,lib,"news")
		var original := joined_text(lib,relation,"news.01")
		check(("我在宗门铺和她说过话" in original)==(variant in ["met_xie","same_sect_known"]),"prior acquaintance matches "+variant)
		check(("如今同在青岚宗" in original)==(variant in ["same_sect","same_sect_known"]),"same sect matches "+variant)
		check(("刚来当值那阵" in original)==(variant=="later_cultivation"),"realm-dependent wording "+variant)
		check(relation.flags.get(XIE_KNOWN,false)==(variant in ["met_xie","same_sect_known"]),"mention cannot fabricate meeting")
		relation.flags[JOIN]=true
		relation.flags[XIE_KNOWN]=true
		check(joined_text(lib,relation,"news.01")==original,"history branch remains fixed")
	for known in [false,true]:
		var returned := fresh(lib)
		returned.flags[JOIN]=true
		returned.flags[RETURN]=true
		if known: returned.flags[F+"knows_joined"]=true
		DialogueGreetings.arrive(returned,lib,{})
		check(returned.npcs[TONG].greeting.active==P+"greeting.return_"+("known" if known else "unknown"),"return respects actual knowledge")
		if not known: check(not returned.flags.has(F+"knows_joined"),"partial welcome has not completed disclosure")
		finish(returned,lib)
		check(returned.flags.get(F+"knows_joined",false) and returned.flags.get(F+"return_greeted",false) and returned.story_revision==0,"completed return records knowledge without advancing global plot")
		check(DialogueJournal.next_segment(returned,lib,"chat",{})==P+"chat.01","return alone cannot assume a business trip")
		returned.flags[F+"town_business_ready"]=true
		read(returned,lib,"chat")
		check(P+"story.return" in returned.npcs[TONG].done,"actual return business opens story")
		DialogueGreetings.arrive(returned,lib,{})
		check("daily" in returned.npcs[TONG].greeting.active,"alternative return welcome never plays a second time")
	var departing := fresh(lib)
	departing.flags["base.story.qinglan.departure_ready"]=true
	DialogueGreetings.arrive(departing,lib,{})
	check(departing.npcs[TONG].greeting.active==P+"greeting.departure","player announces departure")
	departing.flags[JOIN]=true
	DialogueGreetings.arrive(departing,lib,{})
	check("daily" in departing.npcs[TONG].greeting.active and not departing.flags.has(F+"knows_departure"),"joined state stops obsolete unfinished departure without faking completion")
	# Save failure cannot publish the last line or her knowledge.
	var state: MapLoadoutState=MapLoadoutStore.candidate(map.loadout).state
	state.narrative=fresh(lib)
	state.narrative.flags[JOIN]=true
	state.narrative.flags[RETURN]=true
	DialogueGreetings.arrive(state.narrative,lib,{})
	var before := state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"advance","res://artifacts/no-tong-directory/save.json").is_empty() and state.snapshot()==before,"failed save does not disclose entry or finish welcome")
	var path := "res://artifacts/tong-dialogue-%d.json" % Time.get_ticks_usec()
	check(MapLoadoutStore.save(state,path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.snapshot()==before,"unfinished welcome survives reload")
	check(NpcDialogueActions.command(state,lib,"advance",path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.narrative.flags.get(F+"return_greeted",false),"retry persists knowledge and line together")
	var other_names := ["yesongnian","suqinghe","qianwanshun","luhuaizhen","hantieshan","xieyunshu"]
	for other in other_names:
		var other_lib := NpcDialogueLibrary.new()
		check(other_lib.load_file("res://data/dialogues/"+other+".json").is_empty(),"existing library "+other)
		DialogueJournal.visit(state.narrative,other_lib,0)
	var others: Dictionary=state.narrative.npcs.duplicate(true)
	NpcDialogueActions.command(state,lib,"select","","chat")
	for other in other_names: check(state.narrative.npcs["base.npc."+other]==others["base.npc."+other],"isolated history "+other)

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
	check(map.startup_error.is_empty(),"town starts with inn library")
	if not map.startup_error.is_empty():quit(1);return
	map.travel.current_node_id=POINT_TONG
	map.travel.map_position=map.travel.node_positions[POINT_TONG]
	map.travel.stop_at_current_node()
	map.content.position=map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	var before: Dictionary=MapLoadoutStore.candidate(map.loadout).state.snapshot()
	var resources: Dictionary=map.player_status.resources.duplicate(true)
	map._select_destination(map.map_to_screen(map.travel.map_position))
	await settle()
	var dialog: MapInnDialog=map.inn_dialog
	check(map.event_state.phase=="inn" and dialog.visible and dialog.library!=null and dialog.library.definition.id==TONG,"N13 opens actual inn dialogue")
	if dialog.library==null:quit(1);return
	if DisplayServer.get_name()=="headless":model_checks(map,dialog.library)
	await finish_greeting(dialog)
	check_closed(dialog)
	if DisplayServer.get_name()!="headless":await capture_gate("tongwantang-welcome")
	var after_greeting: Dictionary=map.loadout.snapshot()
	if DisplayServer.get_name()=="headless":await click(dialog.continue_button)
	else:dialog.request_continue()
	check_open(dialog,map,after_greeting)
	if DisplayServer.get_name()!="headless":await capture_gate("tongwantang-topics")
	if DisplayServer.get_name()=="headless":await click(dialog.topic_buttons[0])
	else:map._inn_dialogue_command("select","inn")
	for i in 5:dialog.request_continue()
	check(dialog._view.rows[-1].segment_id==P+"inn.01","topic card opens authored conversation")
	after_greeting=map.loadout.snapshot()
	for page in ["food","lodging","conversation"]:
		if DisplayServer.get_name()=="headless":
			await click(dialog.food_tab if page=="food" else (dialog.lodging_tab if page=="lodging" else dialog.conversation_tab))
		else:dialog.set_mode(page)
	check(map.loadout.snapshot()==after_greeting and dialog.topic_buttons[0].visible,"tabs preserve partial reading and opened cards")
	await finish_greeting(dialog)
	map._inn_dialogue_command("select","inn")
	await finish_greeting(dialog)
	if DisplayServer.get_name()!="headless":await capture_gate("tongwantang-lodging-talk")
	# Render the last normal visit through an isolated, legitimately progressed journal.
	if DisplayServer.get_name()!="headless":
		map.loadout.narrative=fresh(dialog.library)
		read(map.loadout.narrative,dialog.library,"chat")
		read(map.loadout.narrative,dialog.library,"chat")
		for day in [90,180,270,360]:
			DialogueJournal.visit(map.loadout.narrative,dialog.library,day)
			read(map.loadout.narrative,dialog.library,"chat",day)
			read(map.loadout.narrative,dialog.library,"chat",day)
		map._inn_dialogue_command("select","chat")
		await capture_gate("tongwantang-qingshi-name")
	var after: Dictionary=map.loadout.snapshot()
	before.erase("narrative")
	after.erase("narrative")
	check(before==after and map.player_status.resources==resources,"conversation never charges, heals, grants items or advances dates")
	map._close_inn()
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("TONG WANTANG DIALOGUE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
