extends "res://tests/map_shop_tests.gd"

# Static layout preview only: no input injection, no real save reads/writes.
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
	var dialog: MapRestDialog=map.rest_dialog
	for suffix in ["n05","n13"]:
		var event: Dictionary=map.event_registry.events["base.map_event.qingshihewan.rest_"+suffix]
		dialog.present(event,true,map.loadout)
		await settle()
		check(dialog.warning.text=="状态不满也可以休息，\n但恢复不会超过各上限值。","explicit two-line warning "+suffix)
		check(dialog.warning.get_global_rect().end.x<=dialog.start_button.get_global_rect().position.x,"warning left / button right without overlap "+suffix)
		check(dialog.start_button.get_meta("source_rect")==Rect2(1142,699,270,91),"shared camp and shelter button position "+suffix)
		check(dialog.start_label.get_global_rect()==dialog.start_button.get_global_rect(),"button text follows button "+suffix)
		check(dialog.description.get_meta("source_rect")==Rect2(850,199,562,123) and dialog.description.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"description centered between rule and section title "+suffix)
		check(dialog.duration_caption.get_meta("source_rect").position.y==503,"duration caption down three on both pages "+suffix)
		check(dialog.food_button.visible and not dialog.later_arrow.visible,"meal slot and artwork arrow "+suffix)
		check(int(event.recovery_percent)==(30 if suffix=="n05" else 50) and event.duration_days==1,"original rest balance "+suffix)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/rest-food-layout-"+suffix+".png")
	# Confirm the common component returns to its original layout for the home.
	var home: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_home_rest.json"))
	dialog.present(home,true,map.loadout)
	await settle()
	check(not dialog.food_button.visible and dialog.warehouse_button.visible,"home keeps warehouse layout")
	if DisplayServer.get_name()=="headless":
		var state: MapLoadoutState=map.loadout
		var shop:=MapShop.new()
		check(shop.load_catalog("res://data/shops/qingshizhen_inn.json",state).is_empty(),"isolated food catalog")
		state.spirit_stones=100
		check(shop.purchase(state,"base.food.qingcha",1,"").is_empty(),"isolated tea purchase")
		map.player_status.resources={"hp":0.0,"stamina":0.0,"spirit":0.0}
		var day:=WorldCalendar.current_day(state.calendar)
		var event: Dictionary=map.event_registry.events["base.map_event.qingshihewan.rest_n13"]
		var result:=MapTimeActions.rest(state,map.player_status,event,"","base.food.qingcha")
		check(result.error.is_empty() and count(state,"base.food.qingcha")==0,"shelter consumes one meal")
		check(is_equal_approx(map.player_status.resources.hp,map.player_status.maxima.hp*0.5) and is_equal_approx(map.player_status.resources.stamina,map.player_status.maxima.stamina*0.52),"shelter 50 percent plus tea recovery")
		check(WorldCalendar.current_day(state.calendar)==day+1 and is_equal_approx(MapFood.modifiers(state).get("accuracy",0),0.02),"shelter bonus starts after rest")
	print("REST FOOD LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
