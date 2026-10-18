extends "res://tests/map_shop_tests.gd"

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
	if not map.startup_error.is_empty(): push_error(map.startup_error); quit(1); return
	var shop:=MapShop.new()
	check(shop.load_catalog("res://data/shops/qingshizhen_inn.json",map.loadout).is_empty(),"food catalog")
	map.loadout.spirit_stones=100
	for id in ["huangjiu","luroumian","dunjitang","baicaifentiao"]:
		check(shop.purchase(map.loadout,"base.food."+id,1,"").is_empty(),"isolated preview food")
	var picker:=MapFoodChoiceDialog.new()
	root.add_child(picker)
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.present_food(map.loadout,"")
	await settle()
	var base:=MapExitDialog.new()
	check(picker.confirm_button.position.y==base.confirm_button.position.y+14,"confirm down eight from previous six offset")
	check(picker.cancel_button.position.y==base.cancel_button.position.y+14,"cancel down eight from previous six offset")
	check(picker.scroll.position==Vector2(29,123) and picker.scroll.size==Vector2(482,126),"card region unchanged")
	check(picker.cards.size()==4 and picker.grid.columns==5,"four cards / original five column layout")
	base.free()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/food-choice-spacing.png")
	print("FOOD CHOICE SPACING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
