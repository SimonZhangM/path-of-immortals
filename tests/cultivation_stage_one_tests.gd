extends "res://tests/map_shop_tests.gd"

const POINT_ID := "base.map.qingshihewan.point.n32"
const EVENT_ID := "base.map_event.qingshihewan.cultivation_n32"

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
	check(map.startup_error.is_empty(),"river startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	var event: Dictionary=map.event_registry.events[EVENT_ID]
	check(event.point_id==POINT_ID and map.content.get_node("Points/N32").location_note=="瀑下静台","correct waterfall node")
	map.travel.current_node_id=POINT_ID
	map.travel.map_position=map.travel.node_positions[POINT_ID]
	map.travel.stop_at_current_node()
	map.travel.node_arrived.emit(POINT_ID)
	await settle()
	var dialog: MapCultivationDialog=map.cultivation_dialog
	check(dialog.visible and map.event_state.phase=="cultivation" and map.travel.paused,"arrival opens phase one")
	var before: Dictionary=map.loadout.snapshot()
	var resources: Dictionary=map.player_status.resources.duplicate(true)
	check(dialog.selected_mode=="cultivation" and dialog.selected_days==10,"reference defaults")
	check(map.event_state.advance().is_empty() and not map.event_state.completed.has(EVENT_ID),"not treated as story completion")
	check(dialog.description.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT and dialog.description.get_meta("source_rect")==Rect2(850,200,562,70),"description below title rule and left aligned")
	for button: Button in dialog.mode_buttons+dialog.duration_buttons:
		_check_border(button)
	for label: Label in [dialog.mode_heading,dialog.duration_heading]:
		var font: SystemFont=label.get_theme_font("font")
		check(font.font_names[0]=="HarmonyOS Sans SC" and font.font_weight==400,"Harmony regular section heading")
	check(dialog.start_button.get_meta("source_rect")==Rect2(984,700,300,96),"CTA center on new cloud rule y748")
	check(dialog.start_button.get_meta("source_rect")==dialog.start_label.get_meta("source_rect"),"CTA text follows button center")
	for key in ["background","illustration"]:
		check(load(event.presentation[key]).get_image().has_mipmaps(),"mipmap "+key)
	var render:=DisplayServer.get_name()!="headless"
	if render: await shot(dialog,"default")
	for index in 3:
		if render:
			dialog.select_mode(event.modes[index].id)
			dialog.select_days(event.durations[index])
		else:
			await click(dialog.mode_buttons[index])
			await click(dialog.duration_buttons[index])
		check(dialog.selected_mode==event.modes[index].id and dialog.selected_days==event.durations[index],"single selection "+str(index))
		for j in 3:
			var expected: String=event.modes[j].selected_image if j==index else event.modes[j].image
			check(dialog.mode_images[j].texture.atlas.resource_path==expected,"selected/idle image "+str(j))
			check(dialog.mode_images[j].texture.atlas.get_image().has_mipmaps(),"mode mipmap")
			check(dialog.mode_buttons[j].get_theme_stylebox("normal").border_color==(dialog.GOLD if j==index else dialog.BLUE),"solid state border")
			_check_border(dialog.mode_buttons[j])
			_check_border(dialog.duration_buttons[j])
			_check_icon(dialog,j)
		if render and index==1: await shot(dialog,"technique")
	if render:
		await shot(dialog,"balanced")
		_check_pair_alignment(dialog,event)
		dialog._start_hover(true)
		check(dialog.start_label.get_theme_color("font_color")==Color.BLACK,"hover black text")
		dialog._start_hover(false)
		check(dialog.start_label.get_theme_color("font_color")==Color.WHITE,"idle white text")
		map._close_cultivation()
	else:
		var motion:=InputEventMouseMotion.new()
		motion.position=dialog.start_button.get_global_rect().get_center()
		motion.global_position=motion.position
		root.push_input(motion,true)
		await settle()
		check(dialog.start_label.get_theme_color("font_color")==Color.BLACK,"actual CTA hover text")
		await click(dialog.start_button)
		check(not dialog.visible and map.cultivation_progress_dialog.visible,"CTA enters phase two")
		check(map.loadout.snapshot()==before and map.player_status.resources==resources,"no time, currency, resources or rewards changed")
		map._close_cultivation()
		check(map._try_start_event(POINT_ID,"click",true),"reopen phase one after phase two ends")
		await settle()
		# The baked arrow belongs to the same leave target, not just the text.
		for pressed in [true,false]:
			var input:=InputEventMouseButton.new()
			input.position=dialog.leave_button.get_global_rect().end-Vector2(12,20)
			input.button_index=MOUSE_BUTTON_LEFT
			input.pressed=pressed
			root.push_input(input,true)
		await settle()
		check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"leave resumes map")
		for method in ["right","escape"]:
			check(map._try_start_event(POINT_ID,"click",true),"repeat opening at node")
			await settle()
			if method=="right":
				var input:=InputEventMouseButton.new()
				input.button_index=MOUSE_BUTTON_RIGHT
				input.pressed=true
				root.push_input(input,true)
			else:
				var input:=InputEventKey.new()
				input.keycode=KEY_ESCAPE
				input.pressed=true
				root.push_input(input,true)
			await settle()
			check(not dialog.visible and not map.travel.paused,"dismiss "+method)
		var registry:=MapEventRegistry.new()
		for key in ["default_mode","default_days","durations","modes"]:
			var bad:=event.duplicate(true)
			bad.erase(key)
			check(not registry.configure([bad],[POINT_ID]).is_empty(),"reject missing "+key)
	check(not map.event_state.completed.has(EVENT_ID),"site stays reusable")
	check(map.loadout.snapshot()==before and map.player_status.resources==resources,"selection and closing have no gameplay mutation")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	print("CULTIVATION PHASE ONE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func shot(dialog: MapCultivationDialog, label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.save_png("res://artifacts/cultivation-phase1-"+label+".png")
	image.get_region(Rect2i(dialog.canvas.get_global_rect())).save_png("res://artifacts/cultivation-phase1-"+label+"-panel.png")

func _check_border(button: Button) -> void:
	var one_pixel:=true
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style: StyleBoxFlat=button.get_theme_stylebox(state)
		one_pixel=one_pixel and style.border_width_left==1 and style.border_width_right==1 and style.border_width_top==1 and style.border_width_bottom==1
	check(one_pixel,"one pixel border in all visual states")

func _check_icon(dialog: MapCultivationDialog, index: int) -> void:
	var art: TextureRect=dialog.mode_images[index]
	var atlas: AtlasTexture=art.texture
	var bounds:=Rect2(dialog.METRICS.inspect(atlas.atlas).visible_rect)
	var rect: Rect2=art.get_meta("source_rect")
	var factor:=rect.size.y/atlas.region.size.y
	var visible_rect:=Rect2(rect.position+(bounds.position-atlas.region.position)*factor,bounds.size*factor)
	var card: Rect2=dialog.mode_buttons[index].get_meta("source_rect")
	var expected_height:=79.8 if index==1 else 84.0
	var expected_y:=379.0
	if index==0: expected_y-=1.0
	elif index==1: expected_y+=1.0
	check(is_equal_approx(visible_rect.size.y,expected_height),"requested visible icon height "+str(index))
	check(visible_rect.get_center().is_equal_approx(Vector2(card.get_center().x,expected_y)),"requested visible icon center "+str(index))
	check(is_equal_approx(rect.size.x/atlas.region.size.x,factor) and visible_rect.size.x<card.size.x-8,"icon aspect preserved and fits card")

func _rendered_icon_bounds(art: TextureRect) -> Rect2:
	var atlas: AtlasTexture=art.texture
	var bounds:=Rect2(MapCultivationDialog.METRICS.inspect(atlas.atlas).visible_rect)
	var factor:=art.size/atlas.region.size
	return Rect2(art.position+(bounds.position-atlas.region.position)*factor,bounds.size*factor)

func _check_pair_alignment(dialog: MapCultivationDialog, event: Dictionary) -> void:
	var original_size:=dialog.size
	var original_mode:=dialog.selected_mode
	# Direct state/geometry checks only: no synthetic mouse or gameplay flow.
	for viewport_size in [Vector2(1920,1080),Vector2(2560,1440)]:
		dialog.size=viewport_size
		for index in 2:
			dialog.select_mode("balanced")
			var idle:=_rendered_icon_bounds(dialog.mode_images[index])
			dialog.select_mode(event.modes[index].id)
			var active:=_rendered_icon_bounds(dialog.mode_images[index])
			check(idle.get_center().distance_to(active.get_center())<0.001,"blue/gold rendered center locked "+str(index)+" "+str(viewport_size))
			check(absf(idle.size.y-active.size.y)<0.001,"blue/gold rendered height locked")
			check(dialog.mode_images[index].stretch_mode==TextureRect.STRETCH_SCALE,"no second integer aspect fitting")
			dialog.select_mode("balanced")
			check(_rendered_icon_bounds(dialog.mode_images[index]).is_equal_approx(idle),"repeat toggle returns identical art bounds")
		dialog._layout()
	dialog.size=original_size
	dialog.select_mode(original_mode)
