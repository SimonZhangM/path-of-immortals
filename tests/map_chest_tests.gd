extends SceneTree

var checks := 0
var failures := 0
var path := "res://artifacts/chest-test-%d.json" % Time.get_ticks_usec()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 8: await process_frame
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await settle()
func new_map() -> Node:
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = path
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"actual map startup: " + map.startup_error)
	return map
func arrive(map: Node, point: String) -> void:
	var origin: String = map.travel.adjacency[point][0].to
	map.travel.current_node_id = origin
	map.travel.map_position = map.travel.node_positions[origin]
	map.travel.mode = "idle"
	map.travel.paused = false
	map._visit_exploration(origin)
	check(map.travel.request_destination(point),"route toward chest")
	map.travel.advance(1000)
	await settle()

func preview(map: Node) -> void:
	# Render only: no virtual mouse or reward writes in the visual pass.
	for suffix in ["n34", "n06", "n22", "n14", "n27"]:
		var event: Dictionary = map.event_registry.events["base.map_event.qingshihewan.chest_"+suffix]
		var dialog = map.chest_observation_dialog
		dialog.present(event)
		await settle()
		for label: Label in [dialog.location_description, dialog.chest_description]:
			check(label.get_visible_line_count()==label.get_line_count(), "all copy visible: "+suffix)
			var source: Rect2 = label.get_meta("source_rect")
			check(label.size.y <= roundf(source.size.y * 1.2)+1, "copy stays in authored band: "+suffix)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/chest-observation-"+suffix+".png")
		dialog.hide()
		var pool_id: String = {"n34":"equipment","n06":"consumables","n22":"artifacts","n14":"equipment","n27":"artifacts"}[suffix]
		var pool := MapChestRewards.pool_definition("base.chest_pool."+pool_id)
		var slots := MapChestRewards.candidates(map.loadout,event,pool)
		var records: Array[Dictionary] = []
		for index in 2:
			var record: Dictionary = map.loadout.records[slots[index][0 if index==0 else slots[index].size()-1]].duplicate(true)
			record.quantity=1
			records.append(record)
		var result = map.chest_dialog
		result.present_choices(event,records,map.inventory_catalog.category_names,map.loadout)
		result.select_choice(0 if suffix!="n27" else 1)
		await settle()
		check(result.location_description.get_visible_line_count()==result.location_description.get_line_count(),"result copy fits: "+suffix)
		for card in result.cards:
			check(not card.description.text.is_empty() and card.description.text==card.entry.flavor_description and card.description.get_line_count()<=2 and card.description.position.y+card.description.size.y<=card.size.y,"catalog narrative fits the two-line description band")
			check(card.glow.material.get_shader_parameter("glow_color").is_equal_approx(Color(MapItemQuality.color(card.entry.quality),0.3)),"glow follows item quality")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/chest-choice-"+suffix+".png")
		result.hide()

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	var map := await new_map()
	if DisplayServer.get_name()!="headless":
		await preview(map)
		map.queue_free()
		await settle()
		print("CHEST OBSERVATION RENDER: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0)
		return
	await check_pools(map)
	var expected := {"n39":"下品","n08":"下品","n27":"下品","n06":"下品","n34":"下品"}
	var locations := {"n39":"桥东石滩","n08":"北岸林阶","n27":"南坡林缘","n06":"河心乱礁","n34":"西瀑石台"}
	var count := 0
	for event: Dictionary in map.event_registry.events.values():
		if event.type == "chest": count += 1
	check(count == 5,"exactly five configured chests")
	var total_before: int = map.loadout.snapshot().owned_units.size()
	for point: String in expected:
		var point_id := "base.map.qingshihewan.point." + point
		var event: Dictionary = map.event_registry.events[map.event_registry.by_point[point_id]]
		check(event.quality == expected[point],"all river bay chests use lower grade: " + point)
		await arrive(map,point_id)
		var observation = map.chest_observation_dialog
		check(observation.visible and not map.chest_dialog.visible and map.event_state.phase=="chest_observation" and map.travel.paused,"arrival observes before offering choices")
		check(observation.heading.text==locations[point] and observation.location_description.text==event.observation.location_description and observation.chest_name.text==event.observation.chest_name and observation.chest_description.text==event.observation.description,"exact location and chest copy")
		check(map.content.get_node("Points/"+point.to_upper()).location_note==locations[point],"map location name matches observation")
		check(observation.location_illustration.texture.resource_path==event.presentation.illustration and observation.chest_image.texture.resource_path==event.presentation.chest_image,"per-location scene and chest artwork")
		check(not map.loadout.chest_offers.has(event.reward_id),"observation does not roll an offer")
		var observed: Dictionary = map.loadout.snapshot()
		check(map.event_state.advance().is_empty() and map.event_state.phase=="chest_observation","dialogue advance cannot skip observation")
		check(map.event_state.close_chest(true).is_empty(),"observation cannot claim rewards")
		await click(observation.later_button)
		check(not observation.visible and not map.event_state.is_active() and not map.travel.paused and map.loadout.snapshot()==observed,"later closes without reward or offer mutation")
		check(map._try_start_event(point_id,"click",true),"click reopens observation")
		await settle()
		if point=="n39":
			var motion := InputEventMouseMotion.new()
			motion.position = observation.open_button.get_global_rect().get_center()
			motion.global_position = motion.position
			root.push_input(motion,true)
			await settle()
			check(observation.open_button.is_hovered() and observation.open_label.get_theme_color("font_color")==Color.BLACK,"open hover has black text")
			check(observation.open_button.texture_hover.resource_path.ends_with("tanchuang-baoxiang-dakai2.webp"),"hover uses supplied lit texture")
			motion.position = observation.canvas.global_position+Vector2(30,30)
			motion.global_position = motion.position
			root.push_input(motion,true)
			await settle()
			check(observation.open_label.get_theme_color("font_color")==Color.WHITE,"leaving button restores white text")
			map.inventory_save_path = "res://artifacts/nonexistent-chest-dir/save.json"
			await click(observation.open_button)
			check(observation.visible and map.event_state.phase=="chest_observation" and not observation.error_label.text.is_empty() and not observation.open_button.disabled,"failed offer save stays in observation with retry")
			check(map.loadout.snapshot()==observed,"failed opening cannot change inventory or offer")
			map.inventory_save_path = path
			for key_cancel in [false,true]:
				var input: InputEvent
				if key_cancel:
					var key := InputEventKey.new()
					key.keycode = KEY_ESCAPE
					key.pressed = true
					input = key
				else:
					var mouse := InputEventMouseButton.new()
					mouse.button_index = MOUSE_BUTTON_RIGHT
					mouse.pressed = true
					mouse.position = Vector2(50,50)
					input = mouse
				root.push_input(input,true)
				await settle()
				check(not observation.visible and not map.event_state.is_active() and map.travel.current_node_id==point_id,"right click / escape cancel observation without map movement")
				check(map._try_start_event(point_id,"click",true),"observation remains reopenable")
				await settle()
		await click(observation.open_button)
		var dialog = map.chest_dialog
		check(dialog.visible and not observation.visible and map.travel.paused and map.event_state.phase=="chest","opening transitions to choice phase and retains travel lock")
		var opened: Dictionary = map.loadout.snapshot()
		map._open_chest()
		check(map.loadout.snapshot()==opened,"duplicate open does not reroll or grant")
		check(dialog.cards.size()==2 and dialog.accept_button.disabled,"exactly two choices; selection required")
		check(dialog.heading.text==event.observation.location_name and dialog.location_description.text==event.observation.result_description,"stage two keeps location title and uses exact result copy")
		check(dialog.location_illustration.texture.resource_path==event.presentation.result_illustration,"opened scene artwork")
		var offer: Array = MapChestRewards.items(map.loadout,event)
		var chosen_pool := MapChestRewards.pool_definition(map.loadout.chest_offers[event.reward_id].pool_id)
		check(offer[0]!=offer[1],"two distinct offered items")
		for index in 2:
			var record: Dictionary = map.loadout.records[offer[index]]
			check(record.quality==expected[point] and record.category in chosen_pool.slots[index],"correct rarity/category pool")
			check(not dialog.cards[index].description.text.is_empty() and dialog.cards[index].description.text==record.flavor_description,"narrative description matches item catalog")
		check(dialog.accept_button.texture_normal.resource_path.ends_with("tanchuang-baoxiang-dakai1.webp") and dialog.accept_button.texture_hover.resource_path.ends_with("tanchuang-baoxiang-dakai2.webp"),"shared stage-one button artwork")
		var before: Dictionary = map.loadout.snapshot()
		await click(dialog.review_button)
		check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"cancel leaves event reusable")
		check(map.loadout.snapshot()==before,"cancel gives no items and preserves offer")
		if point=="n39":
			map.queue_free()
			await settle()
			MapEventState.session_completed.clear()
			map = await new_map()
			dialog = map.chest_dialog
			map.travel.current_node_id = point_id
			map.travel.map_position = map.travel.node_positions[point_id]
			map.travel.mode = "idle"
		check(map._try_start_event(point_id,"click",true),"stationary click reopens cancelled chest")
		await settle()
		await click(map.chest_observation_dialog.open_button)
		check(MapChestRewards.items(map.loadout,event)==offer,"same pair after reopen/reload")
		var tip: ItemTooltip = dialog.cards[0].build_item_tooltip("")
		check(tip.description==ItemTooltip.effect_text(map.loadout.registry.get_item(offer[0])),"choice card uses actual item tooltip")
		tip.free()
		await click(dialog.cards[0])
		check(dialog.selected_index==0 and dialog.cards[0].selected and not dialog.cards[1].selected,"click selects first only")
		await click(dialog.cards[1])
		check(dialog.selected_index==1 and not dialog.cards[0].selected and dialog.cards[1].selected,"click switches exclusive selection")
		check(dialog.open_label.text=="收取 "+map.loadout.records[offer[1]].name,"collect caption follows selected item")
		check(not root.gui_is_dragging(),"choice cards never initiate storage drag")
		if point=="n39":
			# Reload also restores map location metadata; compare atomic actions with
			# the current session snapshot, not the snapshot before map recreation.
			var claim_before: Dictionary=map.loadout.snapshot()
			var hover := InputEventMouseMotion.new()
			hover.position = dialog.accept_button.get_global_rect().get_center()
			hover.global_position = hover.position
			root.push_input(hover,true)
			await settle()
			check(dialog.accept_button.is_hovered() and dialog.open_label.get_theme_color("font_color")==Color.BLACK,"stage two collect hover has black text")
			hover.position=dialog.canvas.global_position+Vector2(30,30)
			hover.global_position=hover.position
			root.push_input(hover,true)
			await settle()
			check(dialog.open_label.get_theme_color("font_color")==Color.WHITE,"stage two collect returns to white text")
			for cancel_key in [false,true]:
				var cancel: InputEvent
				if cancel_key:
					var key:=InputEventKey.new()
					key.keycode=KEY_ESCAPE
					key.pressed=true
					cancel=key
				else:
					var mouse:=InputEventMouseButton.new()
					mouse.button_index=MOUSE_BUTTON_RIGHT
					mouse.pressed=true
					mouse.position=Vector2(50,50)
					cancel=mouse
				root.push_input(cancel,true)
				await settle()
				check(not dialog.visible and not map.event_state.is_active() and map.loadout.snapshot()==claim_before,"right click / escape preserve unopened claim and original options")
				check(map._try_start_event(point_id,"click",true),"stage two cancellation keeps chest accessible")
				await settle()
				await click(map.chest_observation_dialog.open_button)
				await click(dialog.cards[1])
			map.inventory_save_path = "res://artifacts/nonexistent-chest-dir/save.json"
			await click(dialog.accept_button)
			check(dialog.visible and not dialog.error_label.text.is_empty() and not map.loadout.has_reward(event.reward_id),"save failure retains offer without granting")
			check(map.loadout.snapshot()==claim_before,"failed claim leaves ownership, receipts and cooldown atomic")
			map.inventory_save_path = path
		if point=="n06" and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/map-chest-fanpin.png")
		if point=="n08" and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/map-chest-xiapin.png")
		await click(dialog.accept_button)
		check(not dialog.visible and map.loadout.has_reward(event.reward_id),"confirm claims and closes")
		check(map.loadout.granted_rewards[event.reward_id]=={"item_id":offer[1],"quantity":1},"only selected item, quantity one")
		var cooldown: Dictionary=map.loadout.chest_cooldowns[event.reward_id]
		check(cooldown.delay_days==40 and cooldown.remaining_days==40 and cooldown.ready_day==WorldCalendar.current_day(map.loadout.calendar)+40 and cooldown.cycle==1,"claim atomically starts configured 40-day wait")
		check(map.loadout.snapshot().owned_units.size()==before.owned_units.size()+1,"exactly one new owned unit")
		map._accept_chest()
		check(not map._try_start_event(point_id,"arrival",true),"claimed chest cannot trigger again")
		check(not MapChestRewards.claim(map.loadout,event,0,path).is_empty(),"alternate selection cannot claim twice")
	check(map.loadout.snapshot().owned_units.size()==total_before+5,"five chests award five items total")
	map.queue_free()
	await settle()
	MapEventState.session_completed.clear()
	map = await new_map()
	for point: String in expected:
		var id := "base.map.qingshihewan.point." + point
		var event_id: String = map.event_registry.by_point[id]
		check(map.event_state.completed.has(event_id),"claimed state survives fresh session")
		var event: Dictionary=map.event_registry.events[event_id]
		check(map.loadout.chest_cooldowns[event.reward_id].remaining_days==40,"restart preserves waiting; no calendar ticking")
		var dot = map.content.get_node("Points/"+point.to_upper())
		check(dot.visible and not dot.get_node("Sign").visible,"only chest sign disappears; path dot remains")
	var bad: Dictionary = map.loadout.snapshot()
	bad.chest_offers["base.map_reward.bad"] = ["base.map_item.bag_board", "base.map_item.bag_board"]
	check(not map.loadout.restore(bad).is_empty(),"invalid offered categories rejected on load")
	var definitions: Array = []
	for id: String in ["base.map_event.qingshihewan.chest_n06","base.map_event.qingshihewan.chest_n14"]:
		definitions.append(map.event_registry.events[id].duplicate(true))
	definitions[1].reward_id = definitions[0].reward_id
	check(not MapEventRegistry.new().configure(definitions,map.travel.node_positions.keys()).is_empty(),"duplicate chest receipt identifiers rejected")
	map.queue_free()
	await settle()
	print("MAP CHESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check_pools(map: Node) -> void:
	var counts: Dictionary = {}
	for roll in 100:
		var pool := MapChestRewards.pool_for_roll(roll)
		counts[pool.id]=int(counts.get(pool.id,0))+1
	check(counts=={"base.chest_pool.equipment":40,"base.chest_pool.consumables":40,"base.chest_pool.artifacts":20},"exact weighted pool ranges 40/40/20")
	var prepared := MapChestRewards._candidate(map.loadout)
	check(prepared.error.is_empty(),"isolated pool state")
	var state: MapLoadoutState=prepared.state
	var event: Dictionary=map.event_registry.events["base.map_event.qingshihewan.chest_n34"].duplicate(true)
	var original: Dictionary=state.snapshot()
	var rng:=RandomNumberGenerator.new()
	rng.seed=1701
	var covered: Dictionary={}
	for index in 24:
		state.restore(original)
		check(MapChestRewards.ensure_offer(state,event,"",rng).is_empty(),"pool draw succeeds")
		var offer: Dictionary=state.chest_offers[event.reward_id]
		var definition:=MapChestRewards.pool_definition(offer.pool_id)
		covered[offer.pool_id]=true
		check(offer.items[0]!=offer.items[1],"random pair never duplicates")
		for slot in 2:
			var record: Dictionary=state.records[offer.items[slot]]
			check(record.quality=="下品" and record.category in definition.slots[slot],"drawn items obey slot and quality")
	check(covered.size()==3,"seeded draws cover all pools")
	# Persisted old pairs are readable but upgrade atomically to the new pool rules.
	state.restore(original)
	var old: Array=[]
	for categories in [["weapon"],["pill"]]:
		for id: String in state.records:
			if state.records[id].quality=="凡品" and state.records[id].category in categories:
				old.append(id)
				break
	var legacy:=state.snapshot()
	legacy.chest_offers={event.reward_id:old}
	check(state.restore(legacy).is_empty(),"legacy offers load")
	var before:=state.snapshot()
	check(not MapChestRewards.ensure_offer(state,event,"res://artifacts/no-chest-migration-dir/save.json",rng).is_empty() and state.snapshot()==before,"migration save failure leaves old pair intact")
	check(MapChestRewards.ensure_offer(state,event,"",rng).is_empty(),"legacy pair migrates when opened")
	check(state.chest_offers[event.reward_id] is Dictionary and state.records[MapChestRewards.items(state,event)[0]].quality=="下品","old fanpin pair becomes current lower-grade pool")
	var migrated: Dictionary=state.chest_offers[event.reward_id].duplicate(true)
	check(MapChestRewards.ensure_offer(state,event,"",rng).is_empty() and state.chest_offers[event.reward_id]==migrated,"new offer never rerolls on reopen")
	var duplicate:=state.snapshot()
	duplicate.chest_offers[event.reward_id].items[1]=duplicate.chest_offers[event.reward_id].items[0]
	check(not state.restore(duplicate).is_empty(),"duplicate pair rejected")
	var invalid:=state.snapshot()
	invalid.chest_cooldowns={event.reward_id:{"delay_days":30,"remaining_days":30}}
	check(not state.restore(invalid).is_empty(),"cooldown without claim rejected")
	# A future fanpin map can use the same definitions without widening this map.
	event.quality="凡品"
	check(MapChestRewards.configuration_error(state,event).is_empty(),"shared pools still support fanpin")
	state.restore(original)
	check(MapChestRewards.ensure_offer(state,event,"",rng).is_empty(),"fanpin offer supported by generic pool code")
	for id: String in MapChestRewards.items(state,event): check(state.records[id].quality=="凡品","fanpin query stays in grade")
