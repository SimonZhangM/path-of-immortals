extends "res://tests/map_shop_tests.gd"

const GUIDE := "base.map_item.training_guide_stone"
const TRAINING_EVENT := "base.map_event.qingshihewan.cultivation_n32"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	var state: MapLoadoutState=map.loadout
	check(state.growth.realm==5 and state.growth.layer==1,"test player spirit transformation layer 1")
	check(state.growth.roots.size()==7,"seven test roots")
	check(CultivationGrowth.maxima(state.growth)=={"hp":6400,"stamina":4000,"spirit":5000},"approved base maxima")
	check(CultivationGrowth.display(18.25)=="18.3" and CultivationGrowth.display(0.04+0.04)=="0.1","half-up display")
	var raw:=state.snapshot()
	raw.placements=[]
	raw.owned_units["test.guide"]=GUIDE
	check(state.restore(raw).is_empty(),"guide inventory")
	check(state.inventory.add_item("test.guide",GUIDE,Vector2i.ZERO),"equip guide")
	state.storage.take_one("test.guide")
	var books: Array[String]=[]
	for id: String in state.registry.library.books:
		if books.size()==2: break
		books.append(id)
		state.storage.put(state._unit("test."+id,id))
	for mode: String in ["cultivation","technique","balanced"]:
		var waiting:=MapCultivationSession.new()
		check(waiting.begin(map.event_registry.events[TRAINING_EVENT],mode,5,WorldCalendar.current_day(state.calendar)) and waiting.bind(state,map.player_status,""),"prepare "+mode)
		var before_wait:=state.snapshot()
		waiting.advance(60)
		check(waiting.paused and not waiting.started and state.snapshot()==before_wait,"no automatic settlement "+mode)
		waiting.suspend("inventory",true,0)
		waiting.suspend("inventory",false,0)
		check(waiting.paused and not waiting.started,"board adjustment does not start "+mode)
		waiting.finish(0)
	var s:=MapCultivationSession.new()
	check(s.begin(map.event_registry.events[TRAINING_EVENT],"balanced",5,WorldCalendar.current_day(state.calendar)),"begin")
	check(s.bind(state,map.player_status,""),"bind: "+s.error)
	check(s.select_books(books),"two books")
	var prepared_state:=state.snapshot()
	s.advance(60)
	check(s.paused and not s.started and state.snapshot()==prepared_state,"selecting books never starts or settles training")
	map.cultivation_session=s
	map.cultivation_progress_dialog.present(s)
	await settle()
	check(map.cultivation_progress_dialog.pause_caption.text=="开始修炼","initial start caption")
	check(not "/" in map.cultivation_progress_dialog.cultivation_caption.text,"current cultivation omits target")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/cultivation-ready.png")
	await click(map.cultivation_progress_dialog.pause_button)
	check(s.started and not s.paused and map.cultivation_progress_dialog.pause_caption.text=="暂停修炼","start button begins training")
	await click(map.cultivation_progress_dialog.pause_button)
	check(s.paused and map.cultivation_progress_dialog.pause_caption.text=="继续修炼","pause button switches to continue")
	await click(map.cultivation_progress_dialog.pause_button)
	check(not s.paused,"continue button resumes")
	map.cultivation_progress_dialog.hide()
	var stamina: float=map.player_status.resources.stamina
	var spirit: float=map.player_status.resources.spirit
	s.advance(60)
	check(s.error.is_empty(),"settlement: "+s.error)
	check(s.elapsed_days==1 and state.growth.day_usec==0,"60 seconds exactly one day")
	check(is_equal_approx(map.player_status.resources.stamina,stamina-60),"actual stamina 60")
	check(is_equal_approx(map.player_status.resources.spirit,spirit-20),"actual spirit 20")
	check(s.cultivation_gain==660,"balanced character +6.60")
	for id: String in books: check(is_equal_approx(state.knowledge.practice_value(id),6.6),"parallel book +6.60 "+id)
	s.set_paused(true,0)
	s.advance(60)
	check(s.elapsed_days==1,"pause stops time")
	s.set_paused(false,0)
	s.advance(30)
	check(state.growth.day_usec==30000000,"partial day retained")
	check(MapLoadoutStore.candidate(state).error.is_empty(),"growth/learning roundtrip")
	var checkpoint:=state.snapshot()
	var day_before:=WorldCalendar.current_day(state.calendar)
	s.finish(0)
	var resumed:=session_for(map,"cultivation")
	resumed.advance(30)
	check(WorldCalendar.current_day(state.calendar)==day_before+1,"half day finishes after reopening")
	check(state.content_grants.get("training.guide.v1",false),"guide gift receipt")
	check(state.snapshot().owned_units.values().count(GUIDE)==2,"reopen does not duplicate gift (one test fixture plus one gift)")
	state.restore(checkpoint)
	var slow:=session_for(map,"cultivation")
	for n in 30: slow.advance(1)
	var slow_result:=state.snapshot()
	state.restore(checkpoint)
	var fast:=session_for(map,"cultivation")
	fast.speed=60
	fast.advance(0.5)
	check(state.snapshot()==slow_result,"60x and 1x exact same settlement")
	state.restore(checkpoint)
	var failed:=session_for(map,"cultivation")
	failed.save_path="user://missing-cultivation-directory/fail.json"
	var old:=state.snapshot()
	failed.advance(6)
	check(failed.paused and not failed.error.is_empty(),"save failure pauses")
	check(state.snapshot()==old,"save failure no partial publication")
	state.restore(checkpoint)
	state.growth.day_usec=0
	state.growth.budget=0
	var ordinary:=session_for(map,"technique")
	state.spirit_stones=0
	state.growth.day_paid=true # Legacy flag must not re-enable fees or bonuses.
	ordinary.select_books(books)
	ordinary.set_paused(false,0)
	var practice:=state.knowledge.practice_value(books[0])
	ordinary.advance(60)
	check(state.spirit_stones==0 and ordinary.error.is_empty(),"legacy auxiliary flag never charges or requires stones")
	check(is_equal_approx(state.knowledge.practice_value(books[0])-practice,11.0),"no auxiliary bonus")
	state.restore(checkpoint)
	state.growth.day_paid=true
	state.spirit_stones=0
	var legacy_resume:=session_for(map,"cultivation")
	legacy_resume.advance(30)
	check(state.spirit_stones==0 and not state.growth.day_paid and legacy_resume.elapsed_days==1,"legacy partial day finishes without fee")
	state.restore(checkpoint)
	state.growth.day_usec=0; state.growth.budget=0
	state.growth.resources.stamina=0; state.growth.resources.spirit=0
	map.player_status.apply_growth(state.growth)
	var exhausted:=session_for(map,"cultivation")
	exhausted.advance(60)
	check(exhausted.cultivation_gain==0 and map.player_status.resources.stamina==0 and map.player_status.resources.spirit==0,"insufficient resources produce no practice or negative balance")
	state.restore(checkpoint)
	state.growth.day_usec=0; state.growth.budget=0
	check(state.inventory.add_item("gift.training.guide",GUIDE,Vector2i(1,0)),"second guide fixture")
	state.storage.take_one("gift.training.guide")
	var capped:=session_for(map,"cultivation")
	capped.advance(60)
	check(capped.cultivation_gain==1200,"multiple guides share one daily cap")
	state.restore(checkpoint)
	var no_roots:=state.growth.duplicate(true)
	no_roots.roots=[]
	check(not CultivationGrowth.book_error(no_roots,state.registry.library,state.knowledge,books[0]).is_empty(),"no spiritual root rejected")
	check(CultivationGrowth.award_book(no_roots,state.registry.library,state.knowledge,books[0],60000)==0,"root guard inside settlement")
	var spell_book: String="base.cultivation_book.metal_04"
	check(state.registry.library.books[spell_book].max_level==8,"eight-stage fixture")
	state.storage.put(state._unit("test.spellbook",spell_book))
	state.knowledge.practice[spell_book]=599.9
	state.growth.day_usec=0; state.growth.budget=0
	var unlock:=session_for(map,"technique")
	check(unlock.select_books([spell_book]),"select eight stage book")
	unlock.set_paused(false,0)
	unlock.advance(6)
	check(state.knowledge.level(spell_book)==1,"first stage automatically achieved")
	var learned:=state.knowledge.learned_spells(state.registry.library)
	check(not learned.is_empty(),"odd stage unlocks spell")
	for id: String in learned: check(state.snapshot().owned_units.values().count(id)==1,"learned spell granted exactly once")
	check(is_equal_approx(state.knowledge.practice_value(spell_book),1.0),"extra practice carries to next stage")
	var practice_before:=state.knowledge.snapshot()
	map.player_status.award_progression({"cultivation":1.25,"experience":3})
	check(state.knowledge.snapshot()==practice_before,"battle reward never practices books")
	var save_path: String="user://cultivation-runtime-isolated.json"
	check(MapLoadoutStore.save(state,save_path).is_empty(),"durable save")
	var clone: MapLoadoutState=MapLoadoutStore.candidate(state).state
	var reload_error:=MapLoadoutStore.load_into(clone,save_path)
	print("reload: ",reload_error)
	for key in state.snapshot():
		if clone.snapshot().get(key)!=state.snapshot()[key]: print("different: ",key)
	check(reload_error.is_empty() and clone.snapshot()==state.snapshot(),"durable reload")
	state.restore(checkpoint)
	var low:=state.snapshot()
	low.growth=CultivationGrowth.initial(0)
	low.growth.resources={"hp":5000,"stamina":5000,"spirit":5000}
	low.growth.progress=10000
	low.learning={"version":1,"learned":{},"practice":{}}
	check(state.restore(low).is_empty(),"mortal fixture")
	var mortal:=session_for(map,"cultivation")
	day_before=WorldCalendar.current_day(state.calendar)
	check(mortal.breakthrough(),"mortal breakthrough 100 percent")
	check(state.growth.realm==1 and state.growth.layer==1 and state.growth.progress==0,"breakthrough transitions to qi first layer")
	check(WorldCalendar.current_day(state.calendar)==day_before+1,"breakthrough costs day")
	check(is_equal_approx(CultivationGrowth.breakthrough_chance(state.growth,.2),.9),"pill bonus hook percentage points")
	var higher:=state.snapshot()
	higher.growth.layer=10
	higher.growth.progress=400000
	var rng:=RandomNumberGenerator.new()
	for serial in 100:
		rng.seed=1792390426+serial
		if rng.randf()>=.7: higher.growth.breakthrough_serial=serial; break
	state.restore(higher)
	var attempt:=session_for(map,"cultivation")
	day_before=WorldCalendar.current_day(state.calendar)
	check(not attempt.breakthrough(),"configured failure result")
	check(state.growth.realm==1 and state.growth.layer==10 and state.growth.progress==320000,"failure retains realm and 80 percent preparation")
	check(WorldCalendar.current_day(state.calendar)==day_before+3,"failed attempt costs three days")
	for realm in range(1,6):
		var g:=CultivationGrowth.initial(realm)
		for layer in range(1,10):
			var target:=CultivationGrowth.target(g)
			check(CultivationGrowth.award(g,target)==target and g.layer==layer+1,"automatic level %d/%d" % [realm,layer])
		if realm==5: check(CultivationGrowth.maxima(g)=={"hp":10000,"stamina":5800,"spirit":7700},"final resource scale")
	state.restore(checkpoint)
	map.cultivation_session=session_for(map,"balanced")
	map.cultivation_session.select_books(books)
	map.cultivation_session.set_paused(false,0)
	map.cultivation_session.advance(6)
	map.cultivation_progress_dialog.present(map.cultivation_session)
	await settle()
	check(map.cultivation_progress_dialog.cultivation_percent.text.begins_with("＋"),"UI cumulative gain")
	map._open_cultivation_techniques()
	check(map.cultivation_progress_dialog.technique_choice.visible and map.cultivation_session.suspensions.has("choice"),"choice pauses simulation")
	map.cultivation_progress_dialog.technique_choice.close()
	check(map.cultivation_session.suspensions.is_empty(),"choice close resumes")
	if DisplayServer.get_name()!="headless":
		await process_frame
		root.get_texture().get_image().save_png("res://artifacts/cultivation-runtime.png")
	map.cultivation_progress_dialog.hide()
	map.technique_screen.show()
	state.knowledge.record_achievement(state.registry.library,spell_book,1,5)
	state.knowledge.record_achievement(state.registry.library,spell_book,2,5)
	map.technique_screen.focus_book(spell_book)
	await settle()
	check(map.technique_screen.right_panel.find_children("*", "Label", true, false).filter(func(label): return label.is_visible_in_tree()).is_empty(), "unconfigured right panel has no visible detail text")
	check(map.technique_screen.right_panel.find_children("*", "Button", true, false).filter(func(button): return button.is_visible_in_tree()).is_empty(), "unconfigured right panel has no visible controls")
	check(state.knowledge.branch(spell_book,2).is_empty(), "clearing detail UI does not select an earned branch")
	map.status_header.map_title.hide()
	await settle()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png("res://artifacts/cultivation-learning.png")
	map.queue_free()
	await settle()
	print("Cultivation runtime checks: ",checks," failures: ",failures)
	quit(1 if failures else 0)

func session_for(map,mode: String) -> MapCultivationSession:
	var s:=MapCultivationSession.new()
	check(s.begin(map.event_registry.events[TRAINING_EVENT],mode,5,WorldCalendar.current_day(map.loadout.calendar)),"new session")
	check(s.bind(map.loadout,map.player_status,""),"bound session: "+s.error)
	if mode=="cultivation": s.set_paused(false,0)
	return s
