extends "res://tests/map_shop_tests.gd"

func inspect_slots(dialog: MapShopDialog, count_visible: int) -> void:
	for index in 8:
		check(dialog.slot_frames[index].visible == (index < count_visible),"frame visibility %d/%d" % [index,count_visible])
		check(dialog.slots[index].visible == dialog.slot_frames[index].visible and dialog.slot_contents[index].visible == dialog.slot_frames[index].visible,"content/button/frame visibility together")
		var expected := dialog.SLOT_ORIGIN + Vector2(index%4,index/4)*dialog.SLOT_STEP-dialog.FRAME.position
		check(dialog.slot_frames[index].position == expected and dialog.slot_frames[index].size == dialog.SLOT_SIZE,"fixed geometry retained")

func save_preview(path: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)

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
	check(map.startup_error.is_empty(),"map ready")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot()
	var catalog := MapShop.new()
	check(catalog.load_catalog(SHOP_PATH,map.loadout).is_empty(),"isolated catalog loaded")
	var original := catalog.definition.duplicate(true)
	var dialog: MapShopDialog = map.shop_dialog
	dialog.present(JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_shop.json")),catalog,map.loadout)
	await settle()
	inspect_slots(dialog,8)
	await save_preview("res://artifacts/shop-updated-full.png")
	# Isolated ninth weapon keeps pagination coverage after removing the All tab.
	catalog.definition.products = original.products.filter(func(row): return row.category=="weapon")
	catalog.definition.products.append({"item_id":"base.map_item.t01_0002","category":"weapon","preview_buy_price":80})
	dialog.change_page(1)
	await settle()
	inspect_slots(dialog,1)
	await save_preview("res://artifacts/shop-updated-partial.png")
	dialog.set_category("food")
	await settle()
	inspect_slots(dialog,0)
	check(dialog.details.get_child_count()==0 and dialog.buy_button.disabled,"empty category clears stale details and purchase state")
	dialog.set_category("weapon")
	await settle()
	inspect_slots(dialog,8)
	dialog.hide()
	var ui: MapInventoryScreen = map.inventory_screen
	ui.set_warehouse("base.warehouse.qingshizhen.home")
	ui.show()
	map.status_header.map_title.hide()
	await settle()
	var arrow_count := 0
	for node in ui.warehouse_sidebar.find_children("*","TextureRect",true,false):
		if not node.texture is AtlasTexture: continue
		if not node.texture.atlas.resource_path.ends_with("/UI-title-cangku-jiantou.webp"): continue
		arrow_count += 1
		check(node.custom_minimum_size==Vector2(13,25),"arrow layout bounds unchanged")
		check(node.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"arrow aspect preserved")
		check(node.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"arrow mipmap filter")
	check(arrow_count==4,"all four warehouse heading arrows use updated art")
	for asset in ["UI-title-cangku-jiantou","tanchuang-jiaoyi-qingshizhen-shangpu"]:
		var config := ConfigFile.new()
		check(config.load("res://assets/%s.webp.import" % asset)==OK and config.get_value("params","mipmaps/generate",false),"updated source mipmaps "+asset)
	await save_preview("res://artifacts/warehouse-updated-arrows.png")
	check(map.loadout.snapshot()==before,"visual preview leaves inventory, money and save state unchanged")
	map.queue_free()
	await settle()
	print("UPDATED ART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
