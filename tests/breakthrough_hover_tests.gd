extends "res://tests/breakthrough_audio_tests.gd"
## Headless virtual input only; rendered runs inspect static layout without cursor input.

func motion(point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position=point; event.global_position=point
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)

func button(point: Vector2, which: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.global_position=point
	event.button_index=which; event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and which==MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)

func hover(point: Vector2) -> void:
	motion(point)
	await create_timer(0.7).timeout
	await settle()

func item_center(board: Control, id: String) -> Vector2:
	var entry := state.inventory.get_instance(id)
	var item := state.registry.get_item(entry.item_id)
	return board.get_global_transform_with_canvas()*board.layout.footprint_rect(entry.cell,item.grid_size,board.size).get_center()

func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	if not await prepare_audio_fixture("res://artifacts/breakthrough-hover-20261105"): quit(1); return
	var screen: Control=map.breakthrough_screen
	var board: Control=screen.board_view
	var host := ItemTooltipHost.for_control(board)
	var flow: RefCounted=map.breakthrough_session
	var render := DisplayServer.get_name()!="headless"
	if not render:
		for phase in ["ready","running","paused"]:
			if phase=="running": check(flow.start(),"start isolated attempt")
			if phase=="paused": flow.set_paused(true)
			var before := state.snapshot()
			for id in ["test.first_qi.guide","test.audio.restore"]:
				host.dismiss(false)
				await hover(Vector2(30,1000))
				await hover(item_center(board,id))
				check(is_instance_valid(host.tooltip) and host.source==board and host.source_key==id,phase+" hover opens correct item")
				if is_instance_valid(host.tooltip):
					var expected: ItemTooltip=board.build_item_tooltip(id)
					check(not host.tooltip.description.is_empty() and host.tooltip.description==expected.description,phase+" shows shared actual effects")
					expected.free()
			await hover(Vector2(30,1000))
			check(not is_instance_valid(host.tooltip),phase+" leaving dismisses tooltip")
			check(state.snapshot()==before,phase+" hover preserves gameplay")
		var before := state.snapshot()
		var point := item_center(board,"test.first_qi.guide")
		button(point,MOUSE_BUTTON_RIGHT,true); button(point,MOUSE_BUTTON_RIGHT,false)
		motion(point); button(point,MOUSE_BUTTON_LEFT,true)
		motion(point+Vector2(90,35),true)
		await settle()
		check(not root.gui_is_dragging(),"breakthrough hover does not enable dragging")
		button(point+Vector2(90,35),MOUSE_BUTTON_LEFT,false)
		check(state.snapshot()==before and screen.visible,"clicks neither unequip items nor close breakthrough")
		await hover(Vector2(30,1000))
		await hover(item_center(board,"test.audio.restore"))
		map.set_breakthrough_open(false)
		await settle()
		check(not is_instance_valid(host.tooltip),"hidden breakthrough clears tooltip")
		map.set_breakthrough_open(true)
		await settle()
	else:
		check(flow.start(),"prepare static running preview")
		flow.set_paused(true)
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size=resolution
		await settle()
		for value in [0,600,9990,10000]:
			state.growth.breakthrough_attempt.progress=value
			screen.refresh()
			await settle()
			var separator: Label=screen.progress_separator
			var center: float=separator.position.x+separator.size.x*0.5+screen.progress_value.position.x
			check(absf(center-2223.5)<=0.6,"slash stays on divider glow at %s/%d" % [resolution,value])
			check(screen.progress_required.text=="100","required cultivation is an integer")
			check(screen.progress_required.get_theme_color("font_color")==Color("e8c76d"),"required cultivation is gold")
			var label: Label=screen.progress_current
			check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"current value fits")
		if render:
			state.growth.breakthrough_attempt.progress=600
			screen.refresh()
			host.set_process(false)
			host._show(board,"test.audio.restore")
			await capture("hover-%d" % resolution.x)
			host.dismiss(false)
	map.queue_free()
	await settle()
	await create_timer(0.3).timeout
	print("Breakthrough hover/readout: %d checks, %d failures; %s" % [checks,failures,directory])
	quit(1 if failures else 0)
