extends "res://tests/clinic_dialog_tests.gd"

func fees(map: Node, config: Dictionary) -> void:
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.spirit_stones = 100
	var status := MapPlayerStatus.new()
	status.maxima = {"hp":100.0,"stamina":50.0,"spirit":50.0}
	status.resources = {"hp":100.0,"stamina":29.0,"spirit":23.0}
	var regular := config.duplicate(true)
	regular.waive_consultation = false
	for entry in [[0.0,0],[0.1,1],[1.0,1],[19.9,1],[20.0,1],[20.1,2],[40.0,2],[40.1,3],[100.0,5]]:
		status.set_resource("hp",100.0-entry[0])
		var cared := MapClinicTreatment.preview(state,status,config)
		var standard := MapClinicTreatment.preview(state,status,regular)
		check(cared.consultation_fee==entry[1] and cared.waived_fee==entry[1],"rounded consultation fee and full waiver at "+str(entry[0]))
		check(cared.supplies_fee==5 and cared.fee==5,"familiar care charges only supplies")
		check(standard.waived_fee==0 and standard.fee==5+entry[1],"other clinic has no inherited waiver")
		check(cared.error.is_empty()==(entry[0]>0),"full hp remains blocked")
	status.set_resource("hp",60)
	state.spirit_stones = 4
	var snapshot := state.snapshot()
	check(not MapClinicTreatment.treat(state,status,config,"").error.is_empty(),"not enough supplies fee rejected")
	check(state.snapshot()==snapshot and status.resources.hp==60,"insufficient funds no mutation")
	state.spirit_stones = 7
	snapshot = state.snapshot()
	check(not MapClinicTreatment.treat(state,status,regular,"res://artifacts/no-clinic-fee-directory/save.json").error.is_empty(),"save failure rejected")
	check(state.snapshot()==snapshot and status.resources.hp==60,"failure neither charges nor heals")
	var path := "res://artifacts/clinic-fees-%d.json" % Time.get_ticks_usec()
	check(MapClinicTreatment.treat(state,status,regular,path).error.is_empty(),"regular clinic can settle configured fee")
	check(state.spirit_stones==0 and status.resources.hp==100,"regular clinic charges two plus five and fully heals")
	check(status.resources.stamina==29 and status.resources.spirit==23,"other resources unchanged")
	check(state.snapshot().calendar==snapshot.calendar,"no time consumed")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).spirit_stones==0,"payment persisted")
	state.spirit_stones = 5
	status.set_resource("hp",0)
	check(MapClinicTreatment.treat(state,status,config,path).error.is_empty(),"familiar care at maximum loss settles")
	check(state.spirit_stones==0 and status.resources.hp==100,"familiar care still costs five")
	check(not MapClinicTreatment.treat(state,status,config,path).error.is_empty(),"full hp repeated payment rejected")
	for pair in [["consultation_hp_per_stone",0],["consultation_hp_per_stone",1.5],["supplies_fee",-1],["supplies_fee",0.5],["waive_consultation",1],["care_tooltip",""]]:
		var invalid := config.duplicate(true)
		invalid[pair[0]] = pair[1]
		check(not MapClinicTreatment.configuration_error(invalid).is_empty(),"invalid fee config rejected "+str(pair))

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"clinic starts")
	var config: Dictionary = map.event_registry.events[CLINIC_EVENT].treatment
	if DisplayServer.get_name()=="headless": fees(map,config)
	map.loadout.spirit_stones = 5
	map.player_status.set_resource("hp",14.9)
	var dialog: MapClinicDialog = map.clinic_dialog
	dialog.present(map.event_registry.events[CLINIC_EVENT],map.loadout,map.player_status)
	dialog.set_mode("treatment")
	await settle()
	var view: MapClinicTreatmentView = dialog.treatment_content
	check(view.fee_label.text=="5" and view.consultation_label.text=="[s]3[/s]" and view.consultation_due.text=="免收" and view.supplies_label.text=="5","fee breakdown uses real preview")
	check(view.care_badge.visible and view.care_label.text=="熟识照顾","care badge visible")
	check(view.care_badge.get_theme_stylebox("panel","TooltipPanel")==map.calendar_readout.get_theme_stylebox("panel","TooltipPanel"),"simple tooltip shares calendar panel")
	check(view.care_badge.tooltip_text==config.care_tooltip and view.care_label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"authored tooltip and label passthrough")
	var note_box: VBoxContainer = view.get_node("ClinicNoteContent")
	var note_bounds := (note_box.get_child(0) as Control).get_global_rect().merge(view.description.get_global_rect())
	check(absf(note_bounds.get_center().y-note_box.get_global_rect().get_center().y)<1 and view.description.get_theme_font_size("font_size")==19,"clinic heading and description centered vertically without font change")
	var expected_fonts := {"诊治费用":24,"问诊费":21,"药材及耗材":21,"实际支付":24}
	for child in view.get_children():
		if child is Label and expected_fonts.has(child.text):
			check(child.get_theme_font_size("font_size")==expected_fonts[child.text],"fee heading one point smaller: "+child.text)
			if child.text in ["问诊费","药材及耗材"]:
				check(child.get_theme_font("font").font_names[0]=="KaiTi","both cost names use KaiTi")
	check(view.care_label.get_theme_font_size("font_size")==19 and view.consultation_label.get_theme_font_size("normal_font_size")==21 and view.consultation_due.get_theme_font_size("font_size")==21 and view.supplies_label.get_theme_font_size("font_size")==23 and view.fee_label.get_theme_font_size("font_size")==26,"remaining fee text all one point smaller")
	var coin: TextureRect = view.get_node("TreatmentFeeCoin")
	check(coin.size.is_equal_approx(Vector2(22,29)*0.9) and (coin.get_rect().get_center()+view.ORIGIN).is_equal_approx(Vector2(942,765.5)),"coin ten percent smaller about same center")
	check(view.confirm_button.size.is_equal_approx(Vector2(300,92)*0.95) and (view.confirm_button.get_rect().get_center()+view.ORIGIN).is_equal_approx(Vector2(1230,761)),"button five percent smaller about same center")
	check(view.confirm_label.get_rect().is_equal_approx(view.confirm_button.get_rect()) and view.confirm_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and view.confirm_label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"button caption stays centered")
	check(is_equal_approx(view.motto.get_rect().get_center().x,view.confirm_button.get_rect().get_center().x) and view.motto.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"motto aligned with button center")
	check(view.message.position==Vector2(1136,468)-view.ORIGIN and view.message.size==Vector2(208,37),"condition placed under recovery")
	check(view.payment_notes.visible and not view.message.visible,"injured instructions retained")
	for label: Label in [view.care_label,view.consultation_due,view.supplies_label,view.fee_label]:
		check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"fee text fits narrow slot")
	check(view.care_badge.position.y+view.care_badge.size.y+view.ORIGIN.y<689,"badge clears first divider")
	var before: Dictionary = map.loadout.snapshot()
	if DisplayServer.get_name()=="headless":
		var motion := InputEventMouseMotion.new()
		motion.position = view.care_badge.get_global_rect().get_center()
		root.push_input(motion,true)
		await settle()
		check(root.gui_get_hovered_control()==view.care_badge,"pointer reaches simple-tooltip badge")
	else:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/clinic-fees-injured.png")
	map.player_status.set_resource("hp",55)
	await settle()
	check(view.message.text=="气血已满，无需诊治。" and view.message.visible and not view.payment_notes.visible and view.confirm_button.disabled,"full hp condition stays under recovery with payment disabled")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/clinic-fees-full.png")
	check(map.loadout.snapshot()==before,"preview doesn't charge or alter inventory")
	map.queue_free()
	await settle()
	print("CLINIC FEES/LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
