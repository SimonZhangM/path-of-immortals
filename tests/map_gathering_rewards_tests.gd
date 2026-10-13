extends SceneTree

var checks := 0
var failures := 0
var save_path := "res://artifacts/gathering-live-%d.json" % Time.get_ticks_usec()

func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func settle() -> void:
	for i in 6: await process_frame
func click(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event,true)
	await settle()
func new_map() -> Node:
	var map: Node = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "map startup: " + map.startup_error)
	return map
func arrive(map: Node, point: String) -> void:
	var origin: String = map.travel.adjacency[point][0].to
	map.travel.current_node_id = origin
	map.travel.map_position = map.travel.node_positions[origin]
	map.travel.mode = "idle"
	map.travel.paused = false
	map._visit_exploration(origin)
	check(map.travel.request_destination(point), "travel reaches revealed herb neighbor")
	map.travel.advance(1000)
	await settle()
func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	var map := await new_map()
	if not map.startup_error.is_empty(): quit(1); return
	var expected := [["n04","林间草坡","zhixuecao"],["n31","山坡荒地","kuaiye"],["n36","潮湿溪石","xilutai"]]
	var herbs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/herbs.json"))
	check(herbs.size() == 4, "four herbs registered")
	for record: Dictionary in herbs:
		var item: ItemData = map.loadout.registry.get_item(record.id)
		check(item != null and item.category == "plant" and item.quality == "下品", "herb rarity/category")
		check(ItemTooltip.effect_text(item) == record.description, "exact supplied description")
		check(not map.loadout.snapshot().owned_units.values().has(record.id), "no automatic herb grants")
		check(not map.loadout.inventory.add_item("test.herb",record.id,Vector2i.ZERO), "herb cannot equip")
		check((load(record.icon) as Texture2D).get_image().has_mipmaps(), "herb mipmaps")
	var pre_total: int = map.loadout.snapshot().owned_units.size()
	var gained := 0
	for index in 3:
		var row: Array = expected[index]
		var point := "base.map.qingshihewan.point." + str(row[0])
		var event: Dictionary = map.event_registry.events[map.event_registry.by_point[point]]
		check(event.title == row[1] and event.item_id == "base.material."+str(row[2]), "node title/material mapping")
		await arrive(map,point)
		check(map.event_state.phase == "gathering" and map.travel.paused and map.gathering_dialog.visible, "arrival auto modal")
		check(map.gathering_dialog.heading.text == row[1] and map.gathering_dialog.herb_name.text == map.loadout.records[event.item_id].name, "location/herb display")
		var tip: ItemTooltip = map.gathering_dialog.herb_slot.build_item_tooltip("")
		check(tip.description == map.loadout.records[event.item_id].description, "herb slot tooltip")
		tip.free()
		await click(map.gathering_dialog.later_button,MOUSE_BUTTON_RIGHT)
		check(not map.event_state.is_active() and not map.travel.paused and not map.event_state.completed.has(event.id), "right cancel no completion")
		check(map._try_start_event(point,"click",true), "click reopens herb")
		await click(map.gathering_dialog.action_buttons[index])
		check(map.event_state.phase == "gathering", "first click selects")
		await capture("res://artifacts/gathering-herb-%s.png" % row[0])
		if index == 0:
			var before: Dictionary = map.loadout.snapshot()
			map.inventory_save_path = "res://artifacts/missing-gathering-directory/save.json"
			await click(map.gathering_dialog.action_buttons[index])
			check(map.loadout.snapshot() == before and map.gathering_dialog.visible and not map.gathering_dialog.error_label.text.is_empty(), "failed preparation grants nothing")
			map.inventory_save_path = save_path
		await click(map.gathering_dialog.action_buttons[index])
		check(map.event_state.phase == "gathering_reward" and map.gathering_result.visible, "selected button opens actual result")
		var offer: Dictionary = map.loadout.gathering_offers[event.id].duplicate(true)
		check(offer.quantity in [index+1,index+2] and offer.days == index+1, "actual quantity in confirmed bounds")
		check(map.gathering_result.heading.text == "获得"+map.loadout.records[event.item_id].name and map.gathering_result.quantity_label.text == "数量：%d株" % offer.quantity, "reward title/explicit quantity")
		check(not map.loadout.has_reward(offer.id), "display before receipt")
		await capture("res://artifacts/gathering-loot-%s.png" % row[0])
		if index == 0:
			await click(map.gathering_result.accept_button,MOUSE_BUTTON_RIGHT)
			check(not map.event_state.is_active() and not map.loadout.has_reward(offer.id), "cancel result leaves pending reward")
			map.queue_free()
			await settle()
			map = await new_map()
			map.travel.current_node_id = point
			map.travel.map_position = map.travel.node_positions[point]
			map.travel.mode = "idle"
			check(map._try_start_event(point,"click",true), "reopen saved pending result")
			check(map.loadout.gathering_offers[event.id] == offer and map.gathering_result.visible, "pending survives reload without reroll")
			map.inventory_save_path = "res://artifacts/missing-gathering-directory/save.json"
			await click(map.gathering_result.accept_button)
			check(not map.loadout.has_reward(offer.id) and map.gathering_result.visible and not map.gathering_result.accept_button.disabled, "failed receipt is retryable")
			map.inventory_save_path = save_path
		await click(map.gathering_result.accept_button)
		gained += int(offer.quantity)
		check(map.loadout.has_reward(offer.id) and map.event_state.completed.has(event.id), "confirmed receipt completes gathering")
		check(map.loadout.snapshot().owned_units.values().count(event.item_id) == offer.quantity, "right herb/quantity in bag")
		var after: Dictionary = map.loadout.snapshot()
		check(MapGatheringRewards.claim(map.loadout,event,save_path).is_empty() and map.loadout.snapshot() == after, "duplicate claim idempotent")
		check(not map._try_start_event(point,"click",true), "same session cannot gather twice")
		await create_timer(0.4).timeout
		check(not map.content.get_node("Points/"+str(row[0]).to_upper()+"/Sign").visible, "sign fades after receipt")
	check(map.loadout.snapshot().owned_units.size() == pre_total+gained, "no unrelated ownership change")
	map.queue_free()
	await settle()
	MapEventState.session_completed.clear() # New process test respawn, inventory remains saved.
	map = await new_map()
	await arrive(map,"base.map.qingshihewan.point.n04")
	check(map.gathering_dialog.visible and map.event_state.phase == "gathering", "restart restores point after claimed result")
	await click(map.gathering_dialog.action_buttons[0])
	await click(map.gathering_dialog.action_buttons[0])
	var again: Dictionary = map.loadout.gathering_offers["base.map_event.qingshihewan.gathering_n04"]
	check(again.id.ends_with(".2"), "respawn uses fresh receipt")
	await click(map.gathering_result.accept_button)
	check(map.loadout.snapshot().owned_units.values().count("base.material.zhixuecao") > int(again.quantity), "respawn adds to existing herb stack")
	var broken: Dictionary = map.loadout.snapshot()
	broken.gathering_offers["base.map_event.qingshihewan.gathering_n04"].quantity = 999
	check(not map.loadout.restore(broken).is_empty(), "reject invalid saved yield")
	map.queue_free()
	await settle()
	print("GATHERING REWARDS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
