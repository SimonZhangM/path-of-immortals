extends "res://tests/warehouse_inventory_tests.gd"

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
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
	check(map.startup_error.is_empty(),"map startup")
	var state: MapLoadoutState = map.loadout
	var item := ""
	var other := ""
	for record: Dictionary in state.storage_records():
		if record.name == "火砂": item = record.id
		elif other.is_empty() and record.category != "board": other = record.id
	var snapshot := state.snapshot()
	for i in 9: snapshot.owned_units["test.sidebar.fire.%d" % i] = item
	check(state.restore(snapshot).is_empty(),"ten-unit fixture")
	var baseline := state.snapshot()
	if DisplayServer.get_name() == "headless": model_checks(state,item,other,baseline)
	check(state.restore(baseline).is_empty(),"reset isolated fixture")
	var ui: MapInventoryScreen = map.inventory_screen
	ui.set_warehouse(WAREHOUSE)
	ui.show()
	map.status_header.map_title.hide()
	await settle()
	var sidebar = ui.warehouse_sidebar
	var pane := ui.warehouse_pane
	var journal = map.warehouse_transfers
	var actions = ui.warehouse_actions
	check(sidebar.visible and sidebar.maximum == 0 and not sidebar.amount.editable,"empty selection disables quantity")
	check(sidebar.history_rows.get_child(0).text == "无历史记录","empty history")
	if DisplayServer.get_name() == "headless":
		ui.catalog.set_filter("search","火砂")
		await settle()
		await click(find_card(ui,item).get_global_rect().get_center())
		check(sidebar.maximum == 10 and sidebar.quantity == 1,"selected source count and default one")
		check(sidebar.item_name.text == "火砂" and sidebar.category.text == ui.catalog.category_names[state.records[item].category],"selected actual name and major category")
		check((sidebar.direction.texture as AtlasTexture).atlas.resource_path.ends_with("jiantou2.webp"),"deposit arrow points toward fixed warehouse")
		await click(sidebar.plus_button.get_global_rect().get_center())
		check(sidebar.quantity == 2,"plus increments")
		await click(sidebar.minus_button.get_global_rect().get_center())
		check(sidebar.quantity == 1,"minus decrements")
		sidebar.amount.text = "999"
		sidebar.amount.text_changed.emit("999")
		check(sidebar.quantity == 10 and sidebar.plus_button.disabled,"input clamps to source max")
		sidebar.amount.text = "-8"
		sidebar.amount.text_changed.emit("-8")
		check(sidebar.quantity == 1 and sidebar.minus_button.disabled,"input clamps min")
		sidebar.amount.text_changed.emit("not a number")
		check(sidebar.amount.text == "1","invalid input restores safe count")
		sidebar.set_quantity(3)
		await click(actions.deposit_button.get_global_rect().get_center())
		check(_count(state,item,true) == 3 and _count(state,item,false) == 7,"selected action deposits requested count")
		check(journal.history.size() == 1,"successful UI action journals once")
		await click(find_card(pane,item).get_global_rect().get_center())
		check(sidebar.maximum == 3 and sidebar.owned.text == "当前拥有：3","withdraw max reads warehouse, not bag")
		check(not find_card(ui,item).selected,"only one selected across both panes")
		check((sidebar.direction.texture as AtlasTexture).atlas.resource_path.ends_with("jiantou1.webp"),"withdraw direction")
		check(sidebar.status.text == "储物袋空间不足" and sidebar.capacity_text.text == "转移后：%d/99" % state.storage_used_slots(),"preview uses actual inventory, not display 100/100")
		await click(actions.withdraw_button.get_global_rect().get_center())
		check(_count(state,item,true)==2 and _count(state,item,false)==8,"withdraw default one")
		check(journal.history.size()==2,"two history rows")
		var newest_id: int = journal.history[0].operation_id
		var older_id: int = journal.history[1].operation_id
		check(sidebar.find_child("Undo_%d" % older_id,true,false).disabled,"dependent older action unavailable")
		await click(sidebar.find_child("Undo_%d" % newest_id,true,false).get_global_rect().get_center())
		check(journal.history.size()==1 and _count(state,item,true)==3,"undo button restores own receipt")
		check(not sidebar.find_child("Undo_%d" % older_id,true,false).disabled,"previous receipt becomes available again")
		await click(sidebar.find_child("Undo_%d" % older_id,true,false).get_global_rect().get_center())
		check(journal.history.is_empty() and state.snapshot()==baseline,"second undo restores baseline")
		# Existing shortcuts retain whole-stack behavior, and now also journal it.
		await click(find_card(ui,item).get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		check(_count(state,item,true)==10 and journal.history[0].units.size()==10,"right click remains whole stack")
		map._close_home_warehouse()
		check(journal.history.is_empty() and not sidebar.visible,"leaving warehouse clears visit history")
	else:
		var preview_item := item
		for record: Dictionary in state.storage_records():
			if record.name == "培元丹": preview_item = record.id
		check(journal.transfer(state,WAREHOUSE,preview_item,false,"",false,1).is_empty(),"preview first receipt")
		check(journal.transfer(state,WAREHOUSE,other,false,"",false,1).is_empty(),"preview independent second receipt")
		await settle()
		ItemTooltipHost.for_control(ui).select_card(find_card(pane,preview_item))
		ui._refresh_warehouse_actions()
		await settle()
		check(ui.sidebar.get_global_rect().encloses(sidebar.get_global_rect()),"sidebar fits existing panel")
		check(sidebar.history_rows.get_child_count()==2,"two visible history rows")
		var selected_group: Control = sidebar.find_child("SelectedItemGroup",true,false)
		var selected_center: Control = sidebar.find_child("SelectedItemCenter",true,false)
		check(selected_group.get_global_rect().get_center().distance_to(selected_center.get_global_rect().get_center())<1,"fixed four-character group centered within pixel rounding")
		var artwork_rect: Rect2 = sidebar.selected_art.get_child(0).get_global_rect()
		var details_rect: Rect2 = sidebar.find_child("SelectedItemDetails",true,false).get_global_rect()
		check(artwork_rect.merge(details_rect).get_center().distance_to(selected_center.get_global_rect().get_center())<1.5,"visible image/name/tags centered as one group")
		var first_line: Rect2 = sidebar.status.get_parent().get_global_rect()
		var second_line: Rect2 = sidebar.capacity_text.get_global_rect()
		var third_line: Rect2 = sidebar.hint.get_global_rect()
		check(is_equal_approx(first_line.size.y,second_line.size.y) and is_equal_approx(second_line.size.y,third_line.size.y),"preview three equal text rows")
		check(absf((second_line.position.y-first_line.end.y)-(third_line.position.y-second_line.end.y))<0.1,"preview text row gaps equal")
		check(sidebar.item_name.get_theme_font("font")==ItemTooltip.summary_title_font(),"item title shares tooltip bold font")
		check(sidebar.item_name.get_theme_color("font_color")==ItemTooltip.ITEM_TITLE_COLOR,"item title shares tooltip color")
		var tooltip := ItemTooltip.new()
		tooltip.configure(state.registry.get_item(preview_item))
		var tooltip_title: Label = tooltip.find_child("ItemTitle",true,false)
		check(tooltip_title.get_theme_font("font")==sidebar.item_name.get_theme_font("font") and tooltip_title.get_theme_color("font_color")==sidebar.item_name.get_theme_color("font_color"),"actual tooltip and sidebar share title style")
		check(tooltip_title.get_theme_font_size("font_size")==40,"tooltip original native title size unchanged")
		tooltip.free()
		check(sidebar.owned.get_theme_font("font")==ItemTooltip.summary_body_font(),"sidebar prose uses tooltip sans body font")
		var reference_chip := ItemTooltip.chip("丹药",ItemTooltip.CLASSIFICATION_COLOR)
		var reference_style := reference_chip.get_theme_stylebox("normal") as StyleBoxFlat
		for tag: Label in [sidebar.category,sidebar.quality]:
			check(tag.get_theme_font_size("font_size")==13,"sidebar tags reduced from 15 to 13")
			var tag_style := tag.get_theme_stylebox("normal") as StyleBoxFlat
			check(tag.get_theme_font("font")==ItemTooltip.summary_body_font(),"tag font matches tooltip")
			check(tag_style.bg_color==reference_style.bg_color and tag_style.border_color==reference_style.border_color and tag_style.corner_radius_top_left==reference_style.corner_radius_top_left,"tag fill/border/radius match tooltip")
		reference_chip.free()
		var frames := sidebar.find_children("PreviewIconFrame","PanelContainer",true,false)
		check(frames.size()==2,"two preview icon gold frames")
		var bag_caption: Label = sidebar.find_child("PreviewBagCaption",true,false)
		check(bag_caption.size.x>=bag_caption.get_theme_font("font").get_string_size(bag_caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,bag_caption.get_theme_font_size("font_size")).x,"bag caption fully fits below icon")
		for frame: PanelContainer in frames:
			var frame_style := frame.get_theme_stylebox("panel") as StyleBoxFlat
			check(frame_style.border_width_left==1 and frame_style.border_color==Color("9a814c"),"preview icon thin gold border")
		check(sidebar.selected_art.find_child("QualityBackground",true,false).texture.resource_path==MapItemQuality.background_path(state.records[preview_item].quality),"selected thumbnail uses actual quality texture")
		for group in sidebar.get_children():
			if group is VBoxContainer:
				var heading: Label = group.get_child(0).get_child(1)
				check(heading.size.x >= 80,"heading has visible text width: " + heading.text)
				check(heading.get_theme_font("font")==ItemTooltip.summary_title_font(),"section heading bold font")
				var box := group.get_child(1).get_theme_stylebox("panel") as StyleBoxFlat
				check(box.bg_color.a>0.94 and box.border_width_left==1,"dark near-opaque panel retains thin border")
		for row in sidebar.history_rows.get_children():
			for child in row.get_children():
				if child is Label:
					check(child.size.y >= 30 and child.size.x >= 70,"history direction has visible area")
		for asset in ["alert","cangchucaozuo","cebian1","cebian2","jiantou","jiantou1","jiantou2"]:
			check(load("res://assets/UI-title-cangku-%s.webp" % asset).get_image().has_mipmaps(),"sidebar mipmap: "+asset)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-sidebar.png")
	map.queue_free()
	await settle()
	print("WAREHOUSE SIDEBAR: ",checks," checks, ",failures," failures; isolated save, Render has no mouse")
	quit(1 if failures else 0)

func _count(state: MapLoadoutState, item: String, warehouse: bool) -> int:
	for record: Dictionary in (state.warehouse_records(WAREHOUSE) if warehouse else state.storage_records()):
		if record.id == item: return int(record.quantity)
	return 0

func model_checks(state: MapLoadoutState, item: String, other: String, baseline: Dictionary) -> void:
	var journal = Transfer.new()
	check(not journal.transfer(state,WAREHOUSE,item,false,"",false,11).is_empty(),"excess rejected")
	check(not journal.transfer(state,WAREHOUSE,item,false,"",false,0).is_empty(),"zero rejected")
	check(state.snapshot()==baseline and journal.history.is_empty(),"invalid transfer no mutation/history")
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,3).is_empty(),"partial deposit")
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,2).is_empty(),"same kind second receipt")
	var older_id: int = journal.history[1].operation_id
	var newer_id: int = journal.history[0].operation_id
	check(journal.revert(state,older_id,"").is_empty(),"independent older undo")
	check(_count(state,item,true)==2 and _count(state,item,false)==8,"only older three units reversed")
	check(journal.history.size()==1 and journal.history[0].operation_id==newer_id,"other receipt preserved")
	check(journal.revert(state,newer_id,"").is_empty() and state.snapshot()==baseline,"newer independent undo")
	check(not journal.revert(state,older_id,"").is_empty(),"undo cannot repeat")
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,2).is_empty(),"receipt before unrelated award")
	var awarded := state.snapshot()
	awarded.owned_units["test.sidebar.unrelated"] = other
	check(state.restore(awarded).is_empty(),"unrelated award applied")
	check(journal.revert(state,journal.history[0].operation_id,"").is_empty() and state.snapshot().owned_units.has("test.sidebar.unrelated"),"undo does not rewind subsequent reward")
	check(state.restore(baseline).is_empty(),"reset award fixture")
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,3).is_empty(),"dependency base")
	check(journal.transfer(state,WAREHOUSE,item,true,"",false,1).is_empty(),"dependent withdraw")
	var before := state.snapshot()
	check(not journal.revert(state,journal.history[1].operation_id,"").is_empty() and state.snapshot()==before,"dependency rejects without partial reversal")
	check(journal.revert(state,journal.history[0].operation_id,"").is_empty(),"dependent latest reversed")
	var failure_path := "res://artifacts/no-such-sidebar-save-directory/save.json"
	before = state.snapshot()
	check(not journal.revert(state,journal.history[0].operation_id,failure_path).is_empty(),"undo save failure")
	check(state.snapshot()==before and journal.history.size()==1,"failed undo preserves state and receipt")
	check(not journal.transfer(state,WAREHOUSE,other,false,failure_path).is_empty(),"transfer save failure")
	check(state.snapshot()==before and journal.history.size()==1,"failed transfer preserves state/history")
	# Newly awarded same-kind units must not replace a missing recorded unit.
	var changed := before.duplicate(true)
	var missing: String = journal.history[0].units.keys()[0]
	changed.warehouses[WAREHOUSE].erase(missing)
	changed.owned_units.erase(missing)
	changed.owned_units["test.sidebar.new.reward"] = item
	changed.warehouses[WAREHOUSE]["test.sidebar.new.reward"] = item
	check(state.restore(changed).is_empty(),"replacement award fixture")
	check(not journal.revert(state,journal.history[0].operation_id,"").is_empty(),"exact-unit undo refuses same-kind substitution")
	check(state.restore(baseline).is_empty(),"reset bulk fixture")
	journal.clear()
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,2).is_empty(),"individual before bulk")
	older_id = journal.history[0].operation_id
	check(journal.transfer(state,WAREHOUSE,"",false,"",true).is_empty(),"bulk transfer")
	newer_id = journal.history[0].operation_id
	check(state.storage_records().size()==1 and state.storage_records()[0].get("board_layout","")==state.board.id,"bulk protects active board")
	check(journal.revert(state,older_id,"").is_empty(),"independent single undo after bulk")
	check(journal.revert(state,newer_id,"").is_empty() and state.snapshot()==baseline,"bulk exact undo conserves other action")
	check(journal.transfer(state,WAREHOUSE,item,false,"").is_empty(),"withdraw fixture full deposit")
	journal.clear()
	check(journal.transfer(state,WAREHOUSE,item,true,"",false,2).is_empty(),"first partial withdrawal")
	check(journal.transfer(state,WAREHOUSE,item,true,"",false,3).is_empty(),"second partial withdrawal")
	check(journal.revert(state,journal.history[1].operation_id,"").is_empty() and _count(state,item,false)==3,"independent older withdrawal undo")
	var path := "res://artifacts/warehouse-sidebar-undo-%d.json" % Time.get_ticks_usec()
	check(journal.revert(state,journal.history[0].operation_id,path).is_empty(),"undo saves atomically")
	var reloaded: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(MapLoadoutStore.load_into(reloaded,path).is_empty() and reloaded.snapshot()==state.snapshot(),"saved undo survives reload")
	check(state.restore(baseline).is_empty(),"reset withdrawal fixture")
	journal.clear()
	check(not Transfer.preview(state,WAREHOUSE,item,true).sufficient,"actual bag over capacity warning")
	check(Transfer.preview(state,WAREHOUSE,item,false).projected==1,"new destination kind consumes one slot")
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,1).is_empty(),"first history")
	check(Transfer.preview(state,WAREHOUSE,item,false).projected==1,"existing kind consumes no extra slot")
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,1).is_empty(),"second history")
	check(journal.transfer(state,WAREHOUSE,item,false,"",false,1).is_empty(),"third history")
	check(journal.history.size()==2,"history keeps last two successful operations")
	state.inventory.locked = true
	check(not journal.transfer(state,WAREHOUSE,item,false,"").is_empty(),"original lock honored before candidate")
	check(not journal.revert(state,journal.history[0].operation_id,"").is_empty(),"undo honors lock")
	state.inventory.locked = false
	check(state.restore(baseline).is_empty(),"model reset")
