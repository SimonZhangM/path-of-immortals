extends "res://tests/suqinghe_revision_tests.gd"

const SU := "base.npc.suqinghe"
const XIE := "base.npc.xieyunshu"
const S := "base.dialogue.suqinghe."
const X := "base.dialogue.xieyunshu."
const JOINED := "base.story.qinglan.joined"
const SAVE_FAIL := "res://artifacts/no-relations-directory/save.json"
var libraries := {}

func load_person(name: String) -> NpcDialogueLibrary:
	var lib := NpcDialogueLibrary.new()
	check(lib.load_file("res://data/dialogues/"+name+".json").is_empty(),"load "+name)
	return lib

func begin(lib: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,lib,0).is_empty(),"begin independent journal")
	finish(n,lib,0)
	return n

func stage(n: Dictionary, lib: NpcDialogueLibrary, topic: String, day := 0) -> void:
	check(DialogueJournal.select(n,lib,topic,day,{}).is_empty(),"select "+topic)
	finish(n,lib,day)

func initials(n: Dictionary, lib: NpcDialogueLibrary, topic: String) -> void:
	for id: String in lib.topics[topic].initial: stage(n,lib,topic)

func text_for(n: Dictionary, lib: NpcDialogueLibrary, sid: String) -> String:
	return "\n".join(lib.segment_for(n.npcs[lib.definition.id],sid).lines.map(func(line):return line.text))

func old_library(lib: NpcDialogueLibrary) -> NpcDialogueLibrary:
	var raw := lib.definition.duplicate(true)
	if raw.id==SU:
		raw.content_revision=2
		for t: Dictionary in raw.topics:
			if t.id=="medical":
				for id: String in t.revisits: raw.segments.erase(id)
				t.revisits=[]
				for key in ["revisit_added_revision","revisit_interval_days","revisit_batch_size"]:t.erase(key)
			if t.id=="chat":
				t.revisits=t.revisits.slice(0,8)
				t.erase("revisit_interval_days")
				t.erase("revisit_batch_size")
		for id in [S+"family.02",S+"visit.07"]:raw.segments[id].erase("variants")
		for id in [S+"visit.09",S+"visit.10"]:raw.segments.erase(id)
	elif raw.id==XIE:
		raw.segments[X+"visit.06"].erase("variants")
		raw.segments.erase(X+"visit.09")
		for t: Dictionary in raw.topics:
			if t.id=="chat":t.revisits=t.revisits.slice(0,8)
	else:
		for t: Dictionary in raw.topics:
			if t.id=="chat":
				t.erase("revisit_interval_days")
				t.erase("revisit_batch_size")
	var result := NpcDialogueLibrary.new()
	check(result.configure(raw).is_empty(),"prior release fixture validates")
	return result

func cadence_checks() -> void:
	for name: String in libraries:
		var lib: NpcDialogueLibrary=libraries[name]
		var id: String=lib.definition.id
		var n := begin(lib)
		initials(n,lib,"chat")
		n.story_revision+=1
		check(DialogueJournal.visit(n,lib,89).is_empty() and n.npcs[id].visits.chat.unlocked==0,name+": no early ordinary update")
		DialogueJournal.visit(n,lib,90)
		check(n.npcs[id].visits.chat.unlocked==2,name+": two at 90 days")
		stage(n,lib,"chat",90)
		DialogueJournal.visit(n,lib,900)
		check(n.npcs[id].visits.chat.unlocked==2,name+": unread second keeps batch")
		stage(n,lib,"chat",900)
		DialogueJournal.visit(n,lib,989)
		check(n.npcs[id].visits.chat.unlocked==2,name+": completion restarts period")
		DialogueJournal.visit(n,lib,990)
		check(n.npcs[id].visits.chat.unlocked==4,name+": next pair available")
		check(lib.journal_error(n.npcs[id]).is_empty() and DialogueJournal.valid_record(n),name+": consistent journal")
	# Legacy odd-sized batches stay open and become pairs only after completion.
	for name in ["suqinghe","yesongnian"]:
		var lib: NpcDialogueLibrary=libraries[name]
		var old := old_library(lib)
		var n := begin(old)
		initials(n,old,"chat")
		DialogueJournal.visit(n,old,1)
		DialogueJournal.select(n,old,"chat",1,{})
		var id: String=lib.definition.id
		var before: Dictionary=n.npcs[id].duplicate(true)
		DialogueJournal.visit(n,lib,700)
		check(n.npcs[id].visits.chat==before.visits.chat and n.npcs[id].seen==before.seen,"old single unlock and partial reading preserved")
		finish(n,lib,700)
		DialogueJournal.visit(n,lib,789)
		check(n.npcs[id].visits.chat.unlocked==1,"old batch not padded or removed")
		DialogueJournal.visit(n,lib,790)
		check(n.npcs[id].visits.chat.unlocked==3,"old odd count continues with next two")

func migration_and_history_checks(map: Node, su: NpcDialogueLibrary) -> void:
	# Also exercise the existing 1 -> 2 mapping followed by the new clock upgrade.
	migration_checks(map,su)
	var old := old_library(su)
	var n := begin(old)
	initials(n,old,"medical")
	stage(n,old,"family")
	DialogueJournal.select(n,old,"family",0,{})
	var original: Dictionary=n.npcs[SU].duplicate(true)
	var words := text_for(n,old,S+"family.02")
	check(DialogueJournal.visit(n,su,500).is_empty(),"v2 to v3 on actual visit")
	check(n.npcs[SU].visits.medical=={"unlocked":0,"last_day":500,"story_revision":0},"new track does not backdate old visits")
	check(n.npcs[SU].seen==original.seen and n.npcs[SU].done==original.done and n.npcs[SU].order==original.order,"new content leaves read state unchanged")
	finish(n,su,500)
	check(text_for(n,su,S+"family.02")==words,"old interrupted family text stays original")
	DialogueJournal.visit(n,su,589)
	check(n.npcs[SU].visits.medical.unlocked==0,"medical new track waits 90 days")
	DialogueJournal.visit(n,su,590)
	stage(n,su,"medical",590)
	check(DialogueJournal.view(n,su,{}).topics[0].label=="炼好之后","medical pair follows with correct button")
	stage(n,su,"medical",590)
	check(DialogueJournal.view(n,su,{}).topics[0].label=="医馆近况","new medical stage returns to history")
	var clean := begin(su)
	initials(clean,su,"family")
	check("外头" in text_for(clean,su,S+"family.02") and "查些什么" not in text_for(clean,su,S+"family.02"),"unread family uses new life account")
	check("外公肯把这些交给你" in text_for(clean,su,S+"family.03"),"previously approved reassurance preserved")
	# Corrupt existing clocks still fail; only the newly declared track is added.
	var broken: Dictionary=n.npcs[SU].duplicate(true)
	broken.visits.erase("medical")
	check(not su.journal_error(broken).is_empty(),"current-version missing clock is not silently repaired")
	var raw := su.definition.duplicate(true)
	raw.topics[0].revisit_added_revision=4
	check(not NpcDialogueLibrary.new().configure(raw).is_empty(),"invalid introduction version rejected")
	# Save failure publishes neither migration nor the first line of new content.
	var state: MapLoadoutState=MapLoadoutStore.candidate(map.loadout).state
	state.narrative=begin(old)
	initials(state.narrative,old,"medical")
	state.calendar.elapsed_days=500
	var before := state.snapshot()
	check(not NpcDialogueActions.command(state,su,"visit",SAVE_FAIL).is_empty() and state.snapshot()==before,"failed save keeps old version and clocks")
	var path := "res://artifacts/npc-relations-save.json"
	check(NpcDialogueActions.command(state,su,"visit",path).is_empty(),"migration saves atomically")
	check(state.narrative.npcs[SU].visits.medical.last_day==WorldCalendar.current_day(state.calendar),"command uses calendar date, not zero")
	before=state.snapshot()
	check(MapLoadoutStore.load_into(state,path).is_empty() and state.snapshot()==before,"migration and history survive reload")
	# Treatment can be the first command touching an old clinic journal too.
	state.narrative=begin(old)
	initials(state.narrative,old,"medical")
	state.spirit_stones=100
	map.player_status.set_resource("hp",1)
	var config: Dictionary=map.event_registry.events[CLINIC_EVENT].treatment
	before=state.snapshot()
	check(not MapClinicTreatment.treat(state,map.player_status,config,SAVE_FAIL,su).error.is_empty() and state.snapshot()==before and map.player_status.resources.hp==1,"failed treatment does not publish new clocks or healing")
	check(MapClinicTreatment.treat(state,map.player_status,config,path,su).error.is_empty() and state.spirit_stones==95,"treatment migration preserves existing five-stone service")
	check(state.narrative.npcs[SU].visits.medical.last_day==WorldCalendar.current_day(state.calendar),"treatment initializes track with game date")

func all_chats(n: Dictionary, lib: NpcDialogueLibrary, count: int) -> void:
	initials(n,lib,"chat")
	if lib.definition.id==XIE:
		n.flags[JOINED]=true
		stage(n,lib,"cultivation")
	var consumed := 0
	var day := 90
	while consumed<count:
		DialogueJournal.visit(n,lib,day)
		for i in mini(2,count-consumed):
			stage(n,lib,"chat",day)
			consumed+=1
		day+=90

func relationship_checks(su: NpcDialogueLibrary, xie: NpcDialogueLibrary) -> void:
	var first_su := begin(su)
	all_chats(first_su,su,10)
	check(not first_su.npcs.has(XIE),"Qinghe relations do not require meeting Xie")
	check("她很喜欢那只小猫？" in text_for(first_su,su,S+"visit.09") and "她讲的大海" in text_for(first_su,su,S+"visit.10"),"unknown cat and water produce questions")
	check("草稿" in text_for(first_su,su,S+"visit.10"),"sea chat describes a draft, not completed route")
	DialogueJournal.visit(first_su,xie,900)
	finish(first_su,xie,900)
	all_chats(first_su,xie,9)
	check("她也跟我提起过" in text_for(first_su,xie,X+"visit.09"),"Qinghe first is acknowledged by Xie branch")
	check(first_su.npcs[XIE].visits.chat.unlocked==9,"last batch exposes remaining one without inventing another")
	var first_xie := begin(xie)
	all_chats(first_xie,xie,9)
	check("她也想去远方看看？" in text_for(first_xie,xie,X+"visit.09"),"Xie first asks instead of assuming Qinghe's plans")
	check("现在只记了几处" in text_for(first_xie,xie,X+"visit.06"),"map planning and shared draft remain compatible")
	DialogueJournal.visit(first_xie,su,900)
	finish(first_xie,su,900)
	all_chats(first_xie,su,10)
	check("她也跟我说过那只灰尾巴" in text_for(first_xie,su,S+"visit.09") and "她也跟我说过，你看了那份草稿" in text_for(first_xie,su,S+"visit.10"),"Xie first is acknowledged by Qinghe branches")
	check("你在宗门里修炼" in text_for(first_xie,su,S+"visit.07"),"late first reading respects joined status")
	check(S+"story.depart" not in first_xie.npcs[SU].done,"joined stage does not manufacture departure history")
	# Branch knowledge freezes when the segment begins, even if another NPC is
	# heard before finishing it; already-read histories are not rewritten.
	var frozen := begin(su)
	all_chats(frozen,su,8)
	DialogueJournal.visit(frozen,su,450)
	DialogueJournal.select(frozen,su,"chat",450,{})
	frozen.npcs[XIE]=first_xie.npcs[XIE].duplicate(true)
	finish(frozen,su,450)
	check("她很喜欢那只小猫？" in text_for(frozen,su,S+"visit.09"),"new knowledge cannot rewrite started unknown branch")
	var old := old_library(xie)
	var past := begin(old)
	all_chats(past,old,6)
	var old_words := text_for(past,old,X+"visit.06")
	DialogueJournal.visit(past,xie,300)
	check(text_for(past,xie,X+"visit.06")==old_words,"old completed map plan retains exact text")
	# New branches wrap in the existing bubble without dropped characters.
	for lib in [su,xie]:
		for seg: Dictionary in lib.segments.values():
			for version: Dictionary in [seg]+seg.get("variants",[]):
				for line: Dictionary in version.lines:
					var rendered := DialogueJournal.render_text(line.text,first_su)
					check("".join(DialogueBubble.wrap(rendered))==rendered,"bubble preserves complete authored speech")

func preview(map: Node, lib: NpcDialogueLibrary, sid: String, image_name: String) -> void:
	var n := begin(lib)
	if lib.definition.id==SU:
		initials(n,lib,"medical")
		all_chats(n,lib,9 if sid==S+"visit.09" else 10)
		DialogueJournal.visit(n,lib,450)
		stage(n,lib,"medical",450)
		stage(n,lib,"medical",450)
	else:all_chats(n,lib,9)
	map.loadout.narrative=n
	var point: String=CLINIC_POINT if lib.definition.id==SU else "base.map.qingshizhen.point.n01"
	map.travel.current_node_id=point
	map.travel.map_position=map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	map.content.position=map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	map._select_destination(map.map_to_screen(map.travel.map_position))
	await settle()
	# Keep the full valid history; the existing view scrolls to its latest line.
	var record: Dictionary=map.loadout.narrative.npcs[lib.definition.id]
	record.selected=lib.segments[sid].topic
	record.cursor[record.selected]=sid
	if record.has("greeting"):
		record.greeting.active=""
		record.greeting.seen=0
	var dialog: MapClinicDialog=map.clinic_dialog if lib.definition.id==SU else map.shop_dialog.conversation_view
	dialog.refresh_dialogue()
	await settle()
	check(not dialog._view.rows.is_empty() and dialog._view.rows[-1].segment_id==sid,"renders new content: "+image_name)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+image_name+".png")
	dialog.leave_button.pressed.emit()
	await settle()

func run() -> void:
	create_timer(55).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	var map=load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town starts")
	if not map.startup_error.is_empty():quit(1);return
	for name in ["yesongnian","suqinghe","qianwanshun","luhuaizhen","hantieshan","xieyunshu"]:libraries[name]=load_person(name)
	var su: NpcDialogueLibrary=libraries.suqinghe
	var xie: NpcDialogueLibrary=libraries.xieyunshu
	if DisplayServer.get_name()=="headless":
		model_checks(map,su)
		cadence_checks()
		migration_and_history_checks(map,su)
		relationship_checks(su,xie)
	else:
		await preview(map,su,S+"medical.lu_followup","npc-relations-medical")
		await preview(map,su,S+"visit.09","npc-relations-cat")
		await preview(map,su,S+"visit.10","npc-relations-sea")
		await preview(map,xie,X+"visit.09","npc-relations-map")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	print("NPC RELATIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
