extends "res://tests/npc_topic_gate_tests.gd"

const QIAN := "base.npc.qianwanshun"
const P := "base.dialogue.qianwanshun."
const RESCUE := "base.story.qingshihewan.rescue_completed"
const NAME := "base.story.qianwanshun.knows_name"
const TASK := "base.story.tianhe.material_inquiry_assigned"
const KNOWN := "base.story.qianwanshun.knows_inquiry"
const REF := "base.story.qianwanshun.referral_ready"
const BAD_PATH := "res://artifacts/no-qian-directory/save.json"
var save_path := "res://artifacts/qian-dialogue-%d.json" % Time.get_ticks_usec()

func finish(n: Dictionary, lib: NpcDialogueLibrary, day := 0) -> void:
	var guard := 0
	while DialogueJournal.view(n,lib,{}).can_continue and guard<80:
		DialogueJournal.advance(n,lib,day)
		guard += 1
	check(guard<80,"finite conversation and chained greeting")

func read(n: Dictionary, lib: NpcDialogueLibrary, topic: String, day := 0) -> void:
	check(DialogueJournal.select(n,lib,topic,day,{}).is_empty(),"select "+topic)
	finish(n,lib,day)

func fresh(lib: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,lib,0).is_empty(),"fresh journal")
	finish(n,lib)
	return n

func model_checks(map: Node, lib: NpcDialogueLibrary) -> void:
	check(lib.segments.size()==19 and lib.definition.greetings.entries.size()==10,"three-part content and eight daily greetings loaded")
	var n := fresh(lib)
	check(DialogueJournal.view(n,lib,{}).topics.map(func(t): return t.label)==["铺中买卖","天河见闻","闲聊"],"three independent initial topics")
	var pre: Array = []
	for index in 6:
		DialogueGreetings.arrive(n,lib,{})
		pre.append(n.npcs[QIAN].greeting.active)
		finish(n,lib)
	check(pre[0]!=pre[1] and pre[0]==pre[2] and pre[1]==pre[3],"exactly two pre-rescue greetings rotate")
	read(n,lib,"shop")
	DialogueJournal.select(n,lib,"shop",0,{})
	DialogueJournal.advance(n,lib,0)
	var old_seen: int = n.npcs[QIAN].seen[P+"shop.02"]
	var old_rows: Array = DialogueJournal.view(n,lib,{}).rows.duplicate(true)
	n.flags[RESCUE] = true
	DialogueGreetings.arrive(n,lib,{})
	check(n.npcs[QIAN].greeting.active==P+"greeting.name","rescue without name runs introduction first")
	DialogueJournal.advance(n,lib,0)
	check(DialogueJournal.view(n,lib,{}).rows[-1].speaker=="player","special welcome supports actual player speech")
	finish(n,lib)
	check(n.flags.get(NAME,false) and n.npcs[QIAN].greeting.once_done.size()==2,"introduction chains into thanks and records name once")
	check(n.story_revision==0,"learning name does not grant other NPCs an ordinary revisit")
	read(n,lib,"shop")
	check(n.npcs[QIAN].cursor.shop==P+"shop.03" and n.npcs[QIAN].variants[P+"shop.03"]=="missed_before_rescue","rescue story adds missing route context")
	check(n.npcs[QIAN].seen[P+"shop.02"]==old_seen and P+"shop.02" not in n.npcs[QIAN].done,"retired partial remains partial, never falsely completed")
	check(DialogueJournal.view(n,lib,{}).rows.slice(0,old_rows.size())==old_rows,"all old spoken lines remain unchanged")
	check(DialogueJournal.next_segment(n,lib,"shop",{}).is_empty(),"obsolete unspoken shop lines never resume")
	DialogueJournal.select(n,lib,"chat",0,{})
	check(DialogueJournal.view(n,lib,{}).rows.filter(func(row): return row.segment_id==P+"greeting.rescued").size()==10,"completed special thanks stored in chat history")
	var post: Array = []
	for index in 12:
		DialogueGreetings.arrive(n,lib,{})
		post.append(n.npcs[QIAN].greeting.active)
		finish(n,lib)
	check(post.slice(0,6)==post.slice(6,12) and post.slice(0,6).all(func(id): return ".after." in id),"six post-rescue daily greetings rotate without repeating thanks")
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.narrative = n.duplicate(true)
	check(MapLoadoutStore.save(state,save_path).is_empty() and MapLoadoutStore.load_into(state,save_path).is_empty() and state.narrative==n,"all new journal fields and partial history reload")
	var before := state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"select",BAD_PATH,"tianhe").is_empty() and state.snapshot()==before,"no publish on failed dialogue save")
	state.narrative = DialogueJournal.initial()
	state.narrative.flags[RESCUE] = true
	NpcDialogueActions.command(state,lib,"visit","")
	NpcDialogueActions.command(state,lib,"advance","")
	before = state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"advance",BAD_PATH).is_empty() and state.snapshot()==before and not state.narrative.flags.has(NAME),"failed final introduction save cannot publish name or consume greeting")
	check(NpcDialogueActions.command(state,lib,"advance",save_path).is_empty() and MapLoadoutStore.load_into(state,save_path).is_empty(),"completed introduction with queued thanks survives reload")
	check(DialogueGreetings.followup(state.narrative,lib)==P+"greeting.rescued","reloaded name completion still offers thanks instead of revealing topics early")
	# Rescue before first-ever shop visit: never fabricate the old welcome.
	var late := DialogueJournal.initial()
	late.flags[RESCUE] = true
	late.flags[NAME] = true
	DialogueJournal.visit(late,lib,0)
	DialogueGreetings.arrive(late,lib,{})
	check(not late.npcs[QIAN].seen.has(P+"welcome") and late.npcs[QIAN].greeting.active==P+"greeting.rescued","late first visit skips obsolete welcome and known name")
	finish(late,lib)
	read(late,lib,"shop")
	read(late,lib,"shop")
	check(not late.npcs[QIAN].seen.has(P+"shop.02"),"entire missed pre-rescue segment is not false history")
	# Per-line address freezes history but newly revealed lines use current relation.
	var addresses := fresh(lib)
	DialogueJournal.select(addresses,lib,"chat",0,{})
	var first_text: String = DialogueJournal.view(addresses,lib,{}).rows[0].text
	addresses.flags[RESCUE] = true
	addresses.flags[NAME] = true
	finish(addresses,lib)
	read(addresses,lib,"chat")
	var rows: Array = DialogueJournal.view(addresses,lib,{}).rows
	check(rows[0].text==first_text and "小兄弟" in rows[0].text and rows.any(func(row): return "辰宇兄弟，东西找不着" in row.text),"past address stays literal, unread suitable content adopts new relationship")
	# 90-day, two-at-a-time ordinary visits, independent of main story revisions.
	var timed := fresh(lib)
	read(timed,lib,"chat")
	read(timed,lib,"chat")
	timed.story_revision += 1
	for day in [0,1,89]:
		DialogueJournal.visit(timed,lib,day)
		check(timed.npcs[QIAN].visits.chat.unlocked==0,"no early refresh on day %d or story change"%day)
	DialogueJournal.visit(timed,lib,90)
	check(timed.npcs[QIAN].visits.chat.unlocked==2,"three months unlock two")
	read(timed,lib,"chat",90)
	read(timed,lib,"chat",90)
	DialogueJournal.visit(timed,lib,179)
	check(timed.npcs[QIAN].visits.chat.unlocked==2,"next group remains gated until next three months")
	DialogueJournal.visit(timed,lib,180)
	check(timed.npcs[QIAN].visits.chat.unlocked==4,"second group has two")
	DialogueJournal.visit(timed,lib,900)
	check(timed.npcs[QIAN].visits.chat.unlocked==4,"unread group does not bank missed periods")
	read(timed,lib,"chat",900)
	read(timed,lib,"chat",900)
	DialogueJournal.visit(timed,lib,900)
	check(timed.npcs[QIAN].visits.chat.unlocked==4,"finishing overdue group cannot refresh again that day")
	DialogueJournal.visit(timed,lib,990)
	check(timed.npcs[QIAN].visits.chat.unlocked==6 and DialogueJournal.next_segment(timed,lib,"chat",{}).is_empty(),"last group still requires rescue")
	timed.flags[RESCUE] = true
	check(DialogueJournal.next_segment(timed,lib,"chat",{})==P+"visit.05","rescue condition takes effect immediately")
	# First chapter goes straight to the player explaining the task.
	for knows in [false,true]:
		var task := fresh(lib)
		if knows:
			task.flags[RESCUE] = true
			task.flags[NAME] = true
			read(task,lib,"tianhe")
		task.flags[TASK] = true
		check(not task.flags.has(KNOWN) and DialogueJournal.next_segment(task,lib,"tianhe",{})==P+"tianhe.04","assignment unlocks inquiry without NPC telepathy or old-topic prerequisite")
		DialogueJournal.select(task,lib,"tianhe",0,{})
		check(DialogueJournal.view(task,lib,{}).rows[-1].speaker=="player","player brings up assignment")
		finish(task,lib)
		read(task,lib,"tianhe")
		check(task.flags.get(REF,false) and task.npcs[QIAN].get("variants",{}).get(P+"tianhe.05","")==("zhou_known" if knows else ""),"referral uses correct known/unknown introduction")
		check(task.story_revision==0,"conversation knowledge does not advance global main-story revision")
		check(DialogueJournal.next_segment(task,lib,"chat",{})==P+"chat.01","no premature successful return")
		task.flags["base.story.tianhe.midway_town_return"] = true
		check(DialogueJournal.next_segment(task,lib,"chat",{})==P+"chat.return_mid","actual mid-task return unlocks brief safe conversation")
		task.flags["base.story.tianhe.inquiry_completed"] = true
		check(DialogueJournal.next_segment(task,lib,"chat",{})==P+"chat.01","completed quest alone cannot claim meeting or help")
		for flag in [RESCUE,"base.story.tianhe.completed_town_return","base.story.tianhe.met_zhou","base.story.tianhe.zhou_helped"]: task.flags[flag] = true
		check(DialogueJournal.next_segment(task,lib,"chat",{})==P+"chat.return_complete","actual encounter and assistance unlock completed return")
	# Bad optional configuration is rejected before play.
	var invalid := lib.definition.duplicate(true)
	invalid.topics[2].revisit_batch_size = 0
	check(not NpcDialogueLibrary.new().configure(invalid).is_empty(),"invalid batch rejected")
	invalid = lib.definition.duplicate(true)
	invalid.portrait_region = [700,900,300,300]
	check(not NpcDialogueLibrary.new().configure(invalid).is_empty(),"out-of-image portrait rejected")

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town starts with merchant content")
	if not map.startup_error.is_empty(): quit(1); return
	var talk := await open_person(map,POINT)
	var lib: NpcDialogueLibrary = talk.library
	check(lib!=null and lib.definition.id==QIAN,"actual N16 opens independent merchant journal")
	if lib==null: quit(1); return
	if DisplayServer.get_name()=="headless": model_checks(map,lib)
	else: await capture_gate("qianwanshun-first-welcome")
	await finish_greeting(talk)
	check_closed(talk)
	if DisplayServer.get_name()=="headless": await click(talk.continue_button)
	else: talk.request_continue()
	check(talk.topic_buttons.values().all(func(button): return button.visible),"exactly three topic frames after explicit click")
	map.inventory_save_path = save_path
	await click(talk.topic_buttons[0])
	var before: Dictionary = map.loadout.narrative.duplicate(true)
	await click(talk.canvas.get_node("ShopBuyTab"))
	await click(map.shop_dialog.conversation_tab)
	check(map.loadout.narrative==before,"trading tabs retain conversation cursor")
	map.inventory_save_path = BAD_PATH
	talk.request_continue()
	check(map.loadout.narrative==before,"actual UI save failure does not advance")
	map.inventory_save_path = save_path
	talk.request_continue()
	check(map.loadout.narrative!=before,"same line can be retried")
	if DisplayServer.get_name()!="headless": await capture_gate("qianwanshun-shop-chat")
	talk.cancelled.emit()
	await settle()
	check(NpcDialogueActions.set_story_flag(map.loadout,RESCUE,save_path).is_empty(),"isolated test rescue flag")
	talk = await open_person(map,POINT)
	check(talk._view.rows[0].segment_id==P+"greeting.name","UI rescue visit starts missing name")
	await finish_greeting(talk)
	check_closed(talk)
	if DisplayServer.get_name()!="headless": await capture_gate("qianwanshun-rescue-thanks")
	talk.request_continue()
	await click(talk.topic_buttons[1])
	for line in 4: talk.request_continue()
	if DisplayServer.get_name()!="headless": await capture_gate("qianwanshun-wanbao")
	var restored: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(restored,save_path).is_empty() and restored.narrative==map.loadout.narrative,"actual three-part interaction survives reload")
	map.queue_free()
	await settle()
	for suffix in ["",".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	root.get_node("UiButtonAudio").player.stop()
	print("QIANWANSHUN DIALOGUE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
