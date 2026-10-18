extends "res://tests/npc_topic_gate_tests.gd"

const HAN := "base.npc.hantieshan"
const P := "base.dialogue.hantieshan."
const F := "base.story.hantieshan."
const H := "base.story.hechuan."
const FORGE := "base.map.qingshizhen.point.n23"
const BAD_PATH := "res://artifacts/no-han-directory/save.json"

func finish(n: Dictionary, lib: NpcDialogueLibrary, day := 0) -> void:
	var guard := 0
	while DialogueJournal.view(n,lib,{}).can_continue and guard<60:
		DialogueJournal.advance(n,lib,day)
		guard += 1
	check(guard<60,"finite dialogue")

func read(n: Dictionary, lib: NpcDialogueLibrary, topic: String, day := 0) -> void:
	check(DialogueJournal.select(n,lib,topic,day,{}).is_empty(),"select "+topic)
	finish(n,lib,day)

func fresh(lib: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,lib,0).is_empty(),"create Han journal")
	finish(n,lib)
	return n

func text_for(lib: NpcDialogueLibrary, n: Dictionary, key: String) -> String:
	return "\n".join(lib.segment_for(n.npcs[HAN],P+key).lines.map(func(line): return line.text))

func model_checks(map: Node, lib: NpcDialogueLibrary) -> void:
	check(lib.segments.size()==18 and lib.definition.greetings.entries.size()==11,"merged eighteen segments and eleven greeting entries")
	check(lib.definition.portrait.ends_with("ui-portrait-hantieshan.webp") and not lib.definition.has("portrait_region"),"dedicated portrait")
	# Any topic can be chosen first; teaching never requires another initial topic.
	for topic in ["shop","equipment","chat"]:
		var independent := fresh(lib)
		read(independent,lib,topic)
		var labels := {"shop":"这块料能不能用？","equipment":"防具怎么配？","chat":"街坊的活儿"}
		check(lib.segments[DialogueJournal.next_segment(independent,lib,topic,{})].label==labels[topic],"next button "+topic)
		read(independent,lib,topic)
		check(DialogueJournal.next_segment(independent,lib,topic,{}).is_empty() and independent.npcs[HAN].done.size()==3,"only selected topic advances")
		check(DialogueJournal.view(independent,lib,{}).topics.filter(func(t):return t.id==topic)[0].label==lib.topics[topic].label,"completed topic restores label")
		var before := independent.duplicate(true)
		read(independent,lib,topic)
		check(independent==before,"history click never replays or grants effects")
	var n := fresh(lib)
	for topic in ["shop","equipment","chat"]:
		read(n,lib,topic)
		read(n,lib,topic)
	check(n.flags.is_empty() and n.clues.is_empty(),"initial talk grants no plot progress")
	n.story_revision += 1
	for day in [1,89]:
		DialogueJournal.visit(n,lib,day)
		check(n.npcs[HAN].visits.chat.unlocked==0 and n.npcs[HAN].visits.shop.unlocked==0,"no early ordinary refresh")
	DialogueJournal.visit(n,lib,90)
	check(n.npcs[HAN].visits.chat.unlocked==2 and n.npcs[HAN].visits.shop.unlocked==1,"three months opens pair plus independent material followup")
	read(n,lib,"shop",90)
	read(n,lib,"chat",90)
	DialogueJournal.visit(n,lib,900)
	check(n.npcs[HAN].visits.chat.unlocked==2,"unread batch never banks extra time")
	read(n,lib,"chat",900)
	DialogueJournal.visit(n,lib,989)
	check(n.npcs[HAN].visits.chat.unlocked==2,"next period starts at full batch completion")
	DialogueJournal.visit(n,lib,990)
	check(n.npcs[HAN].visits.chat.unlocked==4,"second ordinary pair")
	read(n,lib,"chat",990)
	read(n,lib,"chat",990)
	DialogueJournal.visit(n,lib,1080)
	read(n,lib,"chat",1080)
	read(n,lib,"chat",1080)
	check(n.npcs[HAN].done.size()==14 and DialogueJournal.next_segment(n,lib,"chat",{}).is_empty(),"time alone cannot unlock any military or family story")
	# Familiarity predicates apply to state greetings as well as the daily pool.
	var cold := fresh(lib)
	var low := {"resources":{"hp":1},"maxima":{"hp":100}}
	var cold_pool: Array = []
	for i in 6:
		DialogueGreetings.arrive(cold,lib,low)
		cold_pool.append(cold.npcs[HAN].greeting.active)
	check(cold_pool.slice(0,3)==cold_pool.slice(3,6) and cold_pool.all(func(id):return id in lib.definition.greetings.ordinary.slice(0,3)),"unfamiliar low hp keeps ordinary three")
	read(cold,lib,"chat")
	read(cold,lib,"chat")
	DialogueGreetings.arrive(cold,lib,low)
	check(cold.npcs[HAN].greeting.active==P+"greeting.injured","familiar low hp greeting")
	var warm_pool: Array = []
	for i in 10:
		DialogueGreetings.arrive(cold,lib,{"resources":{"hp":50},"maxima":{"hp":100}})
		warm_pool.append(cold.npcs[HAN].greeting.active)
	check(warm_pool.slice(0,5)==warm_pool.slice(5,10) and not P+"greeting.injured" in warm_pool,"exact threshold is healthy; five familiar welcomes rotate")
	# Events require the NPC's source of knowledge; manufactured item is not used item.
	var event := fresh(lib)
	event.flags["base.story.qingshihewan.rescue_completed"] = true
	DialogueGreetings.arrive(event,lib,{})
	check("daily" in event.npcs[HAN].greeting.active,"rescue alone is not NPC knowledge")
	event.flags[F+"knows_river_danger"] = true
	DialogueGreetings.arrive(event,lib,{})
	check(event.npcs[HAN].greeting.active==P+"greeting.river","disclosed actual danger unlocks welcome")
	event.flags[F+"first_craft_received"] = true
	DialogueGreetings.arrive(event,lib,{})
	check(event.npcs[HAN].greeting.active==P+"greeting.craft_received","receipt does not ask usage")
	event.flags[F+"first_craft_used"] = true
	DialogueGreetings.arrive(event,lib,{})
	check(event.npcs[HAN].greeting.active==P+"greeting.craft_used","real use unlocks usage question")
	var used_first := fresh(lib)
	used_first.flags[F+"first_craft_received"] = true
	used_first.flags[F+"first_craft_used"] = true
	for i in 2:
		DialogueGreetings.arrive(used_first,lib,{})
		check(used_first.npcs[HAN].greeting.active!=P+"greeting.craft_received","used equipment never reverts to receipt welcome")
	var departing := fresh(lib)
	departing.flags["base.story.qinglan.departure_ready"] = true
	DialogueGreetings.arrive(departing,lib,{})
	check(departing.npcs[HAN].greeting.active==P+"greeting.departure" and P+"greeting.departure" not in departing.npcs[HAN].greeting.get("once_done",[]),"player tells departure before NPC response")
	finish(departing,lib)
	departing.flags["base.story.qinglan.joined"] = true
	departing.flags["base.story.qinglan.first_town_return"] = true
	DialogueGreetings.arrive(departing,lib,low)
	check(departing.npcs[HAN].greeting.active==P+"greeting.return","first return has no elapsed-time or body assumption")
	finish(departing,lib)
	read(departing,lib,"chat")
	check(DialogueJournal.view(departing,lib,{}).rows.any(func(row): return row.segment_id==P+"greeting.return"),"once-only encounter remains in chat history")
	var low_return := cold.duplicate(true)
	low_return.flags["base.story.qinglan.joined"] = true
	low_return.flags["base.story.qinglan.first_town_return"] = true
	DialogueGreetings.arrive(low_return,lib,low)
	check(low_return.npcs[HAN].greeting.active==P+"greeting.injured" and P+"greeting.return" not in low_return.npcs[HAN].greeting.get("once_done",[]),"low hp welcome does not consume pending reunion")
	DialogueGreetings.arrive(low_return,lib,{})
	check(low_return.npcs[HAN].greeting.active==P+"greeting.return","reunion available after recovery")
	# Secret reveal needs actual source AND separately authored plot readiness.
	for cooperation in [false,true]:
		var soldier := fresh(lib)
		soldier.flags[F+"military_story_ready"] = true
		check(DialogueJournal.next_segment(soldier,lib,"chat",{})==P+"chat.01","readiness alone cannot fabricate military equipment")
		if cooperation:
			soldier.flags["base.story.combat.cooperation_encountered"] = true
			read(soldier,lib,"equipment")
			check(soldier.npcs[HAN].cursor.equipment==P+"equipment.03","real event bypasses initial topic order")
		soldier.flags[H+"military_equipment_known"] = true
		read(soldier,lib,"chat")
		read(soldier,lib,"chat")
		check(soldier.npcs[HAN].cursor.chat==P+"story.military" and ("同行应对危险" in text_for(lib,soldier,"story.military"))==cooperation,"past-conversation reference only after actually read")
		check(soldier.flags.get(F+"military_known",false) and soldier.story_revision==0,"local knowledge does not refresh other NPCs")
	var source_only := fresh(lib)
	source_only.flags[H+"military_equipment_known"] = true
	read(source_only,lib,"chat")
	check(DialogueJournal.next_segment(source_only,lib,"chat",{})==P+"chat.01","equipment source alone reveals birthplace but not military past")
	for visited in [false,true]:
		var wall := fresh(lib)
		wall.flags[F+"seawall_story_ready"] = true
		check(DialogueJournal.next_segment(wall,lib,"chat",{})==P+"chat.01","seawall readiness without source remains locked")
		if visited:
			wall.flags[H+"seawall_visited"] = true
			read(wall,lib,"chat")
			check("我去过的地方" in text_for(lib,wall,"story.region"),"visited origin does not pretend future first journey")
			check(DialogueJournal.next_segment(wall,lib,"chat",{})==P+"chat.01","visit without report readiness does not invent a report")
			wall.flags[H+"seawall_report_ready"] = true
		else:
			wall.flags[H+"seawall_records_read"] = true
			read(wall,lib,"chat")
		DialogueJournal.select(wall,lib,"chat",0,{})
		var opening: String = DialogueJournal.view(wall,lib,{}).rows[-1].text
		check((opening=="你看过哪一段？慢慢说，我听着。") == visited,"report and record use distinct truthful openings")
		wall.flags[H+"seawall_visited"] = true
		wall.flags[H+"seawall_report_ready"] = true
		finish(wall,lib)
		check(("以后若顺路" in text_for(lib,wall,"story.wall"))!=visited,"started variant remains frozen and report avoids future request")
		check(wall.flags.get(F+"seawall_known",false) and not wall.flags.has(H+"seawall_report_completed"),"no quest invented or report auto-completed")
	# Candidate saves preserve partial lines; failure cannot publish facts or history.
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.narrative = fresh(lib)
	state.narrative.flags[H+"military_equipment_known"] = true
	state.narrative.flags[F+"military_story_ready"] = true
	read(state.narrative,lib,"chat")
	DialogueJournal.select(state.narrative,lib,"chat",0,{})
	for i in lib.segments[P+"story.military"].lines.size()-2: DialogueJournal.advance(state.narrative,lib,0)
	var before := state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"advance",BAD_PATH).is_empty() and state.snapshot()==before,"failed final-line save does not disclose military past")
	var path := "res://artifacts/han-dialogue-%d.json" % Time.get_ticks_usec()
	check(MapLoadoutStore.save(state,path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.snapshot()==before,"partial line and branch survive reload")
	check(NpcDialogueActions.command(state,lib,"advance",path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.narrative.flags.get(F+"military_known",false),"retry records final line and knowledge together")
	for other in ["yesongnian","suqinghe","qianwanshun","luhuaizhen"]:
		var other_lib := NpcDialogueLibrary.new()
		check(other_lib.load_file("res://data/dialogues/"+other+".json").is_empty(),"existing NPC "+other)
		DialogueJournal.visit(state.narrative,other_lib,0)
	var others: Dictionary = state.narrative.npcs.duplicate(true)
	NpcDialogueActions.command(state,lib,"select","","equipment")
	for other in ["yesongnian","suqinghe","qianwanshun","luhuaizhen"]:
		check(state.narrative.npcs["base.npc."+other]==others["base.npc."+other],"independent NPC journal "+other)
	var raw := lib.definition.duplicate(true)
	raw.greetings.entries[P+"greeting.injured"].requires_done = ["not.a.dialogue"]
	check(not NpcDialogueLibrary.new().configure(raw).is_empty(),"invalid resource-greeting predicate refused before play")

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
	check(map.startup_error.is_empty(),"town with Han starts")
	if not map.startup_error.is_empty(): quit(1); return
	var dialog := await open_person(map,FORGE)
	check(dialog.library!=null and dialog.library.definition.id==HAN,"N23 binds Han")
	if DisplayServer.get_name()=="headless": model_checks(map,dialog.library)
	await finish_greeting(dialog)
	check_closed(dialog)
	if DisplayServer.get_name()!="headless": await capture_gate("hantieshan-welcome")
	var before: Dictionary = map.loadout.snapshot()
	if DisplayServer.get_name()=="headless": await click(dialog.continue_button)
	else: dialog.request_continue()
	check_open(dialog,map,before)
	if DisplayServer.get_name()!="headless": await capture_gate("hantieshan-topics")
	if DisplayServer.get_name()=="headless": await click(dialog.topic_buttons[0])
	else: map._shop_dialogue_command("select","shop")
	check(dialog._view.rows[-1].segment_id==P+"shop.01","shop topic opens through actual card")
	for i in 5: dialog.request_continue()
	before = map.loadout.snapshot()
	map.shop_dialog.set_selling(false)
	map.shop_dialog.set_selling(true)
	map.shop_dialog.set_crafting()
	check(map.shop_dialog.crafting_panel.get_child_count()==0,"crafting remains reserved")
	map.shop_dialog.set_conversation()
	check(map.loadout.snapshot()==before and dialog.topic_buttons[0].visible,"four-page switches preserve dialogue")
	if DisplayServer.get_name()!="headless": await capture_gate("hantieshan-shop")
	map._shop_dialogue_command("select","equipment")
	for i in 8: dialog.request_continue()
	if DisplayServer.get_name()!="headless": await capture_gate("hantieshan-equipment")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("HAN TIESHAN DIALOGUE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
