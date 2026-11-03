extends "res://tests/save_actions_tests.gd"

var map: Control
var state: MapLoadoutState
var save_path := ""

func shot(label: String) -> void:
	if DisplayServer.get_name()!="headless": await capture(label)

func arrive(point_id: String) -> void:
	map.travel.current_node_id = point_id
	map.travel.map_position = map.travel.node_positions[point_id]
	map.travel.stop_at_current_node()
	map.player.position = map.travel.map_position
	map._on_node_arrived(point_id)

func finish_scene(expected: String) -> void:
	check(QuestStory.story(state).active==expected,"active story "+expected)
	var guard := 0
	while QuestStory.story(state).active==expected and not QuestStory.story(state).reward_pending and guard<30:
		map._advance_dialogue()
		guard += 1
	check(guard<30,"story terminates "+expected)

func switch_map(scene: String, point: String) -> void:
	Meta.stop()
	map.deactivate_location()
	map.free()
	map = load(scene).instantiate()
	map.inventory_save_path = save_path
	map.arrival_point_id = point
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	state = map.loadout
	await settle()
	check(map.startup_error.is_empty(),"map starts "+scene+": "+map.startup_error)

func collect(event: Dictionary) -> void:
	check(map.event_state.try_start(event.point_id,event.point_id,true,"click"),"open actual gathering point")
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	check(MapGatheringRewards.prepare(state,event,"base.gathering.deep",save_path,rng).is_empty(),"commit gathering offer")
	map._ensure_event_views()
	map._show_gathering_result()
	check(map.gathering_result.backing.texture.atlas.resource_path.ends_with("UI-jiaohu-size-s.webp"),"gathering reward uses common received-item frame")
	map._accept_gathering()

func run() -> void:
	create_timer(100).timeout.connect(func(): quit(2))
	directory = "res://artifacts/quest-story/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_location_save = true
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	check(map.startup_error.is_empty(),"isolated initial map starts: "+map.startup_error)
	state = map.loadout
	save_path = map.inventory_save_path
	var original := state.snapshot()
	check(QuestStory.prepare_start(state).is_empty(),"opening initializer")
	for key in ["owned_units","placements","growth","learning","spirit_stones"]:
		check(state.snapshot()[key]==original[key],"opening preserves "+key)
	check(state.calendar==WorldCalendar.normalized(original.calendar),"opening preserves date and birthday through normalization")
	check(state.narrative.identity==original.narrative.identity,"opening preserves identity")
	check(MapLoadoutStore.save(state,save_path).is_empty(),"save prepared opening")
	map._restore_saved_location()
	map.activate_location()
	await process_frame
	await process_frame
	check(map.quest_story_controller.waiting_idle and map.event_state.phase=="quest_idle" and not map.dialogue.visible,"opening waits on real idle animation before showing text")
	check(map.travel.current_node_id==QuestStory.data.home.point_id,"opening at home n03")
	map.set_task_open(true)
	check(not map.is_task_open(),"idle opening prevents page shortcuts")
	await create_timer(0.15).timeout
	check(not map.dialogue.visible,"cannot skip idle with early frame")
	await map.player.animation_looped
	await settle()
	check(not map.quest_story_controller.waiting_idle and map.dialogue.visible,"one full idle loop starts dialogue")
	check(map.dialogue.text_label.get_parsed_text()==QuestStory.data.scenes.wake.lines[0],"exact authored parenthetical opening")
	check(map.dialogue.portrait_rim.visible and map.dialogue.speaker_name.text==DialogueJournal.full_name(state.narrative),"player identity and rank frame used")
	await shot("wake-1920x1080")
	map._advance_dialogue()
	check(QuestStory.story(state).line==1 and map.dialogue.text_label.get_parsed_text()=="这会儿，叶伯该开铺了。","wake has exact second line without quotation marks")
	var midline := state.snapshot()
	await switch_map("res://scenes/maps/qingshizhen.tscn",QuestStory.data.home.point_id)
	check(QuestStory.story(state).line==1 and not map.quest_story_controller.waiting_idle,"reload resumes opening line without repeating idle")
	finish_scene("wake")
	check(not map.event_state.is_active() and state.quests[QuestState.ID].counts.talk==0,"opening releases control with first objective active")
	check(map._try_start_event(QuestStory.data.home.point_id,"click",true) and map.event_state.phase=="rest","home rest and warehouse interaction preserved")
	map._close_rest()
	var sign = map.content.get_node("Points/N14")
	check(sign.get_node("QuestSign").visible and not sign.get_node("Sign").visible,"morning shop shows exclamation sign")
	arrive(QuestStory.data.shop.point_id)
	check(QuestStory.story(state).active=="morning" and map.event_state.phase=="dialogue","arrival opens morning without shop-topic UI")
	check(map.dialogue.speaker_name.text=="叶松年" and map.dialogue.portrait_rim.texture.resource_path.ends_with("UI-portrait-putongren.webp"),"elder portrait frame and speaker name match")
	root.size = Vector2i(2560,1440)
	await shot("morning-2560x1440")
	map._advance_dialogue()
	check(map.dialogue.speaker_name.text==DialogueJournal.full_name(state.narrative),"dialogue switches to player")
	var before := state.snapshot()
	check(not QuestStory.command(state,directory+"missing/save.json","advance").is_empty() and state.snapshot()==before,"failed dialogue save leaves cursor and facts unchanged")
	finish_scene("morning")
	check(state.quests[QuestState.ID].counts.talk==1 and sign.get_node("Sign").visible and not sign.get_node("QuestSign").visible,"morning completion restores shop road sign")
	check(map._try_start_event(QuestStory.data.shop.point_id,"click",true) and map.event_state.phase=="shop","ordinary shop remains available")
	var library := NpcDialogueLibrary.new()
	check(library.load_file("res://data/dialogues/yesongnian.json").is_empty(),"NPC library remains valid")
	check(DialogueJournal.retired(state.narrative,library.segments[QuestState.definition.accept_segment]),"old quest topic retired without removing its ID")
	map._close_shop()
	await settle()
	await switch_map("res://scenes/maps/xiyuanyaopo.tscn","base.map.xiyuanyaopo.point.n01")
	check(state.quests[QuestState.ID].counts.visit==1,"slope arrival recorded")
	finish_scene("slope")
	arrive("base.map.xiyuanyaopo.point.n19")
	finish_scene("waterfall")
	arrive("base.map.xiyuanyaopo.point.n19")
	check(not map.event_state.is_active(),"waterfall observation occurs only once and opens no cave")
	arrive("base.map.xiyuanyaopo.point.n13")
	finish_scene("see_xilutai")
	var moss: Dictionary = map.event_registry.events[map.event_registry.by_point[map.travel.current_node_id]]
	collect(moss)
	check(state.quests[QuestState.ID].counts.xilutai==3 and state.quests[QuestState.ID].counts.kuaiye==0,"moss first is independent of other herb")
	check(Files.read(Slots.quick_path()).quests[QuestState.ID].story.active=="xilutai_only","post-gather story cursor survives the latest quick checkpoint")
	finish_scene("xilutai_only")
	arrive("base.map.xiyuanyaopo.point.n07")
	finish_scene("see_kuaiye")
	var herb: Dictionary = map.event_registry.events[map.event_registry.by_point[map.travel.current_node_id]]
	collect(herb)
	finish_scene("both")
	before = state.snapshot()
	check(MapGatheringRewards.claim(state,herb,save_path).is_empty() and state.snapshot()==before,"repeat collection receipt does not queue/pay twice")
	check(QuestState.stage(state.quests)=="returning","both herbs update stage and introduction")
	await switch_map("res://scenes/maps/qingshizhen.tscn","base.map.qingshizhen.point.n11")
	sign = map.content.get_node("Points/N14")
	check(sign.get_node("QuestSign").visible and not sign.get_node("Sign").visible,"ready return restores exclamation sign")
	check(QuestTracking.commit(state,{"ids":[QuestState.ID],"shown":true},save_path).is_empty(),"track active quest")
	arrive(QuestStory.data.shop.point_id)
	var money := state.spirit_stones
	var count: int = state.snapshot().owned_units.size()
	finish_scene("returning")
	check(state.spirit_stones==money and state.snapshot().owned_units.size()==count and state.quests[QuestState.ID].counts.deliver==0,"all return lines finish before reward/consumption")
	check(map.reward_dialog.visible and map.reward_dialog.card.entry.quantity==5,"exact five-stone receipt modal")
	await shot("reward-2560x1440")
	await switch_map("res://scenes/maps/qingshizhen.tscn",QuestStory.data.shop.point_id)
	check(QuestStory.story(state).reward_pending and map.reward_dialog.visible,"reload resumes pending reward without replay or payment")
	var ready := state.snapshot()
	var missing := ready.duplicate(true)
	for entry: Dictionary in state.storage.entries():
		if entry.item_id=="base.material.kuaiye":
			for unit: Dictionary in entry.units: missing.owned_units.erase(unit.id)
	check(state.restore(missing).is_empty(),"missing-herb fixture")
	before = state.snapshot()
	check(not QuestStory.command(state,save_path,"accept").is_empty() and state.snapshot()==before,"receipt rechecks actual inventory atomically")
	check(state.restore(ready).is_empty(),"restore ready receipt")
	before = state.snapshot()
	check(not QuestStory.command(state,directory+"missing/save.json","accept").is_empty() and state.snapshot()==before,"failed receipt save grants/consumes nothing")
	if DisplayServer.get_name()=="headless": await click(map.reward_dialog.accept_button)
	else: map.reward_dialog.accept_button.pressed.emit()
	check(state.spirit_stones==money+5 and state.snapshot().owned_units.size()==count-6 and state.quests[QuestState.ID].counts.deliver==1,"receive exact payment and consume three of each herb")
	check(state.quest_tracking.ids.is_empty() and not map.reward_dialog.visible,"completion removes tracking and closes modal")
	sign = map.content.get_node("Points/N14")
	check(sign.get_node("Sign").visible and not sign.get_node("QuestSign").visible,"completed quest leaves normal shop sign")
	before = state.snapshot()
	check(QuestStory.command(state,save_path,"accept").is_empty() and state.snapshot()==before,"repeated receipt cannot pay twice")
	check(Files.read(Slots.quick_path()).quests[QuestState.ID].counts.deliver==1,"completion quick-save includes reward and quest together")
	# Opposite collection order, legacy save migration and malformed cursor.
	var sample: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(QuestStory.prepare_start(sample).is_empty(),"independent alternate-order fixture")
	sample.quests[QuestState.ID].story.wake_pending = false
	QuestState.record(sample,"talk")
	QuestState.record(sample,"visit")
	QuestState.gathered(sample,{"quest_id":QuestState.ID,"item_id":"base.material.kuaiye","quantity":3})
	check(QuestStory.story(sample).pending==["kuaiye_only"],"bitter herb first chooses correct conditional line")
	var legacy := midline.duplicate(true)
	legacy.quests[QuestState.ID].erase("story")
	check(sample.restore(legacy).is_empty() and not QuestStory.story(sample).wake_pending,"old saves do not unexpectedly replay wake")
	var invalid := ready.duplicate(true)
	invalid.quests[QuestState.ID].story.line = 999
	before = sample.snapshot()
	check(not sample.restore(invalid).is_empty() and sample.snapshot()==before,"invalid persisted dialogue cursor rejected")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("QUEST_STORY: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
