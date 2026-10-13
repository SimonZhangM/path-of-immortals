extends "res://tests/item_selection_tooltip_tests.gd"

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map ready")
	var before: Dictionary = map.loadout.snapshot()
	var ui: MapInventoryScreen = map.inventory_screen
	ui.set_warehouse("base.warehouse.qingshizhen.home")
	ui.show()
	map.status_header.map_title.hide()
	await settle()
	var actions: Control = ui.warehouse_actions
	var calendar: Control = map.calendar_readout
	for control: Control in [actions.left_group,actions.right_group]:
		var panel: Control = ui.warehouse_pane.storage_panel if control==actions.left_group else ui.storage_panel
		check(is_equal_approx(panel.get_global_rect().position.y-control.get_global_rect().end.y,8*ui.stage.scale.y),"buttons down three design px; eight px gap remains")
	for action: TextureButton in [actions.withdraw_button,actions.withdraw_all_button,actions.deposit_button,actions.deposit_all_button]:
		check(action.get_theme_stylebox("panel","TooltipPanel")==calendar.get_theme_stylebox("panel","TooltipPanel"),"same dark panel as calendar")
		check(action.get_theme_font("font","TooltipLabel")==calendar.get_theme_font("font","TooltipLabel"),"same tooltip font as calendar")
		check(action.get_theme_font_size("font_size","TooltipLabel")==calendar.get_theme_font_size("font_size","TooltipLabel"),"same compact font size")
		check(action.get_theme_color("font_color","TooltipLabel")==calendar.get_theme_color("font_color","TooltipLabel"),"same tooltip text color")
		check(not action.tooltip_text.is_empty() and action.pressed.get_connections().size()>0,"caption and existing command retained")
	check(ui.get_theme_stylebox("panel","TooltipPanel") is StyleBoxEmpty,"item tooltip host unchanged")
	# Static fixture of the native TooltipPanel/TooltipLabel; no pointer or timer interaction.
	var source: TextureButton = actions.deposit_all_button
	var tip := PanelContainer.new()
	tip.theme = source.theme
	tip.theme_type_variation = "TooltipPanel"
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.z_index = 100
	var label := Label.new()
	label.theme_type_variation = "TooltipLabel"
	label.text = source.tooltip_text
	tip.add_child(label)
	root.add_child(tip)
	await settle()
	tip.position = source.get_global_rect().end + Vector2(-tip.size.x,8)
	check(map.loadout.snapshot()==before,"inventory unchanged")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-simple-tooltip.png")
	tip.queue_free()
	map.queue_free()
	await settle()
	print("WAREHOUSE SIMPLE TOOLTIP: %d checks, %d failures; static only" % [checks,failures])
	quit(1 if failures else 0)
