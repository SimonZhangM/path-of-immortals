extends "res://tests/clinic_dialog_tests.gd"

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
	check(map.startup_error.is_empty(),"clinic treatment starts: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	map.travel.current_node_id = CLINIC_POINT
	map.travel.map_position = map.travel.node_positions[CLINIC_POINT]
	map.travel.stop_at_current_node()
	map.player_status.set_resource("hp",35)
	map.player_status.set_resource("stamina",29)
	map.player_status.set_resource("spirit",23)
	map.loadout.spirit_stones = 5
	await open_clinic(map)
	var dialog: MapClinicDialog = map.clinic_dialog
	var view := dialog.treatment_content
	var config: Dictionary = map.event_registry.events[CLINIC_EVENT].treatment
	if DisplayServer.get_name()!="headless":
		dialog.set_mode("treatment")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/clinic-treatment.png")
		check(view.payment_notes.visible and not view.message.visible,"injured preview displays centered payment notes")
		map.player_status.set_resource("hp",55)
		await settle()
		check(view.message.visible and not view.payment_notes.visible and view.message.text=="气血已满，无需诊治。","full-hp message replaces payment notes")
		check(view.confirm_label.text=="无需诊治" and view.confirm_button.disabled,"full-hp button has no treatment action")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/clinic-treatment-full.png")
	else:
		await click(dialog.treatment_tab)
		check(dialog.backing.texture.atlas.resource_path.ends_with("yiguan-2.webp"),"treatment background selected")
		check(dialog.conversation_tab.position.x<dialog.treatment_tab.position.x,"conversation remains first")
		var preview := MapClinicTreatment.preview(map.loadout,map.player_status,config)
		check(preview.current==35 and preview.after==55 and preview.gain==20 and preview.fee==5,"actual hp/max and five-stone preview")
		check(view.fee_label.text=="5" and view.gain_label.text=="+20" and not view.confirm_button.disabled,"preview controls show real values")
		check(view.confirm_button.texture_normal.resource_path.ends_with("dakai1.webp") and view.confirm_button.texture_hover.resource_path.ends_with("dakai2.webp"),"both requested button textures")
		var move := InputEventMouseMotion.new()
		move.position = view.confirm_button.get_global_rect().get_center()
		root.push_input(move,true)
		await settle()
		check(view.confirm_label.get_theme_color("font_color")==Color.BLACK,"native hover switches to black text")
		move = InputEventMouseMotion.new()
		move.position = dialog.title_label.get_global_rect().get_center()
		root.push_input(move,true)
		await settle()
		check(view.confirm_label.get_theme_color("font_color")==Color.WHITE,"leaving hover restores white text")
		var original: Dictionary = map.loadout.snapshot()
		var resources: Dictionary = map.player_status.resources.duplicate(true)
		map.loadout.spirit_stones = 4
		view.refresh()
		check(view.confirm_button.disabled and not MapClinicTreatment.treat(map.loadout,map.player_status,config,"").error.is_empty(),"insufficient funds rejected")
		check(map.loadout.spirit_stones==4 and map.player_status.resources==resources,"insufficient funds preserve hp and currency")
		map.loadout.spirit_stones = 5
		var invalid_path := "res://artifacts/no-clinic-directory/save.json"
		check(not MapClinicTreatment.treat(map.loadout,map.player_status,config,invalid_path).error.is_empty(),"save failure rejected")
		check(map.loadout.snapshot()==original and map.player_status.resources==resources,"failed save neither heals nor charges")
		var path := "res://artifacts/clinic-treatment-%d.json" % Time.get_ticks_usec()
		map.inventory_save_path = path
		view.refresh()
		await click(view.confirm_button)
		check(map.player_status.resources.hp==55 and map.loadout.spirit_stones==0,"native confirm charges five and heals to max")
		check(map.player_status.resources.stamina==29 and map.player_status.resources.spirit==23,"only hp restored")
		var expected := original.duplicate(true)
		expected.spirit_stones = 0
		expected.narrative.flags["base.story.suqinghe.treatment_used"] = true
		expected.narrative.npcs["base.npc.suqinghe"].greeting.pending_treatment = true
		check(map.loadout.snapshot()==expected,"payment queues greeting without altering inventory calendar or formal dialogue")
		check(view.confirm_button.disabled and view.gain_label.text=="+0","full hp cannot pay again")
		check(view.confirm_label.text=="无需诊治" and view.message.text=="气血已满，无需诊治。" and not view.payment_notes.visible,"full hp replaces payment instructions and button caption")
		move = InputEventMouseMotion.new()
		move.position = view.confirm_button.get_global_rect().get_center()
		root.push_input(move,true)
		await settle()
		check(view.confirm_label.get_theme_color("font_color")==Color.WHITE and view.confirm_button.texture_disabled==view.confirm_button.texture_normal,"disabled hover keeps normal art and white caption")
		await click(view.confirm_button)
		check(map.loadout.spirit_stones==0 and map.player_status.resources.hp==55,"disabled button cannot charge again")
		map.player_status.set_resource("hp",54)
		map.loadout.spirit_stones = 5
		view.refresh()
		check(not view.confirm_button.disabled and view.confirm_label.text=="确认诊治" and view.payment_notes.visible and not view.message.visible,"injury restores normal treatment instructions and action")
		map.player_status.set_resource("hp",55)
		map.loadout.spirit_stones = 0
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(saved.spirit_stones==0,"deduction persisted")
		check(not MapClinicTreatment.treat(map.loadout,map.player_status,config,path).error.is_empty() and map.loadout.spirit_stones==0,"repeat full-hp request cannot charge twice")
		for key in ["consultation_hp_per_stone","supplies_fee","resource","recovery_percent","duration_days"]:
			var invalid := config.duplicate(true)
			invalid[key] = "spirit" if key=="resource" else -1
			check(not MapClinicTreatment.configuration_error(invalid).is_empty(),"invalid treatment configuration rejected: "+key)
		await click(dialog.conversation_tab)
		check(not view.visible and dialog.backing.texture.atlas.resource_path.ends_with("yiguan.webp"),"conversation keeps original art and hides treatment")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("CLINIC TREATMENT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
