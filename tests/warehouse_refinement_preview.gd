extends "res://tests/warehouse_action_art_preview.gd"
const BOARD_ID := "base.map_item.qinglan_board_5"

func _selection_geometry(sidebar: Control) -> Array[Rect2]:
	return [sidebar.selected_art.get_global_rect(),sidebar.item_name.get_global_rect(),sidebar.category.get_global_rect(),sidebar.quality.get_global_rect()]

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
	var state: MapLoadoutState = map.loadout
	var before := state.snapshot()
	var ui: MapInventoryScreen = map.inventory_screen
	ui.set_warehouse(WAREHOUSE)
	ui.show()
	map.status_header.map_title.hide()
	await settle()
	var sidebar: Control = ui.warehouse_sidebar
	var history: Array[Dictionary] = []
	sidebar.present(state,WAREHOUSE,"base.map_item.t01_0059",false,ui.catalog.category_names,history)
	await settle()
	var reference := _selection_geometry(sidebar)
	var group: Control = sidebar.find_child("SelectedItemGroup",true,false)
	var center: Control = sidebar.find_child("SelectedItemCenter",true,false)
	check(group.get_global_rect().get_center().distance_to(center.get_global_rect().get_center())<1,"four-character baseline centered within pixel rounding")
	for id in ["base.map_item.t01_0003","base.map_item.warm_jade",BOARD_ID,"base.map_item.t01_0059"]:
		sidebar.present(state,WAREHOUSE,id,false,ui.catalog.category_names,history)
		await settle()
		var actual := _selection_geometry(sidebar)
		for index in actual.size():
			check(actual[index].position.is_equal_approx(reference[index].position),"image/name/tags origin locked: %s part%d" % [id,index])
		check(actual[1].size.is_equal_approx(reference[1].size),"fixed name slot: "+id)
	for button: TextureButton in [sidebar.minus_button,sidebar.plus_button]:
		var expected := "jianshao" if button==sidebar.minus_button else "zengjia"
		check((button.texture_normal as AtlasTexture).atlas.resource_path.ends_with("tanchuang-jiaoyi-%s.webp" % expected),"quantity image "+expected)
		check(button.stretch_mode==TextureButton.STRETCH_KEEP_ASPECT_CENTERED,"quantity image aspect preserved")
		check((button.texture_normal as AtlasTexture).atlas.get_image().has_mipmaps(),"quantity mipmaps")
	var actions: Control = ui.warehouse_actions
	actions.set_available(true,true,true,true)
	var buttons := [actions.withdraw_button,actions.withdraw_all_button,actions.deposit_button,actions.deposit_all_button]
	var rects: Array[Rect2] = []
	for button: TextureButton in buttons: rects.append(rendered_solid(button,button.texture_normal))
	var left := ui.warehouse_pane.storage_panel.get_global_rect()
	var right := ui.storage_panel.get_global_rect()
	check(absf((left.end.x-rects[1].end.x)-(rects[2].position.x-right.position.x))<1.5,"both inner visible gaps equal")
	check(absf((rects[1].position.x-rects[0].end.x)-(rects[3].position.x-rects[2].end.x))<1.5,"in-pair gaps unchanged and equal")
	for control: Control in [actions.left_group,actions.right_group]:
		var panel := left if control==actions.left_group else right
		check(is_equal_approx(panel.position.y-control.get_global_rect().end.y,8*ui.stage.scale.y),"all actions keep latest eight design px gap")
	check(not map.calendar_readout.get_global_rect().intersects(actions.deposit_all_button.get_global_rect()),"actions still clear date")
	for pane: MapInventoryScreen in [ui,ui.warehouse_pane]:
		var capacity: Control = pane.storage_capacity
		var atlas := capacity.texture as AtlasTexture
		check(atlas.atlas.get_image().has_mipmaps(),"new capacity mipmaps")
		check(capacity.preview_capacity==Vector2i(100,100),"test display retained")
		check(capacity.number_offset==Vector2(-3,0) and capacity.number_area==Rect2(580,106,330,100),"new numeric well with bag and warehouse left nudge")
		check(is_equal_approx(capacity.size.x/capacity.size.y,atlas.get_width()/float(atlas.get_height())),"capacity art not distorted")
		var title: Control = pane.storage_panel.find_child("StorageTitleArtwork",true,false)
		var number_center: Vector2 = capacity.get_global_transform()*capacity.number_center()
		check(absf(number_center.y-title.get_global_rect().get_center().y)<1,"banner body and digits aligned with title")
		check(capacity.get_global_rect().end.x < pane.storage_panel.get_global_rect().end.x-16,"new capacity clear of right border")
		var font_size: int = capacity.display_font_size()
		var text_width: float = capacity.number_font.get_string_size("100/100",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+2
		var numeric_width: float = capacity.number_area.size.x*capacity.size.x/atlas.get_width()*capacity.get_global_transform().get_scale().x
		check(text_width<numeric_width,"100/100 fits new blank well")
		print("CAPACITY ",atlas.atlas.resource_path," atlas=",atlas.region," pos=",capacity.position," size=",capacity.size," font=",font_size)
	var tooltip := ItemTooltip.new()
	tooltip.configure(state.registry.get_item(BOARD_ID))
	tooltip.z_index = 100
	root.add_child(tooltip)
	tooltip.position = Vector2(1480,540)
	await settle()
	var title: Label = tooltip.find_child("ItemTitle",true,false)
	check(title.text=="青岚·凌霄","tooltip removes extra spaces only in rendering")
	check(state.records[BOARD_ID].name=="青岚 · 凌霄" and state.registry.get_item(BOARD_ID).display_name=="青岚 · 凌霄","original name and data unchanged")
	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var relative_width := font.get_string_size("·",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/font.get_string_size("青",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	check(absf(relative_width-1.0)<0.15,"tooltip separator takes about one Chinese character")
	check(state.snapshot()==before,"all adjustments presentation-only")
	if DisplayServer.get_name()!="headless":
		tooltip.hide()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-refinement.png")
		tooltip.show()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-refinement-tooltip.png")
	tooltip.queue_free()
	map.queue_free()
	await settle()
	print("WAREHOUSE REFINEMENT: %d checks, %d failures; static only, no mouse" % [checks,failures])
	quit(1 if failures else 0)
