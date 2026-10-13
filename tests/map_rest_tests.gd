extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("FAIL: "+message)
func settle() -> void:
	for frame in 8: await process_frame

func click(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=control.get_global_rect().get_center()
		event.button_index=button
		event.pressed=pressed
		root.push_input(event,true)
	await settle()

func hover(position: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=position
	event.global_position=position
	root.push_input(event,true)
	await settle()

func arrive(map: Node, point: String) -> void:
	var origin: String=map.travel.adjacency[point][0].to
	map.travel.current_node_id=origin
	map.travel.map_position=map.travel.node_positions[origin]
	map.travel.mode="idle"
	map.travel.paused=false
	map._visit_exploration(origin)
	check(map.travel.request_destination(point),"request rest destination")
	map.travel.advance(1000)
	await settle()

func verify_resources(map: Node, expected: Dictionary) -> void:
	for key: String in expected:
		check(is_equal_approx(float(map.player_status.resources[key]),float(expected[key])),"actual recovery: "+key)
		check(is_equal_approx(map.status_header.bars[key].value,float(expected[key])),"header bar updated: "+key)
		check(map.status_header.values[key].text=="%s/%d" % [EffectSystem.number_text(expected[key]),map.player_status.maxima[key]],"header value updated: "+key)
	check(map.player_status.battle_snapshot().resources==map.player_status.resources,"next battle snapshot uses recovered resources")

func validate_configs(event: Dictionary) -> void:
	var registry:=MapEventRegistry.new()
	check(registry.configure([event],[event.point_id]).is_empty(),"rest config accepted")
	for mutation in [{"rest_kind":"bad"},{"recovery_percent":0},{"recovery_percent":101},{"recovery_percent":30.5},{"duration_days":0},{"duration_days":1.5},{"title":""},{"note":false},{"presentation":{}},{"presentation":{"background":"res://missing.webp","illustration":event.presentation.illustration}}]:
		var broken:=event.duplicate(true)
		broken.merge(mutation,true)
		check(not registry.configure([broken],[event.point_id]).is_empty(),"reject bad rest config: "+str(mutation.keys()))

func verify_edge_cases() -> void:
	var status:=MapPlayerStatus.new()
	status.maxima={"hp":55,"stamina":45,"spirit":0}
	status.resources={"hp":1.125,"stamina":44.9,"spirit":0}
	var changed_count: Array=[0]
	status.changed.connect(func():changed_count[0]+=1)
	var result:=status.rest(30,1,"base.map_event.test.rest")
	check(result.error.is_empty() and is_equal_approx(status.resources.hp,17.625),"fractional current value retained; percent uses maximum")
	check(status.resources.stamina==45 and status.resources.spirit==0,"cap overflow; zero spirit maximum")
	check(changed_count[0]==1 and status.rest_days_spent==1,"single atomic update and one day recorded")
	check(result.result.before.hp==1.125 and result.result.gains.stamina>0 and result.result.after==status.resources,"record source, before/after and gains")
	result.result.after.hp=999
	check(status.resources.hp!=999 and status.last_rest.after.hp!=999,"returned receipt cannot mutate state")
	var before:=status.resources.duplicate()
	for args in [[0,1,"test"],[101,1,"test"],[30,0,"test"],[30,1,""]]:
		check(not status.rest(args[0],args[1],args[2]).error.is_empty(),"invalid rest command rejected")
	check(status.resources==before and status.rest_days_spent==1,"invalid command has no partial recovery or time cost")
	status.resources=status.maxima.duplicate()
	result=status.rest(50,1,"test")
	check(not status.needs_rest() and result.error.is_empty() and status.rest_days_spent==2,"all full still permits a day of rest")
	check(result.result.gains.values().all(func(value):return is_zero_approx(float(value))) and not status.needs_rest(),"full rest has zero recovery")

func verify_interaction(map: Node, event: Dictionary) -> void:
	var status: MapPlayerStatus=map.player_status
	var dialog: MapRestDialog=map.rest_dialog
	for key: String in status.resources: status.set_resource(key,status.maxima[key]*0.1)
	await arrive(map,event.point_id)
	check(map.event_state.phase=="rest" and dialog.visible and map.travel.paused,"arrival opens rest and pauses travel")
	check(map.event_state.advance().is_empty() and map.event_state.phase=="rest","dialogue advance cannot consume rest")
	var before:=status.resources.duplicate()
	var prior_days:=status.rest_days_spent
	for method in ["later","right","escape"]:
		if not dialog.visible: check(map._try_start_event(event.point_id,"click",true),"stationary rest reopens")
		await settle()
		if method=="later": await click(dialog.later_button)
		elif method=="right": await click(dialog.canvas,MOUSE_BUTTON_RIGHT)
		else:
			var escape:=InputEventKey.new()
			escape.keycode=KEY_ESCAPE
			escape.pressed=true
			root.push_input(escape,true)
			await settle()
		check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused and map.travel.mode=="idle","cancel exits cleanly: "+method)
		check(status.resources==before and status.rest_days_spent==prior_days,"cancel has no resource/time change: "+method)
	check(map._try_start_event(event.point_id,"click",true),"reopen for recovery")
	await settle()
	await hover(dialog.start_button.get_global_rect().get_center())
	check(dialog.start_button.is_hovered() and dialog.start_label.get_theme_color("font_color")==Color.BLACK,"hover changes caption to black")
	check(dialog.start_button.texture_hover.resource_path.ends_with("tanchuang-huifu-kaishi2.webp"),"hover artwork")
	await hover(dialog.canvas.global_position+Vector2(20,20))
	check(dialog.start_label.get_theme_color("font_color")==Color.WHITE,"exit hover restores white")
	dialog.set_busy(true)
	await click(dialog.start_button)
	await click(dialog.later_button)
	check(dialog.visible and status.resources==before and status.rest_days_spent==prior_days,"busy blocks confirmation and cancellation")
	dialog.set_busy(false)
	status.set_resource("stamina",status.maxima.stamina-0.2)
	status.set_resource("spirit",status.maxima.spirit)
	before=status.resources.duplicate()
	var expected: Dictionary={}
	for key: String in before: expected[key]=minf(float(status.maxima[key]),float(before[key])+float(status.maxima[key])*float(event.recovery_percent)/100.0)
	var inventory_before: Dictionary=map.loadout.snapshot()
	var progression_before: Array=[status.cultivation_progress,status.experience,status.spirit_stones,status.age]
	await click(dialog.start_button)
	verify_resources(map,expected)
	check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"successful rest closes dialog")
	check(status.rest_days_spent==prior_days+1 and status.last_rest.source_id==event.id,"one day receipt includes location")
	var inventory_after: Dictionary=map.loadout.snapshot()
	check(WorldCalendar.current_day(inventory_after.calendar)==WorldCalendar.current_day(inventory_before.calendar)+1,"rest advances global calendar one day")
	inventory_before.erase("calendar")
	inventory_after.erase("calendar")
	check(inventory_after==inventory_before and progression_before==[status.cultivation_progress,status.experience,status.spirit_stones,status.age],"no inventory or progression side effects")
	map._confirm_rest()
	dialog.request_rest()
	check(status.resources==expected and status.rest_days_spent==prior_days+1,"duplicate confirmation after close is ignored")
	check(not map.event_state.completed.has(event.id) and map.content.get_node("Points/"+event.point_id.get_slice(".",4).to_upper()+"/Sign").visible,"rest sign persists")
	check(map._try_start_event(event.point_id,"click",true),"rest site reusable after recovery")
	await settle()
	await click(dialog.start_button)
	check(status.rest_days_spent==prior_days+2,"second deliberate rest records another day")
	for key: String in status.resources: status.set_resource(key,status.maxima[key])
	check(map._try_start_event(event.point_id,"click",true),"full state still permits viewing location")
	await settle()
	check(not dialog.start_button.disabled and dialog.error_label.text.contains("仍会度过1天"),"all full enables rest with time notice")
	var full_day:=WorldCalendar.current_day(map.loadout.calendar)
	await click(dialog.start_button)
	check(status.rest_days_spent==prior_days+3 and WorldCalendar.current_day(map.loadout.calendar)==full_day+1,"full rest spends exactly one day")
	check(not status.needs_rest() and status.last_rest.gains.values().all(func(value):return is_zero_approx(float(value))) and not dialog.visible,"full rest closes with unchanged capped resources")
	status.set_resource("hp",status.maxima.hp-0.2)
	check(map._try_start_event(event.point_id,"click",true),"only one deficient resource permits rest")
	await settle()
	await click(dialog.start_button)
	check(status.resources.hp==status.maxima.hp and status.rest_days_spent==prior_days+4,"single deficient resource caps at maximum")

func verify_battle_handoff(map: Node) -> void:
	var status: MapPlayerStatus=map.player_status
	var days_before:=status.rest_days_spent
	var receipt:=status.last_rest.duplicate(true)
	var resources_before:=status.resources.duplicate()
	map.travel.current_node_id="base.map.qingshihewan.point.n30"
	map.travel.mode="idle"
	check(map._try_start_event(map.travel.current_node_id,"click",true),"next encounter opens")
	map._confirm_encounter()
	var presentation:=root.get_node("MapPresentation")
	while current_scene==map or presentation.transitioning: await process_frame
	var battle:=current_scene
	var game: GameManager=battle.get_node("GameManager")
	game.set_process(false)
	check(game.startup_error.is_empty(),"actual next battle starts with recovery")
	for key: String in resources_before: check(is_equal_approx(float(game.party[0].get(key)),float(resources_before[key])),"actual battle resource: "+key)
	game.start_battle()
	game.request_retreat()
	game._process(3)
	var error: String=await battle.get_node("MapBattleReturn").return_to_map()
	check(error.is_empty(),"return to map after battle: "+error)
	await settle()
	var returned:=current_scene
	check(returned.player_status==status and status.rest_days_spent==days_before and status.last_rest==receipt,"rest time/receipt retained across battle")
	returned.queue_free()
	await settle()

func run() -> void:
	create_timer(50).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path="res://artifacts/rest-test-%d.json" % Time.get_ticks_usec()
	map.defer_map_music=true
	root.add_child(map)
	current_scene=map
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"actual map startup")
	if not map.startup_error.is_empty(): quit(1); return
	var render_only:=DisplayServer.get_name()!="headless"
	var dialog: MapRestDialog=map.rest_dialog
	for suffix in ["n05","n13"]:
		var event: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_rest_%s.json" % suffix))
		check(map.event_registry.by_point.get(event.point_id)==event.id,"registered on actual map: "+suffix)
		dialog.present(event,true)
		await settle()
		check(dialog.heading.text==event.title and dialog.description.text==event.description and dialog.note.text==event.note,"exact location copy: "+suffix)
		check(dialog.percentage.text=="%d%%" % int(event.recovery_percent) and dialog.days.text=="1","actual rate and duration: "+suffix)
		check(dialog.illustration.texture.resource_path==event.presentation.illustration,"location artwork: "+suffix)
		for label: Label in [dialog.description,dialog.note,dialog.warning]:
			check(label.get_visible_line_count()==label.get_line_count(),"copy fits: "+suffix+" "+label.text)
		check(dialog.percentage.get_theme_font_size("font_size")>dialog.warning.get_theme_font_size("font_size"),"percentage enlarged")
		check(dialog.start_label.text==event.action_label,"action caption")
		if render_only:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/rest-"+suffix+".png")
		dialog.hide()
		if not render_only:
			validate_configs(event)
			await verify_interaction(map,event)
	if render_only: map.queue_free()
	else:
		verify_edge_cases()
		await verify_battle_handoff(map)
	await settle()
	print("MAP REST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
