extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func settle(frames := 6) -> void:
	for i in frames: await process_frame
func motion(point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
func button(point: Vector2, which: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = which
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and which == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)
func click(point: Vector2, which := MOUSE_BUTTON_LEFT) -> void:
	motion(point)
	button(point, which, true)
	button(point, which, false)
	await settle()
func hover(point: Vector2) -> void:
	motion(point)
	await create_timer(0.65).timeout
	await settle()
func find_keyword(tip: ItemTooltip, word: String) -> Vector2:
	var body: VBoxContainer = tip.find_child("EffectDescription",true,false)
	for line: RichTextLabel in body.get_children():
		if not line.text.contains("[url=%s]" % word): continue
		var rect := line.get_global_rect()
		for y in range(int(rect.position.y)+8, int(rect.end.y), 12):
			for x in range(int(rect.position.x)+4, int(rect.end.x), 6):
				var point := Vector2(x,y)
				motion(point)
				await process_frame
				if tip.active_keyword == word: return point
	return Vector2.ZERO
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	if DisplayServer.get_name() != "headless":
		push_error("Run mouse checks headless to isolate the desktop cursor; use square_inventory_card_preview for rendering")
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry")
	var made := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(made.error.is_empty(), "loadout")
	var model: MapLoadoutState = made.state
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	var records: Array[Dictionary] = []
	for record: Dictionary in model.storage_records():
		if record.name in ["开山斧", "镇土丹", "回灵丹"]: records.append(record)
	check(records.size() == 3, "fixtures")
	catalog.replace_entries(records)
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	var card: MapInventoryItemCard
	var other: MapInventoryItemCard
	for child: MapInventoryItemCard in ui.grid.get_children():
		if child.entry.name == "开山斧": card = child
		else: other = child
	var center := card.get_global_rect().get_center()
	var host := ItemTooltipHost.for_control(card)
	check(absf(card.size.y-card.size.x*card.STORAGE_ASPECT) <= 1.0, "height is width plus unchanged name strip")
	check(card.canvas.get_node("NameShade").size == Vector2(186,37), "name rectangle unchanged")
	var before := model.snapshot()
	await click(center)
	check(card.selected and card.get_node("SelectionOutline").visible, "left click selects with highlight")
	check(not root.gui_is_dragging() and model.snapshot() == before, "click never starts drag or mutates loadout")
	await hover(center)
	check(is_instance_valid(host.tooltip) and host.pinned, "selected hover pins tooltip")
	if not is_instance_valid(host.tooltip):
		print("HOVERED: ", root.gui_get_hovered_control(), " HOST: ", host._candidate, " key:", host._candidate_key)
		quit(1)
		return
	var tip := host.tooltip
	check(not tip.find_child("KeywordInset",true,false).visible, "default core only")
	await hover(Vector2(30,1350))
	check(host.tooltip == tip, "pinned survives leaving card and tooltip")
	await click(tip.get_global_rect().position+Vector2(40,40), MOUSE_BUTTON_RIGHT)
	check(host.tooltip == tip, "inside right click retains tooltip")
	var keyword_point := await find_keyword(tip,"疲惫")
	check(keyword_point != Vector2.ZERO, "real text hover finds fatigue keyword")
	await settle()
	check(tip.active_keyword == "疲惫" and tip.find_child("KeywordInset",true,false).visible, "hover shows only fatigue")
	check(tip.find_child("KeywordRows",true,false).get_child_count() == 2, "single heading and definition, not whole glossary")
	motion(tip.get_global_rect().position+Vector2(40,40))
	await settle()
	check(tip.active_keyword.is_empty() and not tip.find_child("KeywordInset",true,false).visible, "leaving keyword collapses its definition")
	await click(Vector2(30,1350))
	check(not is_instance_valid(host.tooltip), "outside left click dismisses")
	await click(other.get_global_rect().get_center())
	check(other.selected and not card.selected, "single selection transfers")
	await hover(other.get_global_rect().get_center())
	await click(Vector2(30,1350), MOUSE_BUTTON_RIGHT)
	check(not is_instance_valid(host.tooltip), "outside right click dismisses")
	await click(center)
	button(center,MOUSE_BUTTON_LEFT,true)
	motion(center+Vector2(12,0),true)
	button(center+Vector2(12,0),MOUSE_BUTTON_LEFT,false)
	await settle()
	check(not root.gui_is_dragging(), "release before deferred drag cannot leave stuck preview")
	button(center,MOUSE_BUTTON_LEFT,true)
	motion(center+Vector2(2,0),true)
	await settle()
	check(not root.gui_is_dragging(), "small pointer jitter does not drag")
	motion(center+Vector2(12,0),true)
	await settle()
	check(root.gui_is_dragging(), "held movement starts existing drag preview")
	check(not is_instance_valid(host.tooltip), "drag has no blocking pinned tooltip")
	var target := ui.loadout_board.get_global_transform_with_canvas() * ui.loadout_board.layout.footprint_rect(Vector2i.ZERO, registry.get_item(card.entry.id).grid_size, ui.loadout_board.size).get_center()
	motion(target,true)
	await settle()
	button(target,MOUSE_BUTTON_LEFT,false)
	await settle()
	check(not model.inventory.item_at(Vector2i.ZERO).is_empty(), "drag still places item on map board")
	await hover(target)
	check(is_instance_valid(host.tooltip) and not host.pinned, "board uses interactive core tooltip too")
	await hover(host.tooltip.get_global_rect().position+Vector2(40,40))
	check(is_instance_valid(host.tooltip), "unselected tooltip can be entered")
	await hover(Vector2(20,1350))
	check(not is_instance_valid(host.tooltip), "unselected tooltip closes after leaving")
	await hover(target)
	ui.hide()
	await settle()
	check(not is_instance_valid(host.tooltip), "hidden owner closes tooltip")
	ui.queue_free()
	await settle()
	# A compact two-keyword fixture also probes the bottom/right boundary.
	var slot := MapEncounterItemSlot.new()
	slot.position = Vector2(2460,1350)
	slot.size = Vector2(80,80)
	var definition: ItemData = registry.get_item("base.map_item.short_iron_hammer")
	root.add_child(slot)
	slot.show_item(definition)
	ItemTooltipHost.bind(slot,func(_point: Vector2): return definition.id,func(_key: String):
		var panel := ItemTooltip.new()
		panel.configure(definition,{"effect_description":"施加疲惫，并获得坚韧。"})
		return panel
	)
	await hover(slot.get_global_rect().get_center())
	tip = host.tooltip
	check(is_instance_valid(tip) and not host.pinned, "encounter source shares core tooltip")
	check(await find_keyword(tip,"疲惫") != Vector2.ZERO, "first keyword hover")
	await settle()
	var core_position: Vector2 = tip.find_child("SummaryPanel",true,false).global_position
	check(await find_keyword(tip,"坚韧") != Vector2.ZERO, "second keyword hover")
	await settle()
	check(tip.find_child("KeywordDefinition",true,false).get_parsed_text().begins_with("坚韧："), "definition switches to hovered keyword only")
	check(tip.find_child("KeywordRows",true,false).get_child_count() == 2, "no extra definition row accumulated")
	check(tip.find_child("SummaryPanel",true,false).global_position.is_equal_approx(core_position), "core does not jump when keyword changes")
	check(root.get_visible_rect().encloses(tip.get_global_rect()), "expanded tooltip fits bottom/right viewport")
	slot.queue_free()
	await settle()
	check(not is_instance_valid(host.tooltip), "removed source closes tooltip")
	await battle_checks(host)
	print("ITEM SELECTION/TOOLTIP: ", checks, " checks, ", failures, " failures; actual viewport mouse events, no system mouse or real save")
	quit(1 if failures else 0)

func battle_checks(host: ItemTooltipHost) -> void:
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	check(game.startup_error.is_empty(), "battle initialized with in-memory loadout")
	game.start_battle()
	game.pause_battle()
	game.set_adjustment(true)
	await settle()
	var ui = scene.get_node("MainUI")
	var panel: BattleStoragePanel = ui.storage_panel
	panel.catalog.set_filter("search","开山斧")
	await settle()
	var card: BattleInventoryItemCard = panel.grid.get_child(0)
	var point := card.get_global_rect().get_center()
	await click(point)
	check(card.selected and not root.gui_is_dragging(), "battle click selects without drag")
	await hover(point)
	check(is_instance_valid(host.tooltip) and host.pinned, "battle selected tooltip pins")
	await click(host.tooltip.get_global_rect().position+Vector2(40,40),MOUSE_BUTTON_RIGHT)
	check(game.adjustment_open and is_instance_valid(host.tooltip), "right click inside tooltip retains battle storage and tooltip")
	# Clicking the card outside its tooltip still executes the old right-click command.
	await click(point,MOUSE_BUTTON_RIGHT)
	check(game.adjustment_open and game.party[0].inventory.get_instances().size() == 1, "right-click card still equips and retains bag")
	var instance: Dictionary = game.party[0].inventory.get_instances()[0]
	check(game.unequip(0,instance.instance_id), "battle item returned for drag fixture")
	await settle()
	card = panel.grid.get_child(0)
	point = card.get_global_rect().get_center()
	button(point,MOUSE_BUTTON_LEFT,true)
	motion(point+Vector2(12,0),true)
	await settle()
	check(root.gui_is_dragging(), "battle held movement starts existing preview")
	var board: InventoryView = ui.ally_panel.bags[0]
	var item := game.registry.get_item(card.entry.id)
	var target := board.get_global_transform_with_canvas()*board.board_layout.footprint_rect(Vector2i.ZERO,item.grid_size,board.size).get_center()
	motion(target,true)
	await settle()
	button(target,MOUSE_BUTTON_LEFT,false)
	await settle()
	check(game.party[0].inventory.get_instances().size() == 1, "battle drag uses manager equip command")
	await hover(target)
	check(is_instance_valid(host.tooltip) and not host.pinned, "battle board tooltip is interactive")
	await click(Vector2(20,650),MOUSE_BUTTON_RIGHT)
	check(not game.adjustment_open and not is_instance_valid(host.tooltip), "outside right click still dismisses tooltip and battle bag")
	scene.queue_free()
	await settle()
