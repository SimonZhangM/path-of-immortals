extends "res://tests/cultivation_combat_tests.gd"
const Format=preload("res://scripts/presentation/battle_replay_format.gd")
func settle()->void:
	for i in 8:await process_frame

func mouse_move(point:Vector2)->void:
	var motion:=InputEventMouseMotion.new()
	motion.position=point;motion.global_position=point
	Input.parse_input_event(motion)
	await create_timer(.55).timeout
	await settle()

func mouse_button(point:Vector2,which:MouseButton)->void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point;event.global_position=point
		event.button_index=which;event.pressed=down
		Input.parse_input_event(event)
	await settle()

func run()->void:
	create_timer(45).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1920,1080)
	var scene=load("res://scenes/main/main.tscn").instantiate()
	var game:GameManager=scene.get_node("GameManager")
	game.battle_seed_override=BattleSimulation.DEFAULT_RANDOM_SEED
	game.use_saved_loadout=false;game.loadout_save_path="";game.enemy_id="base.enemy.qingfenglingtang"
	root.add_child(scene);game.set_process(false)
	check(game.startup_error.is_empty(),"scene startup")
	registry=game.registry
	check(MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).error.is_empty(),"catalog")
	var p:=actor("test.replay.player")
	p.definition.cultivation_rank="base.cultivation.spirit_transformation";p.cultivation_rank_id="base.cultivation.spirit_transformation"
	p.board=registry.get_board("base.board.qinglan_1")
	p.inventory=InventoryState.new(registry,p.board.grid_size)
	check(p.inventory.add_item("blade","base.map_item.t01_0033",Vector2i.ZERO),"blade")
	check(p.inventory.add_item("blade2","base.map_item.t01_0033",Vector2i(2,0)),"same definition distinct instance")
	check(p.inventory.add_item("heal","base.map_item.t01_0083",Vector2i(2,2)),"healer")
	var e:=PartyMemberState.new(registry.get_enemy(game.enemy_id),registry)
	e.definition.max_hp=10000;e.reset_resources();e.equip_definition_loadout()
	game.party.assign([p]);game.enemies.assign([e]);game.companions.clear();game.restart()
	p.hp-=50
	var ui=scene.get_node("MainUI")
	await settle()
	game.start_battle();game._process(12)
	game.simulation._finish("victory",game.simulation.state.time_usec)
	game._process(0);ui._show_victory_rewards();ui._review_victory();await settle()
	if OS.get_environment("REPLAY_VISUAL_ONLY")=="1":
		await render_visual(scene,ui)
		return
	check(ui.replay_active and ui.victory_view==ui.VictoryView.REVIEW,"victory enters board replay")
	check(ui._replay_controls.visible and ui._replay_controls.get_child_count()==5,"five filters")
	var board:InventoryView=ui.ally_panel.bags[0]
	var enemy_board:InventoryView=ui.enemy_panel.bags[0]
	check(board.replay_mode and enemy_board.replay_mode,"both sides replay")
	check(not board.show_cooldown_badges and not enemy_board.show_cooldown_badges,"CD badges replaced")
	for id in range(1,14):
		var texture:Texture2D=load("res://assets/UI-battle-icon-%02d.webp"%id)
		if DisplayServer.get_name()!="headless":check(texture.get_image().has_mipmaps(),"replay icon mipmaps "+str(id))
	var first_key:=board._tooltip_key_at(board.cell_center(Vector2i.ZERO))
	var first=board.build_item_tooltip(first_key)
	check(first!=null and first.has_meta("replay"),"original tooltip replaced")
	first.free()
	var other_key:=board._tooltip_key_at(board.cell_center(Vector2i(2,0)))
	check(first_key!=other_key,"same name hover does not reuse stats")
	ui._replay_buttons.damage.pressed.emit();await settle()
	check(board.replay_filter=="damage" and enemy_board.replay_filter=="damage","filter applies both sides")
	ui._replay_buttons.all.pressed.emit()
	var host:=ItemTooltipHost.for_control(board)
	if DisplayServer.get_name()=="headless":
		root.size=Vector2i(2560,1440)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size=Vector2i.ZERO
		await settle()
		var point:=board.get_global_transform_with_canvas()*board.cell_center(Vector2i.ZERO)
		await mouse_move(point)
		check(is_instance_valid(host.tooltip) and host.source_key==first_key,"real hover first instance")
		if is_instance_valid(host.tooltip):
			host.tooltip.scroll.custom_minimum_size.y=120
			host.tooltip.reset_size();await settle()
			await mouse_button(point,MOUSE_BUTTON_WHEEL_DOWN)
			check(host.tooltip.scroll.scroll_vertical>0,"wheel from item scrolls details")
		await mouse_move(board.get_global_transform_with_canvas()*board.cell_center(Vector2i(2,0)))
		check(is_instance_valid(host.tooltip) and host.source_key==other_key,"real hover switches identical instances")
		await mouse_move(Vector2(30,30))
		check(not is_instance_valid(host.tooltip),"leaving item removes stats")
		var filter_point:Vector2=ui._replay_buttons.damage.get_global_transform_with_canvas()*(ui._replay_buttons.damage.size*.5)
		await mouse_move(filter_point);await mouse_button(filter_point,MOUSE_BUTTON_LEFT)
		check(board.replay_filter=="damage","real filter click")
		ui._replay_buttons.all.pressed.emit()
	# Static screenshots use a fixed hover anchor without moving the desktop cursor.
	host.set_process(false)
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1366,768)]:
		root.size=resolution;await settle()
		check(root.get_visible_rect().encloses(ui._replay_controls.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,ui._replay_controls.size)),"filters on-screen "+str(resolution))
		var key:=board._tooltip_key_at(board.cell_center(Vector2i.ZERO))
		host._pointer=board.get_global_transform_with_canvas()*board.cell_center(Vector2i.ZERO)
		host._show(board,key);await settle()
		check(host.tooltip!=null and host.tooltip.has_meta("replay"),"single host stats tooltip")
		if host.tooltip!=null:
			check(root.get_visible_rect().encloses(host.tooltip.get_global_rect()),"tooltip contained "+str(resolution)+" "+str(host.tooltip.get_global_rect()))
			host.tooltip.call("scroll_by",48)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/replay-20261112/ui-%d.png"%resolution.y)
		host.dismiss(false)
		await settle()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/replay-20261112/xiaolan-%d.png"%resolution.y)
	ui._open_battle_record();await settle()
	check(ui._log_panel.visible,"record still available in replay")
	ui._log_panel.hide();ui._show_victory_rewards();await settle()
	check(not ui.replay_active and not board.replay_mode,"leave replay restores normal mode")
	var normal_key:=board._tooltip_key_at(board.cell_center(Vector2i.ZERO))
	var normal=board.build_item_tooltip(normal_key)
	check(normal!=null and not normal.has_meta("replay"),"ordinary tooltip restored")
	normal.free()
	game.restart();game.start_battle();game.simulation._finish("defeat",0);game._process(0);ui._review_victory();await settle()
	check(ui.replay_active and not ui._retreat_dialog.visible,"defeat opens unblocked board replay")
	var exit_probe:Dictionary={"called":false}
	ui.battle_exit_handler=func()->String:exit_probe.called=true;return ""
	ui._toggle_battle();await create_timer(.1).timeout
	check(exit_probe.called,"defeat replay leaves through existing map exit handler")
	game.restart();await settle()
	check(not ui.replay_active and not game.simulation.replay.frozen,"new battle reset")
	scene.queue_free();await settle()
	print("REPLAY_UI: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func render_visual(scene:Node,ui:Control)->void:
	# Render-only path: no mouse, callbacks, outcome-flow or gameplay assertions.
	var host:=ItemTooltipHost.for_control(ui)
	host.dismiss(false);host.set_process(false)
	await create_timer(1.2).timeout
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size=resolution;await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/replay-20261112/xiaolan-veil-%d.png"%resolution.y)
		if OS.get_environment("REPLAY_CENTER_VISUAL")=="1":
			var middle_x:=root.get_visible_rect().size.x*0.5
			var emblem_x:float=(ui._battle_emblem.get_global_transform_with_canvas()*(ui._battle_emblem.size*0.5)).x
			var filter_x:float=(ui._replay_controls.get_global_transform_with_canvas()*(Vector2(1086,242)*0.21)).x
			var exit_x:float=(ui._battle_button.get_global_transform_with_canvas()*(ui._battle_button.size*0.5)).x
			check(absf(emblem_x-middle_x)<1 and absf(filter_x-middle_x)<1 and absf(exit_x-middle_x)<1,"three artwork axes centered "+str(resolution))
			print("REPLAY_CENTER: viewport=",root.get_visible_rect().size," center=",middle_x," emblem=",emblem_x," filter=",filter_x," exit=",exit_x)
		if OS.get_environment("REPLAY_FILTER_VISUAL")=="1":
			for key:String in ui._replay_buttons:
				var button:Button=ui._replay_buttons[key]
				var point:Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
				var motion:=InputEventMouseMotion.new()
				motion.position=point;motion.global_position=point
				root.push_input(motion,true);await settle()
				# Coordinates above are viewport-local, independent of window stretch.
				for down in [true,false]:
					var click:=InputEventMouseButton.new()
					click.position=point;click.global_position=point
					click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
					root.push_input(click,true)
				await settle()
				check(ui.replay_filter==key and ui._replay_controls.selected_key==key,"filter click updates selection "+key)
				for panel in [ui.ally_panel,ui.enemy_panel]:
					for board:InventoryView in panel.bags:check(board.replay_filter==key,"both boards filter "+key)
				for id:String in ui._replay_buttons:
					check(ui._replay_buttons[id].button_pressed==(id==key),"single selected filter "+id)
				var caption:Label=button.get_node("Caption")
				check(caption.position.is_zero_approx() and caption.size.is_equal_approx(button.size),"caption centered in button "+key)
				if resolution.y==1440 or key=="all":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/replay-20261112/filters-%s-%d.png"%[key,resolution.y])
			ui._replay_buttons.all.pressed.emit();await settle()
		if OS.get_environment("REPLAY_TOOLTIP_VISUAL")=="1":
			var board:InventoryView=ui.ally_panel.bags[0]
			var enemy_board:InventoryView=ui.enemy_panel.bags[0]
			for sample in [{"name":"heal","board":board,"cell":Vector2i(2,2)},{"name":"attack","board":board,"cell":Vector2i.ZERO},{"name":"enemy","board":enemy_board,"cell":Vector2i.ZERO}]:
				var target:InventoryView=sample.board
				var key:=target._tooltip_key_at(target.cell_center(sample.cell))
				host._pointer=target.get_global_transform_with_canvas()*target.cell_center(sample.cell)
				host._show(target,key);await settle()
				check(host.tooltip.find_child("ItemPortrait",true,false)!=null,"shared portrait "+sample.name)
				check(host.tooltip.find_child("BattleStatistics",true,false)!=null,"statistics in effect section "+sample.name)
				check(root.get_visible_rect().encloses(host.tooltip.get_global_rect()),"tooltip fits "+sample.name+str(resolution))
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/replay-20261112/tooltip-card-%s-%d.png"%[sample.name,resolution.y])
				host.dismiss(false);await settle()
	# Same frozen scene without the replay art, for frame/mask-only comparison.
	root.size=Vector2i(2560,1440);await settle()
	ui._set_replay(false);await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/replay-20261112/xiaolan-no-veil-1440.png")
	scene.queue_free();await settle()
	if OS.get_environment("REPLAY_FILTER_VISUAL")=="1":
		print("REPLAY_FILTER_VISUAL: five filter clicks at 2 sizes; %d checks, %d failures"%[checks,failures.size()])
	else: print("REPLAY_VISUAL: rendered 2 sizes and unmasked reference; no mouse checks")
	quit(0 if failures.is_empty() else 1)
