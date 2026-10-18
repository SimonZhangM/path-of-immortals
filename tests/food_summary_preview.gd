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
	var dialog: MapRestDialog=map.rest_dialog
	dialog.present(map.event_registry.events["base.map_event.qingshihewan.rest_n13"],true,map.loadout)
	check(ItemTooltip.highlighted_keywords().has("闪避"),"evasion highlighted")
	check(ItemTooltip._keyword_color("闪避")==ItemTooltip._keyword_color("命中"),"reuse accuracy color")
	for suffix in ["qingcha","chaoqingcai","luroumian"]:
		var id: String="base.food."+suffix
		var record: Dictionary=map.loadout.records[id]
		dialog.selected_food_id=id
		dialog._refresh_food()
		await settle()
		check(dialog.food_effects.text==MapFood.meal_summary(record),"complete summary "+suffix)
		check(not MapFood.effect_text(record).contains("个百分点"),"percent presentation "+suffix)
		check(dialog.food_icon.get_meta("source_rect").position.x==879 and dialog.food_effects.get_meta("source_rect").position.x==960 and dialog.food_caption.get_meta("source_rect").position.x==955,"icon right ten / effects right five / heading unchanged")
		var font: Font=dialog.food_effects.get_theme_font("font")
		var width:=font.get_string_size(dialog.food_effects.text,HORIZONTAL_ALIGNMENT_LEFT,-1,dialog.food_effects.get_theme_font_size("font_size")).x
		check(width<=dialog.food_effects.size.x+1,"full second line fits "+suffix)
		var first_center: float=dialog.warning.position.y+dialog.warning.size.y*0.5-float(dialog.warning.get_line_height())*0.5
		check(absf(first_center-(703.0-32)*1.2)<=1,"first warning line aligned with baked icon")
		var tooltip:=ItemTooltip.new()
		tooltip.configure(map.loadout.registry.get_item(id),{},-1,0,true)
		root.add_child(tooltip)
		tooltip.z_index=100
		tooltip.position=Vector2(50,480)
		await settle()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/food-summary-"+suffix+".png")
		tooltip.free()
	check(MapFood.meal_summary(map.loadout.records["base.food.qingcha"])=="进食效果：额外恢复 体力+2%，额外增加 命中+2%","tea exact effects")
	check(MapFood.meal_summary(map.loadout.records["base.food.chaoqingcai"])=="进食效果：额外恢复 气血+2%、体力+5%，额外增加 闪避+2%","greens exact effects")
	print("FOOD SUMMARY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
