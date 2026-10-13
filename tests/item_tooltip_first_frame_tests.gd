extends SceneTree
var checks := 0
func verify(ok: bool, message: String) -> void:
	checks += 1
	assert(ok, message)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var registry := ContentRegistry.new()
	verify(registry.load_base_content(), "registry")
	var made := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	verify(made.error.is_empty(), "model")
	var model: MapLoadoutState = made.state
	var cards: Array[MapInventoryItemCard] = []
	for title in ["御木丹","回灵丹"]:
		for record: Dictionary in model.storage_records():
			if record.name != title: continue
			var card := MapInventoryItemCard.new()
			card.configure(record,"丹药",true)
			card.bind_loadout(model,null)
			card.set_card_width(175)
			card.position = Vector2(1100,850) if cards.is_empty() else Vector2(2310,1050)
			root.add_child(card)
			cards.append(card)
			break
	verify(cards.size() == 2,"fixtures")
	await settle()
	var host := ItemTooltipHost.for_control(cards[0])
	# Sample actual rendered frames, including the very first visible one.
	for card: MapInventoryItemCard in [cards[0],cards[1],cards[0]]:
		var old := host.tooltip
		host.select_card(card)
		host._show(card,card.entry.id)
		verify(not is_instance_valid(old) or not old.visible,"old panel hidden synchronously")
		var tip := host.tooltip
		verify(tip.modulate.a == 0 and host._awaiting_layout,"new panel never paints provisional geometry")
		var shown := 0
		var first_rect := Rect2()
		for frame in 12:
			if DisplayServer.get_name() == "headless": await process_frame
			else: await RenderingServer.frame_post_draw
			if tip.modulate.a == 0: continue
			var rect := card.get_global_rect()
			var core := tip.find_child("SummaryPanel",true,false) as Control
			var expected_x := rect.end.x+12 if rect.end.x+12+tip.size.x <= 2552 else rect.position.x-tip.size.x-12
			var expected_y := clampf(rect.position.y-core.size.y*0.6,8,1440-tip.size.y-8)
			verify(tip.position.is_equal_approx(Vector2(expected_x,expected_y)),"every visible frame starts at final card-relative position")
			if shown == 0: first_rect = tip.get_global_rect()
			else: verify(tip.get_global_rect() == first_rect,"no jump after first visible frame")
			shown += 1
		verify(shown > 0,"panel becomes visible after layout")
	# A dismissed preparation must never resurrect or reveal another panel.
	host._show(cards[1],cards[1].entry.id)
	host.dismiss()
	await settle()
	verify(not is_instance_valid(host.tooltip),"cancel before reveal stays closed")
	host._show(cards[0],cards[0].entry.id)
	cards[0].hide()
	await settle()
	verify(not is_instance_valid(host.tooltip),"hidden source cancels preparation")
	for card in cards: card.queue_free()
	await settle()
	print("TOOLTIP FIRST FRAME: ",checks," checks passed; frame-by-frame presentation only, no mouse or real save")
	quit()
