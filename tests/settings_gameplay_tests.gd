extends "res://tests/save_actions_tests.gd"
const Settings = preload("res://scripts/settings/game_settings.gd")
const Schedule = preload("res://scripts/entry/save_checkpoint_schedule.gd")
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")
const Playback = preload("res://scripts/dialogue/dialogue_playback.gd")
const CLINIC_EVENT := "base.map_event.qingshizhen.clinic"
const NPC := "base.npc.suqinghe"
const WELCOME := "base.dialogue.suqinghe.welcome"
var settings: Node

func apply(patch: Dictionary) -> void:
	check(settings.apply_values(patch).is_empty(),"settings patch accepted: "+str(patch.keys()))

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	settings = root.get_node("GameSettings")
	apply({"background_pause":false,"background_mute":false,"auto_save":true,"quick_save":true,"auto_save_minutes":10})
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var clock = root.get_node("SavePlaytime")
	clock.set_process(false)
	_test_schedule()
	_test_playback()
	directory = "res://artifacts/settings-gameplay/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var real_paths := [Slots.AUTO_PATH,Slots.quick_path(),Slots.working_path(),Session.INDEX_PATH,"user://manual_save_02.json","user://save_slots.json"]
	var before: Array = []
	for path in real_paths: before.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing")
	var old_auto: String = Slots.auto_path
	var old_index: String = Session.index_path
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"fresh isolated map initializes")
	if not map.startup_error.is_empty(): quit(1); return
	map.inventory_save_path = Slots.working_path()
	check(MapLoadoutStore.save(map.loadout,map.inventory_save_path).is_empty(),"isolated live session created")
	check(Files.write(Slots.auto_path,map.loadout.snapshot())==OK,"isolated auto baseline created")
	Meta.start(map.inventory_save_path)
	_test_snapshots(map,clock)
	Meta.stop()
	map.inventory_save_path = ""
	_test_map_dialogue()
	_test_npc_dialogue(map)
	map.queue_free()
	await settle()
	Checkpoints.pending_quick.clear()
	Slots.auto_path = old_auto
	Session.index_path = old_index
	for index in real_paths.size():
		var after: String = FileAccess.get_sha256(real_paths[index]) if FileAccess.file_exists(real_paths[index]) else "missing"
		check(before[index]==after,"real save unchanged: "+real_paths[index])
	print("SETTINGS GAMEPLAY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_schedule() -> void:
	for minutes in [5,10,15,30]:
		var schedule := Schedule.new()
		schedule.configure_preferences(true,float(minutes)*60.0)
		check(not schedule.advance(float(minutes)*60.0-1.0,false,true),"interval waits until boundary: "+str(minutes))
		check(schedule.advance(1.0,false,true),"configured interval fires: "+str(minutes))
	var schedule := Schedule.new()
	schedule.advance(599,false,false)
	schedule.configure_preferences(true,300.0)
	check(schedule.elapsed==0.0 and not schedule.pending and not schedule.advance(1.0,false,true),"interval change restarts countdown")
	schedule.advance(299,false,false)
	check(schedule.pending,"unsafe phase holds due checkpoint")
	schedule.configure_preferences(false,300.0)
	check(not schedule.pending and schedule.elapsed==0 and not schedule.advance(9999,false,true),"disabled timer discards pending and does not count")
	schedule.configure_preferences(true,300.0)
	check(not schedule.advance(299,false,true),"re-enable starts full interval")
	check(not schedule.advance(100,true,true) and schedule.elapsed==299.0,"pause does not count")
	check(schedule.advance(1,false,true),"enabled interval resumes after pause")

func _test_playback() -> void:
	var first := Label.new()
	var second := Label.new()
	first.text = "一二三四五六七八九十一二三四五"
	second.text = first.text
	var playback := Playback.new()
	playback.begin([first,second],"slow")
	check(not playback.advance(1.0,"slow",true) and first.visible_characters==-1 and second.visible_characters==0,"slow reveals 15 characters across chunks")
	check(playback.finish_reveal() and not playback.is_revealing(),"manual first advance finishes remaining text")
	check(not playback.advance(1.9,"slow",true),"auto waits after manually completed text")
	check(playback.advance(0.11,"slow",true) and not playback.advance(5,"slow",true),"auto emits only once per speech")
	playback.begin([first,second],"medium")
	check(not playback.advance(2.99,"medium",true),"medium reveal plus dwell waits full two seconds")
	check(playback.advance(0.02,"medium",true),"medium auto advances after reveal plus dwell")
	playback.begin([first,second],"fast")
	playback.advance(0.5,"fast",false)
	check(not playback.is_revealing(),"fast reveals 60 characters per second")
	playback.begin([first,second],"instant")
	check(not playback.is_revealing() and first.visible_characters==-1 and second.visible_characters==-1,"instant displays complete text")
	check(not playback.advance(1.9,"instant",true),"instant still keeps read dwell")
	playback.suspend()
	check(not playback.advance(1.9,"instant",true) and playback.advance(0.11,"instant",true),"hidden or paused dwell is reset")
	playback.begin([first,second],"instant")
	check(not playback.advance(100,"instant",false),"choice boundary cannot auto advance")
	playback.begin([first,second],"slow",false)
	check(not playback.is_revealing(),"history labels stay immediately visible")
	first.free()
	second.free()

func _test_snapshots(map: Node, clock: Node) -> void:
	map.loadout.spirit_stones = 111
	check(Checkpoints.write(map.loadout,map.inventory_save_path,"quick","baseline").is_empty(),"quick baseline writes")
	var quick_hash: String = FileAccess.get_sha256(Slots.quick_path())
	apply({"quick_save":false})
	map.loadout.spirit_stones = 222
	check(Checkpoints.write(map.loadout,map.inventory_save_path,"quick","battle_start").is_empty(),"disabled quick does not block guarded action")
	Checkpoints.after_action(map.loadout,map.inventory_save_path,"trade_buy")
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash and Checkpoints.pending_quick.is_empty(),"disabled actions keep existing quick snapshot")
	apply({"quick_save":true})
	DirAccess.make_dir_recursive_absolute(Slots.quick_path()+".tmp")
	Checkpoints.after_action(map.loadout,map.inventory_save_path,"trade_buy")
	check(not Checkpoints.pending_quick.is_empty(),"failed quick queues frozen completed snapshot")
	apply({"quick_save":false})
	check(Checkpoints.pending_quick.is_empty(),"disabling quick clears retry immediately")
	DirAccess.remove_absolute(Slots.quick_path()+".tmp")
	Checkpoints.retry_pending(100,map.inventory_save_path,true)
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"disabled retry cannot overwrite old snapshot")
	var auto_hash: String = FileAccess.get_sha256(Slots.auto_path)
	apply({"auto_save":false})
	check(Checkpoints.write(map.loadout,map.inventory_save_path,"auto","timer").is_empty(),"disabled auto exits cleanly")
	clock._process(9999)
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash and clock.schedule.elapsed==0,"disabled automatic schedule does not save")
	apply({"auto_save":true,"auto_save_minutes":5})
	clock._process(299)
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"five-minute clock waits before deadline")
	map.event_state.phase = "dialogue"
	map.event_state.active_id = "test.unsafe"
	clock._process(1)
	check(clock.schedule.pending and FileAccess.get_sha256(Slots.auto_path)==auto_hash,"due checkpoint waits until free movement")
	apply({"auto_save_minutes":10})
	check(not clock.schedule.pending and clock.schedule.elapsed==0,"changing interval clears due request")
	map.event_state.phase = ""
	map.event_state.active_id = ""
	clock._process(599)
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"new ten-minute interval starts fresh")
	clock._process(1)
	check(Files.read(Slots.auto_path).spirit_stones==222 and not clock.schedule.pending,"enabled timer writes final live state at deadline")

func _test_map_dialogue() -> void:
	apply({"dialogue_speed":"medium","dialogue_auto":false})
	var dialogue := MapDialogue.new()
	root.add_child(dialogue)
	dialogue.set_process(false)
	dialogue._phase = "dialogue"
	dialogue.text_label.text = "一二三四五六七八九十"
	dialogue.playback.begin([dialogue.text_label],"medium")
	dialogue.show()
	var advances := [0]
	dialogue.advance_requested.connect(func(): advances[0]+=1)
	dialogue.request_advance()
	check(advances[0]==0 and not dialogue.playback.is_revealing(),"map first click completes text without advancing")
	dialogue.request_advance()
	check(advances[0]==1,"map second click requests exactly one advance")
	apply({"dialogue_auto":true})
	dialogue.playback.begin([dialogue.text_label],"instant")
	dialogue._process(1.99)
	check(advances[0]==1,"map automatic wait is two seconds")
	dialogue._process(0.02)
	check(advances[0]==2,"map automatically requests continuous advance")
	dialogue._phase = "reward"
	dialogue.playback.begin([dialogue.text_label],"instant")
	dialogue._process(10)
	check(advances[0]==2,"map reward phase cannot advance automatically")
	dialogue.free()

func _test_npc_dialogue(map: Node) -> void:
	apply({"dialogue_speed":"medium","dialogue_auto":true})
	map.loadout.narrative = DialogueJournal.initial()
	map.event_state.active_id = CLINIC_EVENT
	map.event_state.phase = "clinic"
	map._present_event_progress()
	var dialog: MapClinicDialog = map.clinic_dialog
	dialog.set_process(false)
	check(dialog.visible and dialog.playback.is_revealing(),"new NPC speech starts revealing")
	dialog.request_continue()
	check(int(map.loadout.narrative.npcs[NPC].seen[WELCOME])==1 and not dialog.playback.is_revealing(),"NPC first continue only completes current speech")
	dialog.request_continue()
	check(int(map.loadout.narrative.npcs[NPC].seen[WELCOME])==2,"NPC second continue advances one speech")
	check(dialog.dialogue_rows.get_child(0).text_label.visible_characters==-1,"old NPC speech does not reveal again")
	dialog._process(100)
	check(int(map.loadout.narrative.npcs[NPC].seen[WELCOME])==3,"NPC automatic advances one continuous speech")
	dialog._process(100)
	check(not dialog._topics_opened and dialog.topic_buttons.values().all(func(button): return not button.visible),"NPC automatic stops before opening topic choices")
	dialog.request_continue()
	check(dialog._topics_opened and dialog.topic_buttons.values().all(func(button): return button.visible),"topic choices still require explicit continue")
	map._clinic_dialogue_command("select","medical")
	for i in 20:
		if not dialog._view.can_continue: break
		map._clinic_dialogue_command("advance","")
	check(dialog.playback.is_revealing(),"newly appended final topic speech still reveals")
	check(dialog.continue_button.visible and not dialog.topic_continue_hint.visible,"reveal hint does not overlap next-topic hint")
	dialog.playback.finish_reveal()
	dialog.refresh_dialogue()
	check(not dialog.playback.is_revealing(),"refresh of completed history does not replay text")
	var narrative_before: Dictionary = map.loadout.narrative.duplicate(true)
	dialog.set_mode("treatment")
	dialog._process(100)
	check(map.loadout.narrative==narrative_before,"treatment mode never auto progresses conversation")
	dialog.set_mode("conversation")
	var bindings: Dictionary = Settings.value("bindings",{})
	bindings.dialogue_continue = KEY_J
	apply({"bindings":bindings})
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_SPACE
	check(not dialog.handle_continue_input(key),"NPC old space binding no longer advances")
	key.physical_keycode = KEY_J
	check(dialog.handle_continue_input(key),"NPC rebound dialogue key is handled")
	key.keycode = KEY_J
	check(dialog.handle_continue_input(key),"NPC native logical plus physical rebound key is handled")
	bindings.dialogue_continue = KEY_M
	apply({"bindings":bindings,"dialogue_speed":"instant","dialogue_auto":false})
	map.loadout.narrative = DialogueJournal.initial()
	map._clinic_dialogue_command("visit","")
	var seen_before := int(map.loadout.narrative.npcs[NPC].seen[WELCOME])
	key.physical_keycode = KEY_M
	key.keycode = KEY_M
	map._input(key)
	check(int(map.loadout.narrative.npcs[NPC].seen[WELCOME])==seen_before+1 and not map.is_world_map_open(),"dialogue M binding takes priority over world-map M during conversation")
