extends SceneTree

var checks := 0
var failures := 0
var save_path := "res://artifacts/calendar-%d.json" % Time.get_ticks_usec()

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func settle() -> void:
	for i in 8: await process_frame
func new_map() -> Node:
	var map: Node=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=save_path
	map.defer_map_music=true
	root.add_child(map)
	current_scene=map
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map startup: "+map.startup_error)
	return map
func open_at(map: Node, suffix: String) -> void:
	map.travel.current_node_id="base.map.qingshihewan.point."+suffix
	map.travel.map_position=map.travel.node_positions[map.travel.current_node_id]
	map.travel.mode="idle"
	map.travel.paused=false
	map._visit_exploration(map.travel.current_node_id)
	check(map._try_start_event(map.travel.current_node_id,"click",true),"open "+suffix)
	await settle()
func advance_saved(map: Node, days: int) -> void:
	var prepared:=MapLoadoutStore.candidate(map.loadout)
	check(prepared.error.is_empty(),"calendar transaction clone")
	check(prepared.state.advance_days(days,"base.test.calendar").is_empty(),"advance explicit days")
	check(MapLoadoutStore.save(prepared.state,save_path).is_empty(),"save advanced calendar")
	check(map.loadout.restore(prepared.state.snapshot()).is_empty(),"publish advanced calendar")
	await settle()
func verify_readout(map: Node) -> void:
	check(not map.calendar_readout.visible,"date remains hidden on maps")
	check(map.calendar_readout.caption.text==WorldCalendar.date_text(map.loadout.calendar).trim_prefix(str(WorldCalendar.rules().world_name)+"·"),"short date reflects authority without world prefix")
	check(map.calendar_readout.tooltip_text==WorldCalendar.date_text(map.loadout.calendar,true),"full date includes cycle")
	check(not map.calendar_readout.caption.text.contains("纪") and map.calendar_readout.tooltip_text.contains("纪"),"cycle hidden in compact date")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(map.calendar_readout.get_global_rect()),"date contained in viewport")
	check(map.calendar_readout.position.y>=MapStatusHeader.height_for_width(map.size.x),"date clears existing header")

func arithmetic() -> void:
	check(WorldCalendar.configuration_error().is_empty(),"calendar rules valid")
	var calendar:=WorldCalendar.initial()
	check(WorldCalendar.date_text(calendar)=="苍澜界·青鹿年·正月初一","default birthday date")
	check(WorldCalendar.date_text(calendar,true)=="苍澜界·第一纪·青鹿年·正月初一","initial complete date")
	for day in 360:
		var parts:=WorldCalendar.date_parts(calendar)
		check(parts.month==day/30+1 and parts.day==day%30+1,"all 360 dates: %d" % day)
		check(WorldCalendar.advance(calendar,1,"test").is_empty(),"advance one day")
	check(WorldCalendar.date_text(calendar)=="苍澜界·玄狐年·正月初一","next beast year")
	WorldCalendar.advance(calendar,3960,"test")
	check(WorldCalendar.date_text(calendar,true)=="苍澜界·第二纪·青鹿年·正月初一","twelve-year rollover")
	for birthday in [[5,17],[12,30],[2,30]]:
		var custom:=WorldCalendar.initial(birthday)
		check(WorldCalendar.valid_record(custom),"custom birthday accepted")
		check(WorldCalendar.date_parts(custom).month==birthday[0] and WorldCalendar.date_parts(custom).day==birthday[1],"start uses birthday")
		WorldCalendar.advance(custom,360,"test")
		check(WorldCalendar.date_parts(custom).month==birthday[0] and WorldCalendar.date_parts(custom).day==birthday[1],"birthday after one year")
	for invalid in [[0,1],[13,1],[1,31],[1.5,1],[1]]: check(WorldCalendar.initial(invalid).is_empty(),"invalid birthday rejected")
	var before:=calendar.duplicate(true)
	for days in [0,-1,WorldCalendar.MAX_DAY]: check(not WorldCalendar.advance(calendar,days,"test").is_empty(),"invalid duration rejected")
	check(calendar==before,"invalid duration cannot mutate date")
	for mutation in [{"elapsed_days":-1},{"elapsed_days":0.5},{"start_day":1},{"birthday":[2,31]}]:
		var broken:=before.duplicate(true)
		broken.merge(mutation,true)
		check(not WorldCalendar.valid_record(broken),"invalid calendar rejected")
	check(WorldCalendar.month_day(12,30)=="腊月三十" and WorldCalendar.month_day(2,21)=="二月廿一","traditional month/day notation")
	for number: int in {10:"十",110:"一百一十",1010:"一千零一十",101010:"十万一千零一十"}:
		check(WorldCalendar.chinese_number(number)=={10:"十",110:"一百一十",1010:"一千零一十",101010:"十万一千零一十"}[number],"complete cycle number: %d" % number)

func rest_and_gather(map: Node) -> void:
	var start_day:=WorldCalendar.current_day(map.loadout.calendar)
	map.player_status.set_resource("hp",1)
	await open_at(map,"n05")
	map._cancel_rest()
	check(WorldCalendar.current_day(map.loadout.calendar)==start_day,"cancel rest costs no day")
	await open_at(map,"n05")
	var before: Dictionary=map.loadout.snapshot()
	var hp_before: float=map.player_status.resources.hp
	map.inventory_save_path="res://artifacts/nonexistent-calendar-directory/save.json"
	map._confirm_rest()
	check(map.rest_dialog.visible and not map.rest_dialog.error_label.text.is_empty(),"failed rest save is retryable")
	check(map.loadout.snapshot()==before and map.player_status.resources.hp==hp_before,"failed save changes neither resource nor time")
	map.inventory_save_path=save_path
	map._confirm_rest()
	await settle()
	check(WorldCalendar.current_day(map.loadout.calendar)==start_day+1,"rest spends one day")
	check(is_equal_approx(map.player_status.resources.hp,hp_before+map.player_status.maxima.hp*0.3),"rest still restores 30 percent")
	map._confirm_rest()
	check(WorldCalendar.current_day(map.loadout.calendar)==start_day+1,"repeat callback does not spend again")
	verify_readout(map)
	for suffix in ["n04","n19"]:
		await open_at(map,suffix)
		var day_before:=WorldCalendar.current_day(map.loadout.calendar)
		var forecast: Dictionary=map.gathering_dialog.options.forecast(2)
		map._begin_gathering(forecast)
		check(map.event_state.phase=="gathering_reward","gathering result created")
		check(WorldCalendar.current_day(map.loadout.calendar)==day_before+int(forecast.days),"herb/mining spends selected duration")
		map._cancel_gathering()
		await open_at(map,suffix)
		check(map.event_state.phase=="gathering_reward" and WorldCalendar.current_day(map.loadout.calendar)==day_before+int(forecast.days),"reopen pending result never charges twice")
		map._accept_gathering()
		check(WorldCalendar.current_day(map.loadout.calendar)==day_before+int(forecast.days),"claim result costs no further time")

func chest_cycle(map: Node) -> void:
	await open_at(map,"n06")
	map._open_chest()
	var event: Dictionary=map.event_state.active_event()
	var base_id: String=event.source_reward_id
	map.chest_dialog.select_choice(0)
	map._accept_chest()
	check(map.loadout.has_reward(base_id),"first chest receipt retained")
	var first_owned: Array=map.loadout.snapshot().owned_units.keys()
	check(map.loadout.chest_cooldowns[base_id].remaining_days==40,"forty-day deadline created")
	await advance_saved(map,39)
	check(map.event_state.completed.has(event.id),"chest closed on day 39")
	await advance_saved(map,1)
	check(not map.event_state.completed.has(event.id),"chest restored on day 40")
	check(map.content.get_node("Points/N06/Sign").visible,"restored chest sign visible")
	await open_at(map,"n06")
	map._open_chest()
	var second: Dictionary=map.event_state.active_event()
	check(second.reward_id==base_id+".cycle.2","new opening gets new receipt")
	map.chest_dialog.select_choice(1)
	map._accept_chest()
	check(map.loadout.has_reward(second.reward_id),"second opening can grant item")
	check(first_owned.all(func(id): return map.loadout.snapshot().owned_units.has(id)),"refresh preserves all previous inventory units")
	check(map.loadout.chest_cooldowns[base_id].cycle==2 and map.loadout.chest_cooldowns[base_id].remaining_days==40,"second opening resets deadline once")
	var legacy: Dictionary=map.loadout.snapshot()
	legacy.erase("calendar")
	legacy.erase("respawn_rules_version")
	legacy.erase("encounter_cooldowns")
	legacy.chest_cooldowns[base_id]={"delay_days":30,"remaining_days":17}
	var clone:=MapLoadoutStore.candidate(map.loadout)
	check(clone.state.restore(legacy).is_empty(),"old save migrates")
	check(clone.state.chest_cooldowns[base_id].ready_day==27 and clone.state.calendar.elapsed_days==0,"legacy countdown preserves elapsed days with ten-day extension")

func victory_deadline(map: Node) -> Node:
	await open_at(map,"n30")
	var event_id: String=map.event_state.active_id
	var day_before:=WorldCalendar.current_day(map.loadout.calendar)
	map._confirm_encounter()
	var presentation:=root.get_node("MapPresentation")
	while current_scene==map or presentation.transitioning: await process_frame
	var battle:=current_scene
	var game: GameManager=battle.get_node("GameManager")
	game.set_process(false)
	game.start_battle()
	game.simulation._finish("victory",0)
	game._process(0)
	var flow:=battle.get_node("MapBattleReturn")
	check(flow.reward_error.is_empty(),"victory saves reward plus deadline")
	check(game._durable_snapshot.encounter_cooldowns[event_id]==day_before+20,"actual victory creates 20-day deadline")
	check(WorldCalendar.current_day(game._durable_snapshot.calendar)==day_before,"battle does not advance calendar")
	check((await flow.return_to_map()).is_empty(),"battle return")
	await settle()
	var returned:=current_scene
	returned.set_process(false)
	check(returned.event_state.completed.has(event_id),"defeated enemy stays hidden after return")
	await advance_saved(returned,19)
	check(returned.event_state.completed.has(event_id),"enemy remains absent before deadline")
	var saved_calendar: Dictionary=returned.loadout.calendar.duplicate(true)
	returned.queue_free()
	await settle()
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	returned=await new_map()
	check(returned.loadout.calendar==saved_calendar and returned.event_state.completed.has(event_id),"restart preserves date and defeated enemy")
	await advance_saved(returned,1)
	check(not returned.event_state.completed.has(event_id) and returned.content.get_node("Points/N30/Sign").visible,"enemy returns at deadline")
	check(returned.event_state.resolved_event(event_id).enemy_id==returned.event_registry.events[event_id].enemy_id,"respawn keeps configured species")
	check(not returned.loadout.encounter_cooldowns.has("base.map_event.qingshihewan.encounter_n07"),"undefeated nodes do not get invented death dates")
	return returned

func run() -> void:
	create_timer(55).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	arithmetic()
	var map:=await new_map()
	if not map.startup_error.is_empty(): quit(1); return
	if DisplayServer.get_name()=="headless":
		await rest_and_gather(map)
		await chest_cycle(map)
		map=await victory_deadline(map)
		var elapsed: int=map.loadout.calendar.elapsed_days
		await advance_saved(map,360-elapsed)
		check(map.player_status.age==map.player_status.initial_age+1,"one birthday increases age by one")
		var date_before: Dictionary=map.loadout.calendar.duplicate(true)
		map._process(20)
		check(map.loadout.calendar==date_before,"idle frames cost no game time")
		map.travel.current_node_id="base.map.qingshihewan.point.east_exit"
		map.travel.mode="idle"
		check(map._try_open_exit(map.travel.current_node_id),"cross-map exit")
		await map._complete_exit()
		await settle()
		map=current_scene
		check(map.loadout.calendar==date_before and map.player_status.age==16,"date and age retained across maps")
		verify_readout(map)
	else:
		verify_readout(map)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/calendar-map.png")
	map.queue_free()
	var presentation:=root.get_node("MapPresentation")
	presentation._cancel_fade()
	presentation.music.stop()
	presentation.music.stream=null
	await settle()
	print("WORLD CALENDAR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
