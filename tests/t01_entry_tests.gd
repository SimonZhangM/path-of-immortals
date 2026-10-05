extends SceneTree

const SAVE := "res://artifacts/t01-entry-inventory.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for i in 8: await process_frame

func click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/t01-" + label + ".png")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1920,1080)
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	var map: Control = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = SAVE
	root.add_child(map)
	await settle()
	check(map.startup_error.is_empty(), "F5 actual map startup")
	if not map.startup_error.is_empty():
		quit(1)
		return
	check(map.loadout.snapshot().owned_units.size() == 115, "F5 all115 immediately owned")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_I
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	check(map.is_inventory_open(), "I opens real inventory")
	check(map.inventory_catalog.visible_entries().size() == 115, "actual inventory lists115")
	await capture("map-inventory")
	check(map.loadout.add_reward({"id":"base.map_reward.entry_fixture","item_id":"base.map_item.hemostatic_pill","quantity":11}).is_empty(), "isolated stack stock")
	map.inventory_catalog.set_filter("search", "止血丹")
	await settle()
	var card: MapInventoryItemCard = map.inventory_screen.grid.get_child(0)
	check(card.quantity_picker != null, "map quantity picker present")
	card.quantity_picker.value = 4
	var rect := card.quantity_picker.get_global_rect()
	await click(rect.position + Vector2(rect.size.x-6,rect.size.y*0.25))
	check(card.selected_quantity() == 5 and not root.gui_is_dragging(), "map spin arrow selects5 without dragging card")
	await click(card.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	check(map.loadout.inventory.get_instances().size() == 1 and map.loadout.inventory.get_instances()[0].units.size() == 5, "map right click equips chosen quantity")
	map.set_inventory_open(false)
	await settle()
	map.queue_free()
	await settle()
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	var manager: GameManager = scene.get_node("GameManager")
	manager.loadout_save_path = SAVE
	root.add_child(scene)
	manager.set_process(false)
	await settle()
	var ui: Control = scene.get_node("MainUI")
	check(manager.startup_error.is_empty() and manager.simulation.t01 != null, "F6 loads shared rules and saved map layout")
	check(manager.party[0].spirit == 50 and manager.party[0].definition.max_stamina == 50 and manager.party[0].stamina == 55, "approved spirit50; original stamina50 plus board5 unchanged")
	manager.set_adjustment(true)
	ui.storage_panel.set_category("pill")
	await settle()
	var stock_id := "owned.base.map_item.hemostatic_pill.0"
	var storage_card: StorageItemCard
	for entry: StorageItemCard in ui.storage_panel.cards.values():
		if entry.item.id == "base.map_item.hemostatic_pill": storage_card = entry
	check(storage_card != null and storage_card.quantity_picker != null, "battle quantity picker")
	(ui.storage_panel._grid.get_parent() as ScrollContainer).ensure_control_visible(storage_card)
	await settle()
	storage_card.quantity_picker.value = 1
	rect = storage_card.quantity_picker.get_global_rect()
	await click(rect.position + Vector2(rect.size.x-6,rect.size.y*0.25))
	check(storage_card.selected_quantity() == 2 and not root.gui_is_dragging(), "battle spin selects2 without dragging")
	await click(storage_card.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	check(manager.party[0].inventory.get_instances()[0].units.size() == 7, "battle chosen quantity merges into same item cell")
	ui.storage_panel.set_category("throwable")
	await settle()
	check(ui.storage_panel.cards.size() == 5, "five blank-image throwable cards accessible")
	await capture("battle-storage")
	manager.set_adjustment(false)
	manager.party[0].hp = 20
	manager.start_battle()
	manager._process(0.001)
	check(manager.party[0].inventory.get_instances()[0].units.size() == 6, "actual first bottle consumes at0")
	manager._process(1.999)
	check(manager.party[0].hp == 23, "actual first recovery tick2s")
	manager.simulation.t01.apply_status(manager.party[0],"反锋",3,manager.party[0],manager.simulation.state.time_usec)
	manager.simulation.t01.apply_status(manager.party[0],"雷蕴",10,manager.party[0],manager.simulation.state.time_usec)
	manager._process(0)
	await settle()
	check(ui.ally_panel.combat_status.text.contains("反锋 3") and ui.ally_panel.combat_status.text.contains("雷盾 80"), "authoritative status and shield display")
	await capture("battle-state")
	var log_button: Button = ui.find_child("BattleLogButton",true,false)
	await click(log_button.get_global_rect().get_center())
	check(ui._log_panel.visible and ui._log_label.text.contains("止血丹") and ui._log_label.text.contains("雷盾80"), "clickable battle log shows use/recovery/shield")
	await capture("battle-log")
	var content := ContentRegistry.new()
	content.load_base_content()
	var reloaded: MapLoadoutState = MapLoadoutStore.create_state(content,content.get_board("base.board.bag")).state
	check(MapLoadoutStore.load_into(reloaded,SAVE).is_empty(), "reload actual consumption save")
	check(reloaded.snapshot().owned_units.size() == 125 and not reloaded.snapshot().owned_units.has(stock_id), "consumed original unit absent; other125 preserved")
	check(reloaded.inventory.get_instances()[0].units.size() == 4, "temporary battle transfer does not rewrite saved formation")
	check(MapLoadoutStore.load_into(reloaded,SAVE).is_empty() and reloaded.snapshot().owned_units.size() == 125, "second reload does not regift")
	scene.queue_free()
	await settle()
	await create_timer(0.2).timeout
	print("T01 ENTRY CHECKS %d; FAILURES %d" % [checks,failures])
	quit(1 if failures else 0)
