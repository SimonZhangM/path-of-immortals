extends SceneTree

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i in 5: await process_frame

func wheel(position: Vector2, direction: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = direction
	event.pressed = true
	event.factor = 1.0
	root.push_input(event, true)
	await settle()

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(800,600)
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40,40)
	scroll.size = Vector2(250,320)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	var column := VBoxContainer.new()
	scroll.add_child(column)
	for i in 3:
		var card := MapInventoryItemCard.new()
		card.configure(model.records["base.map_item.qinglan_board_5"], "阵盘")
		card.bind_loadout(model, null)
		column.add_child(card)
	await settle()
	assert(scroll.scroll_vertical == 0)
	await wheel(Vector2(100,100), MOUSE_BUTTON_WHEEL_DOWN)
	var down := scroll.scroll_vertical
	assert(down > 0, "Wheel over board card must scroll storage down")
	assert(not root.gui_is_dragging(), "Wheel must not start a board drag")
	await wheel(Vector2(100,100), MOUSE_BUTTON_WHEEL_UP)
	assert(scroll.scroll_vertical < down, "Wheel over board card must scroll storage up")
	scroll.queue_free()
	await settle()
	print("BOARD CARD SCROLL: real GUI wheel propagation down/up passed; no drag started")
	quit()
