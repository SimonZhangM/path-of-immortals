extends "res://tests/first_qi_breakthrough_tests.gd"

func prepare_audio_fixture(prefix: String) -> bool:
	create_timer(50).timeout.connect(func(): quit(2))
	directory=prefix+"/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	Session.clear_selection()
	path=directory+"working.json"
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	# Keep playback tests quiet while allowing the Music bus clock to advance.
	AudioServer.set_bus_mute(0,false)
	AudioServer.set_bus_volume_db(0,-90.0)
	map=load("res://scenes/maps/baishacun.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true; map.defer_optional_views=true
	root.add_child(map)
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map startup")
	if not map.startup_error.is_empty(): return false
	state=map.loadout
	baseline=state.snapshot()
	baseline.placements=[]
	baseline.board_id="base.board.qinglan_1"
	baseline.growth=CultivationGrowth.initial(0)
	baseline.growth.progress=CultivationGrowth.target(baseline.growth)
	baseline.growth.resources={"hp":1000,"stamina":5000,"spirit":5000}
	baseline.learning={"version":1,"learned":{},"practice":{}}
	baseline.map_location=HomecomingQuest.data.home.duplicate(true)
	baseline.owned_units["test.first_qi.guide"]=GUIDE
	baseline.owned_units["test.audio.sword"]="base.map_item.qingshi_short_sword"
	baseline.owned_units["test.audio.restore"]="base.map_item.t01_0019"
	baseline.content_grants["training.guide.v1"]=true
	baseline.narrative.flags.erase(Run.FIRST_QI_FLAG)
	for target: Dictionary in QuestState.definition.objectives: baseline.quests[QuestState.ID].counts[target.id]=target.required
	baseline.quests[QuestState.ID].story=QuestStory.migrated({"counts":baseline.quests[QuestState.ID].counts})
	baseline.quests[RiverQuest.ID].done=["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	baseline.quests[RiverQuest.ID].accepted_location=RiverQuest.RIVER
	var quest: Dictionary=baseline.quests[HomecomingQuest.ID]
	quest.active=""; quest.line=0; quest.location={}; quest.reward_pending=false
	quest.accepted_location=HomecomingQuest.data.shop.map_id
	quest.letter_received=true; quest.home_reunited=true; quest.guidance_completed=true
	restore_fixture()
	equip_guide()
	check(state.inventory.add_item("test.audio.sword","base.map_item.qingshi_short_sword",Vector2i(1,0)),"equip actual weapon")
	state.storage.take_one("test.audio.sword")
	check(state.inventory.add_item("test.audio.restore","base.map_item.t01_0019",Vector2i(3,0)),"equip actual restoration item")
	state.storage.take_one("test.audio.restore")
	map.inventory_save_path=path
	map.set_breakthrough_open(true)
	await settle()
	return true

func run() -> void:
	if not await prepare_audio_fixture("res://artifacts/breakthrough-audio-20261105"): quit(1); return
	var flow: RefCounted=map.breakthrough_session
	var screen: Control=map.breakthrough_screen
	var sound_view: Node=screen.get_node("BreakthroughAudio")
	var battle_audio := GameAudio.new()
	root.add_child(battle_audio)
	battle_audio.configure_effects()
	var sounds: Array[String]=[]
	sound_view.audio.sound_played.connect(func(kind): sounds.append(kind))
	check(sound_view.audio.music==null,"breakthrough creates no battle BGM")
	check(sound_view.audio.players.values().all(func(p): return p.bus=="Effects"),"all item sounds respect existing Effects volume bus")
	check(flow.start(),"start actual breakthrough")
	flow.advance(10)
	check(sounds.has("magic"),"actual guide payment plays sound")
	check(sounds.has("hit"),"actual weapon damage event plays battle sound")
	check(sounds.has("restore"),"actual restoration plays battle sound")
	check(is_equal_approx(sound_view.audio.players.hit.volume_linear,battle_audio.players.hit.volume_linear*0.8),"breakthrough weapon volume is 80 percent of battle volume")
	check(is_equal_approx(sound_view.audio.players.restore.volume_linear,battle_audio.players.restore.volume_linear),"restoration keeps its existing volume")
	check(is_equal_approx(sound_view.audio.players.magic.volume_linear,battle_audio.players.magic.volume_linear),"guide activation keeps its existing volume")
	check(flow.runtime.progress()>0,"audio preserves actual breakthrough income")
	var count := sounds.size()
	flow.set_paused(true)
	check(sound_view.audio.players.values().all(func(p): return not p.playing),"pause stops active sounds")
	flow.advance(20)
	check(sounds.size()==count,"pause generates no new sounds")
	flow.set_paused(false)
	flow.advance(6)
	check(sounds.size()>count,"resume generates subsequent real events")
	check(is_equal_approx(sound_view.audio.players.hit.volume_linear,battle_audio.players.hit.volume_linear*0.8),"resume preserves weapon volume without repeated attenuation")
	# Multiple packets from one hit play once; no visual effects are constructed.
	sounds.clear()
	var snapshot := state.snapshot()
	var nodes := screen.get_child_count()
	var packet := {"kind":"damage","at_usec":123,"instance_id":"test","item_id":"base.map_item.qingshi_short_sword","target_id":"dummy","value":1}
	var batch: Array[Dictionary]=[packet,packet.duplicate(true),{"kind":"restore","value":0}]
	sound_view.present(batch)
	check(sounds==["hit"],"multi-packet hit deduplicated and zero restore silent")
	check(state.snapshot()==snapshot and screen.get_child_count()==nodes,"sound presentation neither mutates gameplay nor spawns damage visuals")
	map.set_breakthrough_open(false)
	check(sound_view.audio.players.values().all(func(p): return not p.playing),"closing stops active sounds")
	sounds.clear(); sound_view.present(batch)
	check(sounds.is_empty(),"hidden or paused screen rejects sounds")
	map.set_breakthrough_open(true)
	flow.set_paused(false)
	sound_view.present(batch)
	check(is_equal_approx(sound_view.audio.players.hit.volume_linear,battle_audio.players.hit.volume_linear*0.8),"reopening preserves weapon volume")
	map.set_breakthrough_open(false)
	battle_audio.queue_free()
	# Failed persistence must not publish simulated but uncommitted events.
	restore_fixture(); equip_guide()
	var broken := new_run()
	var emitted: Array[Dictionary]=[]
	broken.presentation_events.connect(func(events): emitted.append_array(events))
	check(broken.start(),"prepare isolated failed-save scenario")
	broken.advance(5)
	emitted.clear()
	broken.training.save_path=directory+"missing/save.json"
	snapshot=state.snapshot()
	broken.advance(1)
	check(broken.phase=="paused" and not broken.error.is_empty(),"failed save pauses run")
	check(emitted.is_empty() and state.snapshot()==snapshot,"failed payment emits no sound and commits no resources")
	map.queue_free()
	await settle()
	print("Breakthrough audio: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
