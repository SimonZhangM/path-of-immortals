extends "res://tests/npc_greeting_tests.gd"

const RETURN := PREFIX+"story.return"
const RETURN_GREETING := GREETING+"return_injured"
const FAILURE_PATH := "res://artifacts/no-suqinghe-revision-directory/save.json"

func legacy_library(library: NpcDialogueLibrary) -> NpcDialogueLibrary:
	var raw := library.definition.duplicate(true)
	# The original revision predates the new medical revisit track and variants.
	for topic: Dictionary in raw.topics:
		if topic.id=="medical":
			for id: String in topic.revisits: raw.segments.erase(id)
			topic.revisits = []
			topic.erase("revisit_added_revision")
	for id in [PREFIX+"family.02",PREFIX+"visit.07"]: raw.segments[id].erase("variants")
	for id: String in raw.legacy_seen_maps:
		raw.segments[id].lines = raw.segments[id].lines.slice(0,raw.legacy_seen_maps[id].size())
		raw.segments[id].erase("variants")
	for id: String in raw.legacy_greeting_seen_maps:
		raw.greetings.entries[id].lines = raw.greetings.entries[id].lines.slice(0,raw.legacy_greeting_seen_maps[id].size())
	for key in ["content_revision","legacy_seen_maps","legacy_greeting_seen_maps"]: raw.erase(key)
	raw.greetings.erase("once")
	raw.greetings.entries.erase(RETURN_GREETING)
	var result := NpcDialogueLibrary.new()
	check(result.configure(raw).is_empty(),"legacy counter fixture accepts original line counts")
	return result

func migration_checks(map: Node, library: NpcDialogueLibrary) -> void:
	var fresh_narrative := DialogueJournal.initial()
	DialogueJournal.visit(fresh_narrative,library,0)
	check(typeof(fresh_narrative.npcs[NPC].content_revision)==TYPE_INT,"JSON content revision enters journal as integer before saving")
	var legacy := legacy_library(library)
	var n := DialogueJournal.initial()
	DialogueJournal.visit(n,legacy,0)
	finish(n,legacy,0)
	for topic: Dictionary in legacy.topics.values():
		for id: String in topic.initial:
			DialogueJournal.select(n,legacy,topic.id,0,{})
			finish(n,legacy,0)
	n.flags["base.story.qinglan.joined"] = true
	n.flags["base.story.qinglan.first_town_return"] = true
	DialogueJournal.select(n,legacy,"chat",0,{})
	finish(n,legacy,0)
	check(legacy.journal_error(n.npcs[NPC]).is_empty(),"old completed journal valid before upgrade")
	var original: Dictionary = n.npcs[NPC].duplicate(true)
	check(library.upgrade_journal(n.npcs[NPC]).is_empty(),"all edited completed stages upgrade")
	var upgraded: Dictionary = n.npcs[NPC]
	check(upgraded.done==original.done and upgraded.order==original.order and upgraded.cursor==original.cursor and upgraded.visits.chat==original.visits.chat,"upgrade preserves completed topics, history order, cursors and existing visit cadence")
	check(upgraded.visits.medical.unlocked==0 and upgraded.visits.medical.last_day==0,"new medical track starts at migration day without unlocked content")
	for id: String in library.definition.legacy_seen_maps:
		check(int(upgraded.seen[id])==library.segments[id].lines.size(),"completed content stays completed: "+id)
	var once := upgraded.duplicate(true)
	check(library.upgrade_journal(upgraded).is_empty() and upgraded==once,"migration is idempotent")
	# Every possible interrupted counter remains unfinished and valid after editing.
	for id: String in library.definition.legacy_seen_maps:
		var mapping: Array = library.definition.legacy_seen_maps[id]
		for count in range(1,mapping.size()):
			var partial := original.duplicate(true)
			partial.seen[id] = count
			partial.done.erase(id)
			check(library.upgrade_journal(partial).is_empty() and id not in partial.done and int(partial.seen[id])==int(mapping[count-1]),"unfinished legacy count migrates without completion")
	for id: String in library.definition.legacy_greeting_seen_maps:
		var record := original.duplicate(true)
		record.greeting = DialogueGreetings.initial()
		record.greeting.active = id
		record.greeting.last = id
		record.greeting.seen = 1
		check(library.upgrade_journal(record).is_empty() and record.greeting.seen==2,"old one-line daily greeting remains finished")
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.narrative = n.duplicate(true)
	state.narrative.npcs[NPC] = original.duplicate(true)
	state.narrative.npcs[NPC].selected = "medical"
	var before := state.snapshot()
	check(not NpcDialogueActions.command(state,library,"select",FAILURE_PATH,"medical").is_empty() and state.snapshot()==before,"failed save cannot publish migration")
	var path := "res://artifacts/suqinghe-revision-migration.json"
	check(NpcDialogueActions.command(state,library,"select",path,"medical").is_empty(),"archive selection upgrades through atomic command")
	var expected := state.snapshot()
	check(MapLoadoutStore.load_into(state,path).is_empty() and state.snapshot()==expected,"revision and history survive reload")
	check(DialogueJournal.view(state.narrative,library,{}).topics[0].label=="医馆近况" and not DialogueJournal.view(state.narrative,library,{}).can_continue,"medical topic ends as archive without investigation nag")
	var invalid := original.duplicate(true)
	invalid.seen[PREFIX+"medical.03"] = 99
	var invalid_before := invalid.duplicate(true)
	check(not library.upgrade_journal(invalid).is_empty() and invalid==invalid_before,"corrupt legacy counter rejected without partial migration")
	var raw := library.definition.duplicate(true)
	raw.legacy_seen_maps[PREFIX+"medical.03"][0] = 6
	check(not NpcDialogueLibrary.new().configure(raw).is_empty(),"mapping cannot mark interrupted first line complete")

func fresh(map: Node, library: NpcDialogueLibrary) -> void:
	map.loadout.narrative = DialogueJournal.initial()
	command(map,library,"visit")
	complete(map,library)

func injured_return_checks(map: Node, library: NpcDialogueLibrary) -> void:
	fresh(map,library)
	var n: Dictionary = map.loadout.narrative
	n.flags["base.story.qinglan.joined"] = true
	n.flags["base.story.qinglan.first_town_return"] = true
	var hp: float = map.player_status.resources.hp
	var wallet: int = map.loadout.spirit_stones
	var topic_before := formal(map)
	command(map,library,"visit","",{"resources":{"hp":50},"maxima":{"hp":100}})
	check(greeting(map).active!=RETURN_GREETING,"exact half health does not trigger reunion injury")
	complete(map,library)
	var before: Dictionary = map.loadout.snapshot()
	check(not command(map,library,"visit","",{"resources":{"hp":49},"maxima":{"hp":100}},FAILURE_PATH).is_empty() and map.loadout.snapshot()==before,"failed arrival does not consume special reunion")
	command(map,library,"visit","",{"resources":{"hp":49,"stamina":1},"maxima":{"hp":100,"stamina":100}})
	check(greeting(map).active==RETURN_GREETING and int(greeting(map).seen)==1,"first injured return overrides generic injury and fatigue")
	check(formal(map)==topic_before and not n.npcs[NPC].seen.has(RETURN),"reunion welcome does not read formal reunion")
	check(map.player_status.resources.hp==hp and map.loadout.spirit_stones==wallet,"greeting never treats or charges")
	before = map.loadout.snapshot()
	check(not command(map,library,"advance","",HEALTHY,FAILURE_PATH).is_empty() and map.loadout.snapshot()==before,"failed special greeting advance preserves unread lines and one-time eligibility")
	command(map,library,"advance")
	var path := "res://artifacts/suqinghe-revision-injured-return.json"
	before = map.loadout.snapshot()
	check(MapLoadoutStore.save(map.loadout,path).is_empty() and MapLoadoutStore.load_into(map.loadout,path).is_empty() and map.loadout.snapshot()==before,"interrupted special greeting survives isolated save and reload")
	command(map,library,"visit","",{"resources":{"hp":20},"maxima":{"hp":100}})
	check(greeting(map).seen==2,"interrupted reunion greeting resumes exact line")
	complete(map,library)
	check(RETURN_GREETING in greeting(map).once_done and not map.loadout.narrative.npcs[NPC].done.has(RETURN),"only special greeting is marked finished")
	command(map,library,"visit","",{"resources":{"hp":20},"maxima":{"hp":100}})
	check(greeting(map).active==GREETING+"injured","later injured visit does not repeat reunion")
	complete(map,library)
	map.player_status.set_resource("hp",10)
	map.loadout.spirit_stones = 5
	var config: Dictionary = map.event_registry.events[CLINIC_EVENT].treatment
	var result := MapClinicTreatment.treat(map.loadout,map.player_status,config,"",library)
	check(result.error.is_empty(),"player can still explicitly choose treatment")
	command(map,library,"after_treatment")
	complete(map,library)
	check(not map.loadout.narrative.npcs[NPC].seen.has(RETURN),"treatment and its greeting leave reunion unread")
	command(map,library,"select","chat")
	var view := DialogueJournal.view(map.loadout.narrative,library,{})
	check(view.rows.size()==1 and view.rows[0].speaker=="player" and "刚回镇上" in view.rows[0].text,"formal reunion follows special welcome without repeating ordinary opening")
	check(map.loadout.narrative.npcs[NPC].variants[RETURN]=="after_injured_greeting","chosen reunion opening remains fixed")
	before = map.loadout.snapshot()
	check(MapLoadoutStore.save(map.loadout,path).is_empty() and MapLoadoutStore.load_into(map.loadout,path).is_empty() and map.loadout.snapshot()==before,"reunion branch and first unread line survive save and reload")
	complete(map,library)
	check(DialogueJournal.view(map.loadout.narrative,library,{}).rows[-1].text.contains("你倒两杯"),"reunion retains her medical life and mutual care")
	command(map,library,"visit")
	check(greeting(map).active==GREETING+"sect","completed reunion still enables ordinary sect visit phase")
	# No requirement to listen to the elder topic before discussing medicine.
	fresh(map,library)
	for i in 3:
		command(map,library,"select","medical")
		complete(map,library)
	check(not map.loadout.narrative.npcs[NPC].seen.has(PREFIX+"family.01"),"medical conversation does not consume family topic")
	var rows: Array = DialogueJournal.view(map.loadout.narrative,library,{}).rows
	check(rows.any(func(row): return "采收、晾晒、存放" in row.text) and not rows.any(func(row): return "叶伯最近也在翻" in row.text),"medical conversation stands on apprentice experience alone")
	check(DialogueJournal.view(map.loadout.narrative,library,{}).topics[0].label=="药材从何处采来？","medical third stage retains next label")
	command(map,library,"select","medical")
	complete(map,library)
	check(DialogueJournal.view(map.loadout.narrative,library,{}).topics[0].label=="医馆近况","final stage returns original topic label")
	# Start ordinary return while injured only after explicitly beginning the story:
	# later arrivals must not insert a new reunion intro over an existing reading.
	fresh(map,library)
	map.loadout.narrative.flags["base.story.qinglan.joined"] = true
	map.loadout.narrative.flags["base.story.qinglan.first_town_return"] = true
	command(map,library,"select","chat")
	check(not map.loadout.narrative.npcs[NPC].get("variants",{}).has(RETURN) and DialogueJournal.view(map.loadout.narrative,library,{}).rows[0].speaker=="npc","healthy reunion retains original ordinary opening")
	command(map,library,"visit","",{"resources":{"hp":10},"maxima":{"hp":100}})
	check(greeting(map).active==GREETING+"injured","already-started reunion keeps its original opening")

func daily_stage_checks(map: Node, library: NpcDialogueLibrary) -> void:
	fresh(map,library)
	var record := greeting(map)
	record.ordinary_index = library.definition.greetings.ordinary.find(GREETING+"daily.05")
	command(map,library,"visit")
	check(greeting(map).active==GREETING+"daily.05","shop helper stage retains fifth greeting")
	complete(map,library)
	map.loadout.narrative.flags["base.story.qinglan.joined"] = true
	var last := ""
	for turn in 24:
		command(map,library,"visit")
		var active: String = greeting(map).active
		check(active!=GREETING+"daily.05" and active!=last,"joined pool skips fifth greeting without adjacent duplication")
		complete(map,library)
		last = active
	var elder := NpcDialogueLibrary.new()
	check(elder.load_file("res://data/dialogues/yesongnian.json").is_empty(),"elder configuration remains compatible")
	var elder_n := DialogueJournal.initial()
	DialogueJournal.visit(elder_n,elder,0)
	finish(elder_n,elder,0)
	DialogueGreetings.arrive(elder_n,elder,HEALTHY)
	check(elder_n.npcs[elder.definition.id].greeting.active=="base.dialogue.yesongnian.greeting.daily.01","elder unweighted daily pool still starts normally")
	check(DialogueJournal.valid_record(elder_n) and elder.journal_error(elder_n.npcs[elder.definition.id]).is_empty(),"elder old revision still validates")

func capture_revision(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+label+".png")

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
	check(map.startup_error.is_empty(),"town startup with revised dialogue")
	if not map.startup_error.is_empty(): quit(1); return
	map.clinic_dialog.present(map.event_registry.events[CLINIC_EVENT],map.loadout,map.player_status)
	var dialog: MapClinicDialog = map.clinic_dialog
	var library := dialog.library
	if DisplayServer.get_name()=="headless":
		model_checks(map,library)
		model_greetings(map,library)
		migration_checks(map,library)
		injured_return_checks(map,library)
		daily_stage_checks(map,library)
	else:
		fresh(map,library)
		dialog.refresh_dialogue()
		await capture_revision("suqinghe-revised-welcome")
		for i in 4:
			command(map,library,"select","medical")
			complete(map,library)
		dialog.refresh_dialogue()
		await capture_revision("suqinghe-revised-trust")
		map.loadout.narrative.flags["base.story.qinglan.joined"] = true
		map.loadout.narrative.flags["base.story.qinglan.first_town_return"] = true
		map.player_status.set_resource("hp",10)
		command(map,library,"visit","",{"resources":map.player_status.resources,"maxima":map.player_status.maxima})
		complete(map,library)
		dialog.refresh_dialogue()
		await capture_revision("suqinghe-revised-injured-return")
		check(dialog._view.rows.size()==3 and not map.loadout.narrative.npcs[NPC].seen.has(RETURN),"rendered injury greeting leaves long reunion untouched")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("SUQINGHE REVISION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
