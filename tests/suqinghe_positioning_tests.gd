extends "res://tests/npc_dialogue_tests.gd"

const DEPART := PREFIX+"story.depart"
const READY := "base.story.qinglan.departure_ready"
const JOINED := "base.story.qinglan.joined"

func begin_departure(library: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,library,0).is_empty(),"create isolated journal")
	finish(n,library,0)
	n.flags[READY] = true
	check(DialogueJournal.select(n,library,"chat",0,{}).is_empty(),"start available departure")
	return n

func compatibility_checks(map: Node, library: NpcDialogueLibrary) -> void:
	var raw := library.definition.duplicate(true)
	raw.segments[DEPART].erase("variants")
	var old := NpcDialogueLibrary.new()
	check(old.configure(raw).is_empty(),"previous departure fixture validates")
	# Every old reading position, including completion, must retain its text and
	# cursor. New content must not retroactively create knowledge in old history.
	for count in range(1,old.segments[DEPART].lines.size()+1):
		var n := begin_departure(old)
		for i in range(1,count): DialogueJournal.advance(n,old,0)
		var before := n.duplicate(true)
		var view := DialogueJournal.view(n,old,{})
		check(DialogueJournal.visit(n,library,0).is_empty() and n==before,"old position unchanged on update")
		check(DialogueJournal.view(n,library,{})==view,"old history text and completion preserved")
		finish(n,library,0)
		check(library.segment_for(n.npcs[NPC],DEPART).lines==old.segments[DEPART].lines,"old continuation never switches branch")
		check(library.journal_error(n.npcs[NPC]).is_empty(),"finished legacy departure remains valid")
	var n := begin_departure(library)
	check(n.npcs[NPC].variants[DEPART]=="medical_path","new reader receives fixed medical path")
	var new_lines: Array = library.segment_for(n.npcs[NPC],DEPART).lines
	for i in 7: DialogueJournal.advance(n,library,0)
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.narrative = n
	var save_path := "res://artifacts/suqinghe-positioning-save.json"
	check(MapLoadoutStore.save(state,save_path).is_empty(),"new branch saves mid-conversation")
	var snapshot := state.snapshot()
	check(MapLoadoutStore.load_into(state,save_path).is_empty() and state.snapshot()==snapshot,"new branch and reading position reload exactly")
	var before := state.snapshot()
	check(not NpcDialogueActions.command(state,library,"advance","res://artifacts/no-positioning-directory/save.json").is_empty() and state.snapshot()==before,"failed save never consumes new dialogue")
	finish(state.narrative,library,0)
	check(library.segment_for(state.narrative.npcs[NPC],DEPART).lines==new_lines,"saved branch stays fixed through completion")
	check(state.narrative.flags=={READY:true},"reading does not enroll Qinghe or grant party abilities")
	for line: Dictionary in new_lines:
		var text := DialogueJournal.render_text(line.text,state.narrative)
		var wrapped := DialogueBubble.wrap(text)
		check("".join(wrapped)==text,"new dialogue wraps without lost characters")
		for row: String in wrapped:
			check(DialogueBubble.font().get_string_size(row,HORIZONTAL_ALIGNMENT_LEFT,-1,DialogueBubble.FONT_SIZE).x<=DialogueBubble.TEXT_WIDTH,"new dialogue fits measured width")
	# An old unstarted journal still selects new text, while missing story facts
	# and late arrival cannot open a farewell merely because time has elapsed.
	var unread := DialogueJournal.initial()
	DialogueJournal.visit(unread,old,0)
	finish(unread,old,0)
	DialogueJournal.visit(unread,library,900)
	check(DialogueJournal.next_segment(unread,library,"chat",{})!=DEPART,"time alone never grants departure")
	unread.flags[READY] = true
	DialogueJournal.select(unread,library,"chat",900,{})
	check(unread.npcs[NPC].variants[DEPART]=="medical_path","old save with unread departure gets new version")
	var retired := unread.duplicate(true)
	retired.flags[JOINED] = true
	var read_count: int = int(retired.npcs[NPC].seen[DEPART])
	DialogueJournal.advance(retired,library,900)
	check(int(retired.npcs[NPC].seen[DEPART])==read_count and DEPART not in retired.npcs[NPC].done,"joining retires unfinished farewell without fabricating completion")
	check(DialogueJournal.next_segment(retired,library,"chat",{})!=DEPART,"no obsolete departure after joining")

func capture_positioning(map: Node, library: NpcDialogueLibrary) -> void:
	map.loadout.narrative = begin_departure(library)
	map.clinic_dialog.present(map.event_registry.events[CLINIC_EVENT],map.loadout,map.player_status)
	for i in 6: DialogueJournal.advance(map.loadout.narrative,library,0)
	map.clinic_dialog.refresh_dialogue()
	await settle()
	check(map.clinic_dialog._view.rows.size()==7,"preview includes initial test and clinic responsibilities")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/suqinghe-positioning-background.png")
	finish(map.loadout.narrative,library,0)
	map.clinic_dialog.refresh_dialogue()
	await settle()
	check(not map.clinic_dialog._view.can_continue,"departure archives after final line")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/suqinghe-positioning-farewell.png")

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
	check(map.startup_error.is_empty(),"town startup with positioning revision")
	if not map.startup_error.is_empty(): quit(1); return
	var library := NpcDialogueLibrary.new()
	check(library.load_file("res://data/dialogues/suqinghe.json").is_empty(),"dialogue data validates")
	if DisplayServer.get_name()=="headless":
		model_checks(map,library)
		compatibility_checks(map,library)
	else:
		await capture_positioning(map,library)
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	print("SUQINGHE POSITIONING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
