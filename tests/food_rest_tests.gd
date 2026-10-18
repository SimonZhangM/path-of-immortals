extends "res://tests/map_shop_tests.gd"

const FOOD_PATH := "res://data/shops/qingshizhen_inn.json"
const REST_PATH := "res://data/map_events/qingshihewan_rest_n05.json"
const INN := "base.map_event.qingshizhen.inn"
const EXPECTED := [
	["qingcha",2,0,2,"accuracy"],["huangjiu",3,0,6,""],["congyoushaobing",3,0,8,""],
	["danchaofan",7,3,10,""],["luroumian",9,6,12,""],["chaoqingcai",4,2,5,"evasion"],
	["baicaifentiao",5,4,7,""],["shanjunretang",5,7,3,""],["dunjitang",9,11,5,""]]

func new_status(state: MapLoadoutState) -> MapPlayerStatus:
	var status := MapPlayerStatus.new()
	status.configure(state.registry,JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json")))
	status.resources={"hp":0.0,"stamina":0.0,"spirit":0.0}
	return status

func verify_food(state: MapLoadoutState, shop: MapShop) -> void:
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REST_PATH))
	check(shop.products().size()==9 and shop.categories().map(func(c):return c.label)==["酒水","主食","菜品","热汤"],"nine foods / four categories")
	for row: Array in EXPECTED:
		var id: String="base.food."+row[0]
		var record: Dictionary=state.records[id]
		check(record.category=="food" and record.food.hp_percent==row[2] and record.food.stamina_percent==row[3] and record.food.bonus_stat==row[4],"exact table effects "+id)
		check(shop.buy_unit_price(id)==row[1],"exact final price "+id)
		check(not state.inventory.equipment_allowed(state.registry.get_item(id)),"food is not battle equipment")
		var stored: Dictionary=state.storage_records().filter(func(r): return r.id==id)[0]
		check(not state.can_place(state.drag_data("storage",stored.storage_id),Vector2i.ZERO),"food placement preview is invalid")
		check(ItemTooltip.classification_tags(state.registry.get_item(id)).has("食物") and not ItemTooltip.effect_text(state.registry.get_item(id)).is_empty(),"food tooltip has actual effects")
		var copy: MapLoadoutState=MapLoadoutStore.candidate(state).state
		var status:=new_status(copy)
		var before:=count(copy,id)
		var day:=WorldCalendar.current_day(copy.calendar)
		var result:=MapTimeActions.rest(copy,status,event,"",id)
		check(result.error.is_empty() and count(copy,id)==before-1 and WorldCalendar.current_day(copy.calendar)==day+1,"one meal consumed with one day")
		check(is_equal_approx(status.resources.hp,status.maxima.hp*(30.0+row[2])/100.0) and is_equal_approx(status.resources.stamina,status.maxima.stamina*(30.0+row[3])/100.0) and is_equal_approx(status.resources.spirit,status.maxima.spirit*0.3),"real percent recovery "+id)
		check(MapFood.modifiers(copy).is_empty() if row[4]=="" else is_equal_approx(MapFood.modifiers(copy).get(row[4],0),0.02),"correct one-day modifier")
		check(copy.restore(JSON.parse_string(JSON.stringify(copy.snapshot()))).is_empty(),"JSON round trip")
		copy.advance_days(1,"test.food.expire")
		check(MapFood.modifiers(copy).is_empty(),"bonus expires next game day")
	var copy: MapLoadoutState=MapLoadoutStore.candidate(state).state
	var status:=new_status(copy)
	var before:=copy.snapshot()
	var resources:=status.resources.duplicate()
	check(not MapTimeActions.rest(copy,status,event,"res://artifacts/no-food-directory/save.json","base.food.qingcha").error.is_empty(),"save failure reported")
	check(copy.snapshot()==before and status.resources==resources,"save failure consumes nothing / no time or recovery")
	check(not MapTimeActions.rest(copy,status,event,"","base.item.unknown").error.is_empty() and copy.snapshot()==before,"invalid or absent food cannot be consumed")
	var no_food_event:=event.duplicate(true)
	no_food_event.erase("allow_food")
	check(not MapTimeActions.rest(copy,status,no_food_event,"","base.food.qingcha").error.is_empty(),"other rest points do not gain food UI implicitly")
	check(not shop.purchase(copy,"base.food.qingcha",1,"res://artifacts/no-food-directory/save.json").is_empty() and copy.snapshot()==before,"purchase write failure atomic")
	check(MapTimeActions.rest(copy,status,event,"").error.is_empty() and count(copy,"base.food.qingcha")==count(state,"base.food.qingcha") and is_equal_approx(status.resources.hp,status.maxima.hp*0.3),"rest without food retains original recovery and inventory")
	status.resources=status.maxima.duplicate()
	var full:=MapTimeActions.rest(copy,status,event,"res://artifacts/food-rest-isolated.json","base.food.qingcha")
	check(full.error.is_empty() and ["hp","stamina","spirit"].all(func(key): return is_equal_approx(float(status.resources[key]),float(status.maxima[key]))),"full state can eat; recovery capped: "+full.error)
	var loaded: MapLoadoutState=MapLoadoutStore.candidate(state).state
	check(MapLoadoutStore.load_into(loaded,"res://artifacts/food-rest-isolated.json").is_empty() and loaded.food_bonus==copy.food_bonus and count(loaded,"base.food.qingcha")==count(copy,"base.food.qingcha"),"food consumption / bonus survive restart")
	var old:=copy.snapshot()
	old.erase("food_bonus")
	check(loaded.restore(old).is_empty() and loaded.food_bonus.is_empty(),"legacy saves have no food bonus")
	var corrupt:=copy.snapshot()
	corrupt.food_bonus.expires_day+=2
	check(not loaded.restore(corrupt).is_empty(),"invalid food expiry rejected")
	var missing:=MapLoadoutStore.candidate(state).state as MapLoadoutState
	var unavailable:=missing.snapshot()
	for unit: String in unavailable.owned_units.keys():
		if unavailable.owned_units[unit]=="base.food.qingcha": unavailable.owned_units.erase(unit)
	missing.restore(unavailable)
	check(not MapTimeActions.rest(missing,new_status(missing),event,"","base.food.qingcha").error.is_empty(),"unowned food rejected")
	var bad_food: Dictionary=state.records["base.food.qingcha"].food.duplicate()
	bad_food.bonus_points=-1
	check(not MapFood.valid_definition(bad_food),"invalid food data rejected")
	# The live combat hit calculation reads resolved values, never calendar or UI.
	var ally:=PartyMemberState.new(status.battle_snapshot().character,state.registry)
	var enemy:=PartyMemberState.new(state.registry.get_enemy("base.enemy.chisong_liaozhu"),state.registry)
	var sim:=BattleSimulation.new([ally],[enemy],state.registry)
	ally.definition.food_modifiers={}
	var base:=sim.cultivation.hit_chance(ally,enemy,0.9,"base.element.none",0)
	ally.definition.food_modifiers={"accuracy":0.02}
	check(is_equal_approx(sim.cultivation.hit_chance(ally,enemy,0.9,"base.element.none",0),base+0.02),"tea adds two percentage points to combat accuracy")
	ally.definition.food_modifiers={"evasion":0.02}
	var evade:=sim.cultivation.hit_chance(enemy,ally,0.9,"base.element.none",0)
	ally.definition.food_modifiers={}
	check(is_equal_approx(sim.cultivation.hit_chance(enemy,ally,0.9,"base.element.none",0),evade+0.02),"greens add two percentage points to combat evasion")

func shot(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/food-"+name+".png")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	var map=load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	var state: MapLoadoutState=map.loadout
	var shop:=MapShop.new()
	check(shop.load_catalog(FOOD_PATH,state).is_empty(),"food catalog")
	state.spirit_stones=1000
	for row: Dictionary in shop.products():
		check(count(state,row.item_id)==0,"not automatically granted")
		check(shop.purchase(state,row.item_id,3,"").is_empty(),"purchase into bag")
	var rendering:=DisplayServer.get_name()!="headless"
	if not rendering: verify_food(state,shop)
	map.event_state.active_id=INN
	map.event_state.phase="inn"
	map.inn_dialog.present(map.event_registry.events[INN],state,map.player_status)
	map.inn_dialog.set_mode("food")
	await settle()
	var menu: MapInnFoodView=map.inn_dialog.food_view
	check(menu.visible and menu.filters.size()==4 and menu.slots[0].visible and not menu.slots[2].visible,"inn food contents and empty slots")
	if rendering:
		await shot("inn-drinks")
		menu.set_category("staple")
		await shot("inn-staples")
	else:
		await click(menu.filters.staple)
		check(menu.category=="staple","actual food category click")
		var id:=menu.selected_id
		var owned:=count(state,id)
		var wallet:=state.spirit_stones
		await click(menu.buy_button)
		check(count(state,id)==owned+1 and state.spirit_stones==wallet-shop.buy_unit_price(id),"actual inn purchase click")
	var carried:=state.snapshot()
	map.queue_free()
	await settle()
	map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"river startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	state=map.loadout
	check(state.restore(carried).is_empty(),"carried foods transfer to river map")
	var rest_event: Dictionary=map.event_registry.events["base.map_event.qingshihewan.rest_n05"]
	map.event_state.active_id=rest_event.id
	map.event_state.phase="rest"
	map.rest_dialog.present(rest_event,true,state)
	await settle()
	var rest: MapRestDialog=map.rest_dialog
	if rendering: await shot("camp-empty")
	else: await click(rest.food_button)
	if rendering: rest.food_choice.present_food(state,"")
	await settle()
	var picker:=rest.food_choice
	check(picker.visible and picker.cards.size()==9 and picker.grid.columns==5,"picker shows only carried foods; five per row")
	check(picker.grid.size.y>picker.scroll.size.y,"more than five foods scroll")
	if rendering:
		await shot("picker")
		picker.select_food("base.food.luroumian")
		picker.confirmed.emit()
		await shot("camp-selected")
	else:
		var before:=state.snapshot()
		var motion:=InputEventMouseMotion.new()
		motion.position=picker.cards[0].get_global_rect().get_center()
		motion.global_position=motion.position
		root.push_input(motion,true)
		await create_timer(0.55).timeout
		var host:=ItemTooltipHost.for_control(picker)
		check(picker.cards[0].modulate.r>1.0 and is_instance_valid(host.tooltip),"actual card hover brightens and shows food tooltip")
		host.dismiss()
		await click(picker.cards[0])
		var chosen:=picker.selected_id
		check(not chosen.is_empty(),"actual card selection")
		await click(picker.cancel_button)
		check(not picker.visible and rest.visible and rest.selected_food_id=="" and state.snapshot()==before,"cancel only closes selector; no food consumed")
		await click(rest.food_button)
		await click(picker.cards[0])
		await click(picker.confirm_button)
		check(rest.selected_food_id==chosen and state.snapshot()==before,"confirm chooses without consuming")
		var owned:=count(state,chosen)
		await click(rest.start_button)
		check(not rest.visible and count(state,chosen)==owned-1,"actual rest click consumes exactly once")
		# A short final row must remain centered; an empty bag is harmless.
		var limited: MapLoadoutState=MapLoadoutStore.candidate(state).state
		var fewer:=limited.snapshot()
		for unit: String in fewer.owned_units.keys():
			if String(fewer.owned_units[unit]).begins_with("base.food.") and fewer.owned_units[unit] not in ["base.food.qingcha","base.food.huangjiu"]: fewer.owned_units.erase(unit)
		limited.restore(fewer)
		rest.present(rest_event,true,limited)
		picker.present_food(limited,"")
		await settle()
		check(picker.cards.size()==2 and absf(picker.grid.get_global_rect().get_center().x-picker.scroll.get_global_rect().get_center().x)<2,"two cards horizontally centered")
		check(absf(picker.grid.get_global_rect().get_center().y-picker.scroll.get_global_rect().get_center().y)<2,"single row vertically centered")
		var escape:=InputEventKey.new()
		escape.keycode=KEY_ESCAPE
		escape.pressed=true
		map.event_state.phase="rest"
		map.event_state.active_id=rest_event.id
		root.push_input(escape,true)
		await settle()
		check(not picker.visible and rest.visible,"Escape closes picker before rest")
		for unit: String in fewer.owned_units.keys():
			if String(fewer.owned_units[unit]).begins_with("base.food."): fewer.owned_units.erase(unit)
		limited.restore(fewer)
		picker.present_food(limited,"")
		await settle()
		check(picker.cards.is_empty() and picker.empty_label.visible,"empty food selector")
	map.queue_free()
	await settle()
	print("FOOD REST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
