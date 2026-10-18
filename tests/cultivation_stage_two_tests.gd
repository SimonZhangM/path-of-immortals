extends "res://tests/map_shop_tests.gd"

const CULTIVATION_POINT := "base.map.qingshihewan.point.n32"
const CULTIVATION_EVENT := "base.map_event.qingshihewan.cultivation_n32"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	map.travel.current_node_id=CULTIVATION_POINT
	map.travel.map_position=map.travel.node_positions[CULTIVATION_POINT]
	map.travel.stop_at_current_node()
	check(map._try_start_event(CULTIVATION_POINT,"click",true),"open stage one")
	map.cultivation_dialog.select_mode("balanced")
	map.cultivation_dialog.select_days(15)
	# Match save/restore's canonical integer birthday before fixture rollback.
	map.loadout.calendar=WorldCalendar.normalized(map.loadout.calendar)
	var before: Dictionary=map.loadout.snapshot()
	var resources: Dictionary=map.player_status.resources.duplicate(true)
	var render:=DisplayServer.get_name()!="headless"
	if render: map._request_cultivation("balanced",15)
	else: await click(map.cultivation_dialog.start_button)
	var view: MapCultivationProgressDialog=map.cultivation_progress_dialog
	var session: MapCultivationSession=map.cultivation_session
	check(view.visible and not map.cultivation_dialog.visible,"stage one transitions to stage two")
	check(session.mode_id=="balanced" and session.duration_days==15,"selected mode and days carried over")
	check(view.location_label.text=="瀑下静台" and view.mode_label.text=="兼修并进" and view.duration_label.text=="持续15天","three info labels omit prefixes")
	var description_rect: Rect2=view.description.get_meta("source_rect")
	check(description_rect==Rect2(850,189,562,79) and view.description.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT,"status moves up five source pixels, left aligned")
	check(not view.description.text.contains("\n") and view.description.get_line_count()==1,"status description stays on one line")
	check(is_equal_approx(description_rect.get_center().y,228.5) and view.description.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"status keeps vertical alignment with five-pixel upward optical offset")
	check(view.cultivation_caption.text.is_empty() and view.cultivation_percent.text=="—" and view.cultivation_bar.ratio==0,"unknown cultivation remains blank without invented percent")
	check(view.technique_caption.text=="未选择功法" and view.technique_percent.text=="—" and session.techniques.is_empty(),"no legacy techniques silently added")
	check(view.day_label.text=="0/15天" and view.day_bar.ratio==0,"days from calendar start at zero")
	check(view.day_bar.end_color.g>view.day_bar.end_color.r and view.day_bar.start_color!=view.day_bar.end_color,"green day gradient")
	check(view.cultivation_bar.start_color!=view.cultivation_bar.end_color and view.technique_bar.start_color!=view.technique_bar.end_color,"yellow and blue gradients")
	for key in ["background","illustration"]:
		check(load(session.event.stage_two[key]).get_image().has_mipmaps(),"stage two mipmap "+key)
	if render:
		await shot(view,"empty")
		_check_text_bounds(view)
		_check_refreshed_layout(view)
		map._open_cultivation_techniques()
	else:
		await click(view.technique_slot)
	check(view.technique_choice.visible and view.technique_choice.heading.text=="功法选择","plus opens technique picker")
	check(view.technique_choice.empty_label.visible and view.technique_choice.empty_label.text=="当前没有功法可选","explicit empty state")
	check(view.technique_choice.confirm_button.disabled and not view.technique_choice.cancel_button.disabled,"empty cannot confirm, cancel available")
	check(view.technique_choice.grid.columns==5,"same five-column picker layout")
	if render:
		await shot(view,"picker")
		view.technique_choice.close()
		# Fixture data exists only in this isolated preview, never in game content.
		session.sync_calendar(session.last_calendar_day+6)
		session.set_cultivation_progress(50,100,"当前修为 50 / 100")
		session.set_available_techniques([_fixture_technique(map)])
		session.choose_technique("test.technique.preview")
		await shot(view,"progress-fixture")
		_check_gradient_pixels(view)
		check(view.day_label.text=="6/15天" and is_equal_approx(view.day_bar.ratio,0.4),"day ratio")
		check(view.cultivation_percent.text=="50%" and view.technique_percent.text=="42%","supplied progress interfaces drive percent labels")
		map._close_cultivation()
	else:
		await dismiss(KEY_ESCAPE)
		check(not view.technique_choice.visible and view.visible and map.event_state.phase=="cultivation","Escape closes picker only")
		await click(view.technique_slot)
		await click(view.technique_choice.cancel_button)
		check(not view.technique_choice.visible and session.suspensions.is_empty(),"cancel closes picker without selection")
		await click(view.pause_button)
		check(session.paused and view.pause_caption.text=="继续修炼","pause button toggles session state")
		await click(view.pause_button)
		check(not session.paused and view.pause_caption.text=="暂停修炼","resume button toggles back")
		await click(view.board_button)
		check(map.is_inventory_open() and not view.visible and session.suspensions.has("inventory"),"board adjustment opens real inventory and suspends session")
		await dismiss(KEY_ESCAPE)
		check(not map.is_inventory_open() and view.visible and map.travel.paused and session.suspensions.is_empty(),"closing inventory returns to cultivation, not map")
		session.set_available_techniques([_fixture_technique(map)])
		await click(view.technique_slot)
		check(view.technique_choice.cards.size()==1,"future supplied technique produces standard item card")
		await click(view.technique_choice.cards[0])
		check(not view.technique_choice.confirm_button.disabled,"selecting supplied technique enables confirm")
		await click(view.technique_choice.confirm_button)
		check(session.selected_technique_id=="test.technique.preview" and view.technique_percent.text=="42%" and not view.technique_slot_plus.visible,"chosen technique binds name, image and progress")
		await click(view.end_button)
		check(not view.visible and not session.active and not map.event_state.is_active() and not map.travel.paused,"end returns to map")
		check(map._try_start_event(CULTIVATION_POINT,"click",true),"site can be reopened")
		map._request_cultivation("cultivation",5)
		check(map.cultivation_session.mode_id=="cultivation" and map.cultivation_session.selected_technique_id.is_empty(),"new session resets selection, not world state")
		var before_day:=WorldCalendar.current_day(map.loadout.calendar)
		var error: String=map.loadout.advance_days(5,"test.cultivation.calendar")
		map.loadout.changed.emit()
		check(error.is_empty() and map.cultivation_session.elapsed_days==5 and view.day_label.text=="5/5天","real calendar signal supplies elapsed game days")
		check(WorldCalendar.current_day(map.loadout.calendar)==before_day+5 and view.pause_button.disabled,"elapsed days capped at chosen duration")
		map._close_cultivation()
		map.loadout.restore(before)
		_check_session(session.event)
		_check_registry(session.event)
	check(map.loadout.snapshot()==before and map.player_status.resources==resources,"UI does not spend days or resources or award unplanned cultivation")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	print("CULTIVATION PHASE TWO: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _fixture_technique(map: Node) -> Dictionary:
	var record: Dictionary=map.loadout.records.values()[0].duplicate(true)
	record.id="test.technique.preview"
	record.name="测试功法"
	record.icon="res://assets/UI-xiulian-zzgf2.webp"
	record.quantity=1
	record.progress_current=42
	record.progress_target=100
	return record

func _check_session(event: Dictionary) -> void:
	var session:=MapCultivationSession.new()
	check(not session.begin(event,"invalid",10,0),"invalid mode rejected")
	check(session.begin(event,"balanced",15,100),"session starts on current calendar day")
	var first:=session.status("cultivation")
	session.sync_calendar(104)
	check(session.elapsed_days==4 and session.status("cultivation")==first,"status unchanged before five game days")
	session.sync_calendar(105)
	check(session.elapsed_days==5 and session.status("cultivation")!=first,"status changes at five game days")
	session.sync_calendar(105)
	check(session.elapsed_days==5,"same-day refresh cannot double count")
	session.set_paused(true,105)
	session.sync_calendar(108)
	check(session.elapsed_days==5,"paused days not counted")
	session.set_paused(false,108)
	session.sync_calendar(110)
	check(session.elapsed_days==7,"resume excludes pause gap")
	session.suspend("inventory",true,110)
	session.sync_calendar(111)
	session.suspend("inventory",false,111)
	check(session.elapsed_days==7,"inventory days excluded")
	session.sync_calendar(109)
	session.sync_calendar(111)
	check(session.elapsed_days==7,"calendar rewind cannot double count")
	session.set_cultivation_progress(50,100,"50/100")
	check(is_equal_approx(session.cultivation_progress.ratio,0.5),"cultivation numerator/target ratio")
	session.set_cultivation_progress(1,0,"")
	check(session.cultivation_progress.is_empty(),"unknown/zero target safely empty")
	session.set_available_techniques([{"id":"test.technique","name":"测试","progress_current":20,"progress_target":80}])
	check(not session.choose_technique("missing") and session.choose_technique("test.technique"),"selection validated against supplied list")
	check(is_equal_approx(session.technique_progress().ratio,0.25),"technique ratio from selected record")
	var technique_status:=session.status("technique")
	session.sync_calendar(115)
	check(session.status("technique")!=technique_status,"technique status rotates separately at next five-day boundary")
	session.sync_calendar(130)
	check(session.elapsed_days==15,"elapsed clamped to selected days")
	session.finish(130)
	session.sync_calendar(150)
	check(session.elapsed_days==15 and not session.active,"ended session no longer accumulates")
	session.begin(event,"technique",10,150)
	check(session.status("cultivation").contains("未安排") and session.status("technique").contains("尚未选择"),"mode and missing-technique copy truthful")

func _check_registry(event: Dictionary) -> void:
	for key in ["background","illustration","description","status_interval_days","cultivation_statuses","technique_statuses"]:
		var invalid:=event.duplicate(true)
		invalid.stage_two.erase(key)
		check(not MapEventRegistry.new().configure([invalid],[CULTIVATION_POINT]).is_empty(),"reject stage two missing "+key)

func dismiss(key: Key) -> void:
	for pressed in [true,false]:
		var input:=InputEventKey.new()
		input.keycode=key
		input.pressed=pressed
		root.push_input(input,true)
	await settle()

func shot(view: MapCultivationProgressDialog, label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.save_png("res://artifacts/cultivation-phase2-"+label+".png")
	image.get_region(Rect2i(view.canvas.get_global_rect())).save_png("res://artifacts/cultivation-phase2-"+label+"-panel.png")

func _check_text_bounds(view: MapCultivationProgressDialog) -> void:
	for label: Label in [view.description,view.location_label,view.mode_label,view.duration_label,view.day_label,view.cultivation_percent,view.technique_caption,view.technique_status,view.board_caption,view.pause_caption,view.end_caption]:
		var width:=label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		check(width<=label.size.x+1,"text fits designated container: "+label.text)
	check(view.technique_slot.get_global_rect().get_center().distance_to(view.illustration.get_global_rect().get_center())<12,"technique slot centered on scene tai chi")

func _check_refreshed_layout(view: MapCultivationProgressDialog) -> void:
	check(view.info_frames.size()==3,"three independent info outlines restored after art refresh")
	var expected_frames: Array[Rect2]=[Rect2(863,306,175,61),Rect2(1047,306,175,61),Rect2(1231,306,176,61)]
	var labels: Array[Label]=[view.location_label,view.mode_label,view.duration_label]
	for index in 3:
		var panel: Panel=view.info_frames[index]
		check(panel.get_meta("source_rect")==expected_frames[index],"saved inner-frame geometry follows 13px shift "+str(index))
		check(panel.get_theme_stylebox("panel").get_border_width(SIDE_LEFT)==1,"one-pixel info outline "+str(index))
		check(labels[index].get_meta("source_rect").position.y==311,"info text follows frame "+str(index))
	var buttons: Array[Button]=[view.board_button,view.pause_button,view.end_button]
	var captions: Array[Label]=[view.board_caption,view.pause_caption,view.end_caption]
	for index in 3:
		var button_rect: Rect2=buttons[index].get_meta("source_rect")
		var caption_rect: Rect2=captions[index].get_meta("source_rect")
		check(is_equal_approx(caption_rect.get_center().x-button_rect.get_center().x,11),"main caption moves six pixels right from previous five-pixel offset "+str(index))
		check(caption_rect.position.y==708,"main captions share icon-aligned row "+str(index))

func _check_gradient_pixels(view: MapCultivationProgressDialog) -> void:
	var image:=root.get_texture().get_image()
	for bar: CultivationProgressBar in [view.day_bar,view.cultivation_bar,view.technique_bar]:
		var filled_width: float=(bar.size.x-6)*bar.ratio
		var origin:=bar.global_position+Vector2(3,bar.size.y*0.5)
		var left:=image.get_pixelv(Vector2i(origin+Vector2(filled_width*0.1,0)))
		var right:=image.get_pixelv(Vector2i(origin+Vector2(filled_width*0.9,0)))
		check(right.get_luminance()>left.get_luminance()+0.05,"rendered progress gradient dark to light")
